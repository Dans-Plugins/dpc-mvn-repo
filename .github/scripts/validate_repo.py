#!/usr/bin/env python3
"""Static checks for what this repository ships.

Two things leave this repository:

* the reusable workflows under .github/workflows/reusable-*.yml, which every
  adopting plugin repo calls by path, and the example callers under
  docs/examples/ that people copy into those repos;
* the Nexus image (Dockerfile) and the XML templates people paste into their
  Maven setup.

This script checks the workflow contracts and the template syntax. It needs
only PyYAML and the standard library, reads no secrets, and talks to nothing.
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

    if errors:
        print("Validation failed:")
        for line in errors:
            print(f"  - {line}")
        return 1
    print(
        f"OK: {len(contracts)} reusable workflow(s), {len(examples)} example caller(s), "
        "2 XML template(s)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
