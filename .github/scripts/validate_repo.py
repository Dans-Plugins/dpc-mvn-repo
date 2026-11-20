#!/usr/bin/env python3
"""Static checks for what this repository ships.

Two things leave this repository:

* the reusable workflows under .github/workflows/reusable-*.yml, which every
  adopting plugin repo calls by path, and the example callers under
  docs/examples/ that people copy into those repos;
* the Nexus image (Dockerfile) and the XML templates people paste into their
  Maven setup.

This script checks the workflow contracts and the template syntax, that
.env.example documents exactly the variables docker-compose.yml reads, that
every Maven repository id in the templates, docs, and publish workflow has a
matching <server> id in settings.xml.template, and that every Makefile target
is listed by `make help` and .PHONY and every `make <target>` the docs show
exists. It needs only PyYAML and the standard library, reads no secrets, and
talks to nothing.
Exit status is non-zero if any check fails; every failure is printed.

Run locally:  python3 .github/scripts/validate_repo.py
"""

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"
EXAMPLES = ROOT / "docs" / "examples"
REPO_SLUG = "Dans-Plugins/dpc-mvn-repo"

# Secrets every publish workflow must declare as required: the example callers
# and PUBLISHING.md tell adopters to provide exactly these three.
PUBLISH_SECRETS = {"NEXUS_USERNAME", "NEXUS_PASSWORD", "NEXUS_URL"}

EXPR = re.compile(r"\$\{\{\s*(inputs|secrets)\.([A-Za-z0-9_-]+)\s*\}\}")

errors = []


def fail(path, message):
    errors.append(f"{path.relative_to(ROOT)}: {message}")


def load(path):
    try:
        with path.open(encoding="utf-8") as handle:
            data = yaml.safe_load(handle)
    except yaml.YAMLError as exc:
        fail(path, f"YAML does not parse: {exc}")
        return None
    if not isinstance(data, dict):
        fail(path, "top level is not a mapping")
        return None
    return data


def triggers(workflow):
    # YAML 1.1 reads a bare `on` key as boolean True.
    on = workflow.get("on", workflow.get(True))
    if isinstance(on, str):
        return {on: None}
    if isinstance(on, list):
        return {name: None for name in on}
    return on if isinstance(on, dict) else {}


def check_reusable(path):
    workflow = load(path)
    if workflow is None:
        return None
    on = triggers(workflow)
    if set(on) != {"workflow_call"}:
        fail(path, f"reusable workflow must trigger only on workflow_call, got {sorted(on)}")
        return None
    call = on.get("workflow_call") or {}
    inputs = call.get("inputs") or {}
    secrets = call.get("secrets") or {}

    for name, spec in inputs.items():
        spec = spec or {}
        if "type" not in spec:
            fail(path, f"input '{name}' has no type")
        if not spec.get("required", False) and "default" not in spec:
            fail(path, f"optional input '{name}' has no default")

    text = path.read_text(encoding="utf-8")
    for kind, name in EXPR.findall(text):
        declared = inputs if kind == "inputs" else secrets
        if name not in declared:
            fail(path, f"references {kind}.{name}, which is not declared under workflow_call")

    is_publish = "publish" in path.name
    if is_publish:
        missing = PUBLISH_SECRETS - set(secrets)
        if missing:
            fail(path, f"publish workflow does not declare secrets {sorted(missing)}")
        for name in PUBLISH_SECRETS & set(secrets):
            if not (secrets[name] or {}).get("required", False):
                fail(path, f"secret '{name}' must be required")
    elif secrets or "secrets." in text:
        fail(path, "build-only workflow must not declare or read secrets")

    jobs = workflow.get("jobs") or {}
    if not jobs:
        fail(path, "has no jobs")
    for job_name, job in jobs.items():
        perms = (job or {}).get("permissions", workflow.get("permissions"))
        if perms != {"contents": "read"}:
            fail(path, f"job '{job_name}' must cap permissions to contents: read, got {perms!r}")

    return {"inputs": inputs, "secrets": secrets}


def check_callers(path, contracts, *, allow_publish):
    workflow = load(path)
    if workflow is None:
        return
    prefix = f"{REPO_SLUG}/.github/workflows/"
    for job_name, job in (workflow.get("jobs") or {}).items():
        uses = (job or {}).get("uses")
        if not uses or not uses.startswith(prefix):
            continue
        target = uses[len(prefix):].split("@", 1)[0]
        if target not in contracts:
            fail(path, f"job '{job_name}' calls {target}, which is not a reusable workflow here")
            continue
        if "publish" in target and not allow_publish:
            fail(path, f"job '{job_name}' calls publishing workflow {target}")
        contract = contracts[target]
        for key in (job.get("with") or {}):
            if key not in contract["inputs"]:
                fail(path, f"job '{job_name}' passes unknown input '{key}' to {target}")
        for name, spec in contract["inputs"].items():
            if (spec or {}).get("required") and name not in (job.get("with") or {}):
                fail(path, f"job '{job_name}' omits required input '{name}' for {target}")
        passed = job.get("secrets")
        if passed == "inherit":
            continue
        passed = passed or {}
        for name, spec in contract["secrets"].items():
            if (spec or {}).get("required") and name not in passed:
                fail(path, f"job '{job_name}' omits required secret '{name}' for {target}")
        for name in passed:
            if name not in contract["secrets"]:
                fail(path, f"job '{job_name}' passes undeclared secret '{name}' to {target}")


def check_xml(path, *, fragment):
    text = path.read_text(encoding="utf-8")
    if fragment:
        # pom.xml.template is a set of sibling snippets to paste into a pom,
        # not a whole document; give it a root so it can be parsed.
        text = "<fragment>" + text + "</fragment>"
    try:
        ET.fromstring(text)
    except ET.ParseError as exc:
        fail(path, f"XML is not well-formed: {exc}")


def check_pinned_images():
    """A floating Nexus tag would upgrade the server (and migrate its data
    volume) on any rebuild; the base image must name an exact release."""
    for name in ("Dockerfile", "docker-compose.yml"):
        path = ROOT / name
        for ref in re.findall(r"(?:FROM|image:)\s+(sonatype/nexus3\S*)", path.read_text(encoding="utf-8")):
            if "@sha256:" not in ref or ref.split("@")[0].endswith((":latest", "nexus3")):
                fail(path, f"Nexus image {ref!r} is not pinned to a release tag and digest")


def check_compose_cli():
    """The documented prerequisite is Compose v2, which installs only the
    `docker compose` plugin; a `docker-compose` call fails with 'command not
    found' on such a host. File names like docker-compose.yml are allowed."""
    paths = [ROOT / "Makefile", *ROOT.glob("*.sh"), *ROOT.glob("*.md"), *ROOT.glob("docs/*.md")]
    for path in sorted(paths):
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if re.search(r"\bdocker-compose(?![.\w-])", line):
                fail(path, f"line {number} calls 'docker-compose'; use 'docker compose' (Compose v2)")


REPOSITORY_TAGS = ("repository", "snapshotRepository", "pluginRepository", "mirror")


def maven_ids(root):
    """Return (server ids, [(tag, id)] for every repository-like element).
    settings.xml.template declares the Maven settings namespace, so tags are
    compared by local name."""
    def local(tag):
        return tag.rsplit("}", 1)[-1]

    def ident(element):
        for child in element:
            if local(child.tag) == "id":
                return (child.text or "").strip()
        return None

    servers, repos = set(), []
    for element in root.iter():
        tag = local(element.tag)
        if tag == "server":
            servers.add(ident(element))
        elif tag in REPOSITORY_TAGS:
            repos.append((tag, ident(element)))
    return servers, repos


def check_maven_ids():
    """Maven sends credentials only for a repository whose id equals a
    <server> id in settings.xml. Every repository, mirror, and deploy target
    this repository tells people to configure must therefore use an id that
    settings.xml.template declares as a server; otherwise resolution goes out
    anonymously and fails with 401 once anonymous access is disabled, with no
    error in this repository. Checked: both XML templates, every ```xml block
    in the Markdown docs, and the server-id / altDeploymentRepository id the
    Maven publish workflow deploys with."""
    settings_path = ROOT / "settings.xml.template"
    try:
        known, repos = maven_ids(ET.fromstring(settings_path.read_text(encoding="utf-8")))
    except ET.ParseError:
        return 0  # already reported by check_xml
    if not known:
        fail(settings_path, "declares no <server> id")
        return 0
    sources = [(settings_path, None, repos)]

    pom_path = ROOT / "pom.xml.template"
    try:
        sources.append((pom_path, None, maven_ids(ET.fromstring(
            "<fragment>" + pom_path.read_text(encoding="utf-8") + "</fragment>"))[1]))
    except ET.ParseError:
        pass  # already reported by check_xml

    for path in sorted([*ROOT.glob("*.md"), *ROOT.glob("docs/*.md")]):
        text = path.read_text(encoding="utf-8")
        for block in re.finditer(r"^```xml\n(.*?)^```", text, re.S | re.M):
            line = text.count("\n", 0, block.start()) + 1
            try:
                root = ET.fromstring("<fragment>" + block.group(1) + "</fragment>")
            except ET.ParseError as exc:
                fail(path, f"xml block at line {line} is not well-formed: {exc}")
                continue
            servers, repos = maven_ids(root)
            repos += [("server", sid) for sid in servers]
            sources.append((path, line, repos))

    for path in sorted(WORKFLOWS.glob("reusable-publish*.yml")):
        text = path.read_text(encoding="utf-8")
        repos = [("server-id", v) for v in re.findall(r"^\s*server-id:\s*(\S+)", text, re.M)]
        repos += [("altDeploymentRepository", v) for v in re.findall(r"-DaltDeploymentRepository=\"?([^:\"\s]+)::", text)]
        sources.append((path, None, repos))

    checked = 0
    for path, line, repos in sources:
        where = f"xml block at line {line}: " if line else ""
        for tag, ident in repos:
            checked += 1
            if ident not in known:
                fail(path, f"{where}<{tag}> id {ident!r} has no matching <server> id in "
                           f"settings.xml.template ({', '.join(sorted(known))})")
    return checked


def check_env_parity():
    """Every variable documented in .env.example must be interpolated by
    docker-compose.yml with the same default, and vice versa. A documented
    key the compose file never reads is silently ignored, and a default that
    differs from the example means an unmodified copy of .env changes the
    service."""
    env_path = ROOT / ".env.example"
    compose_path = ROOT / "docker-compose.yml"
    documented = dict(re.findall(r"^([A-Z_]+)=(.*)$", env_path.read_text(encoding="utf-8"), re.M))
    compose = "".join(
        line
        for line in compose_path.read_text(encoding="utf-8").splitlines(keepends=True)
        if not line.lstrip().startswith("#")
    )
    interpolated = {}
    for name, default in re.findall(r"\$\{([A-Z_]+)(?::-([^}]*))?\}", compose):
        interpolated.setdefault(name, default)
    for name, value in sorted(documented.items()):
        if name not in interpolated:
            fail(env_path, f"{name} is documented but docker-compose.yml never reads it")
        elif interpolated[name] != value:
            fail(compose_path, f"${{{name}}} defaults to {interpolated[name]!r}, but .env.example says {value!r}")
    for name in sorted(set(interpolated) - set(documented)):
        fail(compose_path, f"${{{name}}} is read but not documented in .env.example")
    return len(documented)


def check_makefile():
    """`make help` lists only targets whose rule line carries a `## ` comment,
    a target missing from .PHONY stops running once a file of the same name
    exists, and a `make <target>` in the docs that the Makefile does not define
    fails with 'No rule to make target'. Checked: every rule has a help
    comment, .PHONY names exactly the rules, and every `make <target>` in a
    fenced code block or inline code span of the Markdown docs is a rule."""
    path = ROOT / "Makefile"
    text = path.read_text(encoding="utf-8")
    rules = {}
    for name, rest in re.findall(r"^([A-Za-z0-9_-]+):(?!=)(.*)$", text, re.M):
        rules[name] = rest
    phony = set()
    for line in re.findall(r"^\.PHONY:(.*)$", text, re.M):
        phony.update(line.split())
    for name, rest in rules.items():
        # Mirror the help target's own grep, which matches only [a-zA-Z_-] names.
        if not re.fullmatch(r"[a-zA-Z_-]+", name) or not re.search(r"## \S", rest):
            fail(path, f"'make help' omits target '{name}'; it needs a '## ' help comment "
                       "and a name of only letters, '_' and '-'")
        if name not in phony:
            fail(path, f"target '{name}' is not declared .PHONY")
    for name in sorted(phony - set(rules)):
        fail(path, f".PHONY names '{name}', which has no rule")

    referenced = 0
    for doc in sorted([*ROOT.glob("*.md"), *ROOT.glob("docs/*.md")]):
        text = doc.read_text(encoding="utf-8")
        spans = [m.group(1) for m in re.finditer(r"^\s*```[^\n]*\n(.*?)^\s*```", text, re.S | re.M)]
        spans += re.findall(r"(?<!`)`([^`\n]+)`(?!`)", text)
        for span in spans:
            for target in re.findall(r"(?:^|[\s;&|(])make\s+([A-Za-z0-9_-]+)(?![\w=-])", span, re.M):
                referenced += 1
                if target not in rules:
                    fail(doc, f"documents 'make {target}', but the Makefile has no such target")
    return len(rules), referenced


def main():
    contracts = {}
    reusable = sorted(WORKFLOWS.glob("reusable-*.yml"))
    if not reusable:
        errors.append("no reusable workflows found under .github/workflows")
    for path in reusable:
        contract = check_reusable(path)
        if contract is not None:
            contracts[path.name] = contract

    for path in sorted(WORKFLOWS.glob("*.yml")):
        if not path.name.startswith("reusable-"):
            # This repo's own workflows must never call the publish ones.
            check_callers(path, contracts, allow_publish=False)

    examples = sorted(EXAMPLES.glob("*.yml"))
    if not examples:
        errors.append("no example callers found under docs/examples")
    for path in examples:
        check_callers(path, contracts, allow_publish=True)

    check_xml(ROOT / "settings.xml.template", fragment=False)
    check_xml(ROOT / "pom.xml.template", fragment=True)
    check_pinned_images()
    check_compose_cli()
    env_keys = check_env_parity()
    maven_refs = check_maven_ids()
    make_rules, make_refs = check_makefile()

    if errors:
        print("Validation failed:")
        for line in errors:
            print(f"  - {line}")
        return 1
    print(
        f"OK: {len(contracts)} reusable workflow(s), {len(examples)} example caller(s), "
        f"2 XML template(s), {env_keys} .env.example variable(s), "
        f"{maven_refs} Maven id reference(s), {make_rules} Makefile target(s), "
        f"{make_refs} documented make command(s)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
