# Publishing to the DPC Maven Repository

This guide explains how to wire up any **Dans-Plugins Community (DPC)** plugin repository so that every version tag automatically builds the JAR and publishes it to the self-hosted Nexus Maven repository.

Both **Maven** and **Gradle** build systems are supported. Jump to the section that matches your project.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Maven — step-by-step setup](#2-maven--step-by-step-setup)
3. [Gradle — step-by-step setup](#3-gradle--step-by-step-setup)
4. [Versioning convention](#4-versioning-convention)
5. [Consuming published artifacts](#5-consuming-published-artifacts)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Prerequisites

| Requirement | Notes |
|---|---|
| Running DPC Nexus instance | See [QUICKSTART.md](QUICKSTART.md) to spin one up with Docker |
| Nexus deploy user | Must hold a role that can deploy to the `maven-releases` and `maven-snapshots` repositories |
| GitHub repository secrets | Three secrets — details in the next section |

### Create a Nexus deploy role and user

Nexus ships with only two roles, `nx-admin` and `nx-anonymous`, so a deploy role has to be created first.

1. Open the Nexus web UI (default: `http://localhost:8081`) and log in as an administrator. On a new instance, finish the setup wizard first: until the Community Edition license agreement is accepted, Nexus answers every repository request with 403, even from `admin`.
2. Go to **Settings → Security → Roles** and select **Create Role**. Choose the **Nexus role** type, give it a Role ID such as `dpc-deployer`, and add these privileges:

   | Repository | Privileges |
   |---|---|
   | `maven-releases` | `nx-repository-view-maven2-maven-releases-add`, `nx-repository-view-maven2-maven-releases-edit`, `nx-repository-view-maven2-maven-releases-read` |
   | `maven-snapshots` | `nx-repository-view-maven2-maven-snapshots-add`, `nx-repository-view-maven2-maven-snapshots-edit`, `nx-repository-view-maven2-maven-snapshots-read` |
   | `maven-public` | `nx-repository-view-maven2-maven-public-read` |

   `read` is not optional: Maven and Gradle both fetch `maven-metadata.xml` during a deploy, so a role without it fails with 403. `maven-public` is needed when anonymous access is disabled and the project resolves dependencies from this instance, because the build then uses the deploy user's credentials for those requests too.
3. Go to **Settings → Security → Users**, create a local user, and grant it the new role.
4. Note the username and password — you will add them as GitHub secrets.

---

## 2. Maven — step-by-step setup

### 2a. Add the caller workflow files

Copy the two example workflow files from this repository into your plugin's `.github/workflows/` directory.

**`.github/workflows/ci.yml`** — build & test on every push / PR  
([source](docs/examples/ci.yml))

```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    # Pin to a full-length commit SHA of this repository for reproducible
    # builds, e.g. reusable-build.yml@<full-commit-sha> (it has no
    # release tags yet). @main always uses the latest workflow.
    uses: Dans-Plugins/dpc-mvn-repo/.github/workflows/reusable-build.yml@main
    with:
      java-version: '17'
```

**`.github/workflows/publish.yml`** — publish on version tag or manual dispatch  
([source](docs/examples/publish.yml))

```yaml
name: Publish to DPC Maven Repo

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  publish:
    # Pin to a full-length commit SHA of this repository for reproducible
    # builds, e.g. reusable-publish.yml@<full-commit-sha> (it has no
    # release tags yet). @main always uses the latest workflow.
    uses: Dans-Plugins/dpc-mvn-repo/.github/workflows/reusable-publish.yml@main
    with:
      java-version: '17'
    secrets:
      NEXUS_USERNAME: ${{ secrets.NEXUS_USERNAME }}
      NEXUS_PASSWORD: ${{ secrets.NEXUS_PASSWORD }}
      NEXUS_URL: ${{ secrets.NEXUS_URL }}
```

> **Tip:** Change `java-version` to match the Java version your plugin requires (e.g. `'21'`).

### 2b. Update `pom.xml`

Add the `<distributionManagement>` block to your plugin's `pom.xml` (see [`pom.xml.template`](pom.xml.template) for a full example):

```xml
<distributionManagement>
  <repository>
    <id>dpc-maven-repo</id>
    <name>DPC Maven Repository - Releases</name>
    <url>${env.NEXUS_URL}/repository/maven-releases/</url>
  </repository>
  <snapshotRepository>
    <id>dpc-maven-repo</id>
    <name>DPC Maven Repository - Snapshots</name>
    <url>${env.NEXUS_URL}/repository/maven-snapshots/</url>
  </snapshotRepository>
</distributionManagement>
```

> The CI workflow overrides the URL at deploy time with `-DaltDeploymentRepository`. `NEXUS_URL` must be set as an environment variable for local deploys (`export NEXUS_URL=https://repo.dansplugins.com`); it is not needed for `mvn verify` (build & test only).

### 2c. Add the GitHub secrets

Add the following secrets to the plugin repository (or at the **Dans-Plugins organisation** level so they are available to all repos automatically):

| Secret | Value |
|---|---|
| `NEXUS_USERNAME` | Nexus deploy username (e.g. `ci-deployer`) |
| `NEXUS_PASSWORD` | Password or token for that user |
| `NEXUS_URL` | Base URL of the Nexus instance **without** a trailing slash (e.g. `https://repo.dansplugins.com`) |

To add a secret to a single repo:  
**GitHub → Settings → Secrets and variables → Actions → New repository secret**

To add an org-level secret:  
**GitHub Organisation → Settings → Secrets and variables → Actions → New organisation secret**

### 2d. Trigger the first publish

```bash
git tag v1.0.0
git push --tags
```

GitHub Actions will detect the `v1.0.0` tag, run the `publish` workflow, and deploy the release JAR to `maven-releases`.

---

## 3. Gradle — step-by-step setup

### 3a. Add the caller workflow files

Copy the two Gradle example workflow files from this repository into your project's `.github/workflows/` directory.

**`.github/workflows/ci.yml`** — build & test on every push / PR  
([source](docs/examples/ci-gradle.yml))

```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    # Pin to a full-length commit SHA of this repository for reproducible
    # builds, e.g. reusable-build-gradle.yml@<full-commit-sha> (it has no
    # release tags yet). @main always uses the latest workflow.
    uses: Dans-Plugins/dpc-mvn-repo/.github/workflows/reusable-build-gradle.yml@main
    with:
      java-version: '17'
```

**`.github/workflows/publish.yml`** — publish on version tag or manual dispatch  
([source](docs/examples/publish-gradle.yml))

```yaml
name: Publish to DPC Maven Repo

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  publish:
    # Pin to a full-length commit SHA of this repository for reproducible
    # builds, e.g. reusable-publish-gradle.yml@<full-commit-sha> (it has no
    # release tags yet). @main always uses the latest workflow.
    uses: Dans-Plugins/dpc-mvn-repo/.github/workflows/reusable-publish-gradle.yml@main
    with:
      java-version: '17'
    secrets:
      NEXUS_USERNAME: ${{ secrets.NEXUS_USERNAME }}
      NEXUS_PASSWORD: ${{ secrets.NEXUS_PASSWORD }}
      NEXUS_URL: ${{ secrets.NEXUS_URL }}
```

> **Tip:** Change `java-version` to match the Java version your project requires (e.g. `'21'`).

### 3b. Configure the `maven-publish` repository block

The reusable publish workflow passes four environment variables to `./gradlew publish`:

| Variable | Description |
|---|---|
| `NEXUS_URL` | Base URL of the Nexus instance (no trailing slash) |
| `NEXUS_REPO_TYPE` | `releases` or `snapshots` (set automatically based on the triggering ref) |
| `NEXUS_USERNAME` | Nexus deploy username |
| `NEXUS_PASSWORD` | Nexus deploy password or token |

Each module that should be published must apply the `maven-publish` plugin and declare a repository that reads these variables. Add the following to every publishable module's `build.gradle.kts`:

```kotlin
plugins {
    `maven-publish`
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
        }
    }

    repositories {
        maven {
            name = "dpcMavenRepo"
            url = uri(
                "${System.getenv("NEXUS_URL")}/repository/maven-${System.getenv("NEXUS_REPO_TYPE") ?: "snapshots"}/"
            )
            credentials {
                username = System.getenv("NEXUS_USERNAME")
                password = System.getenv("NEXUS_PASSWORD")
            }
        }
    }
}
```

Or, if you are using a Groovy `build.gradle`:

```groovy
plugins {
    id 'maven-publish'
}

publishing {
    publications {
        maven(MavenPublication) {
            from components.java
        }
    }

    repositories {
        maven {
            name = 'dpcMavenRepo'
            url = uri("${System.getenv('NEXUS_URL')}/repository/maven-${System.getenv('NEXUS_REPO_TYPE') ?: 'snapshots'}/")
            credentials {
                username = System.getenv('NEXUS_USERNAME')
                password = System.getenv('NEXUS_PASSWORD')
            }
        }
    }
}
```

#### Multi-module projects

For multi-module Gradle projects (such as Ponder with `ponder-bukkit`, `ponder-cache`, `ponder-commands`), apply the `maven-publish` block to each submodule's `build.gradle.kts`. Running `./gradlew publish` from the root will then publish all submodules in a single pass because the workflow invokes Gradle at the repository root.

### 3c. Add the GitHub secrets

The same three secrets as the Maven setup are required:

| Secret | Value |
|---|---|
| `NEXUS_USERNAME` | Nexus deploy username (e.g. `ci-deployer`) |
| `NEXUS_PASSWORD` | Password or token for that user |
| `NEXUS_URL` | Base URL of the Nexus instance **without** a trailing slash (e.g. `https://repo.dansplugins.com`) |

To add a secret to a single repo:  
**GitHub → Settings → Secrets and variables → Actions → New repository secret**

To add an org-level secret:  
**GitHub Organisation → Settings → Secrets and variables → Actions → New organisation secret**

### 3d. Trigger the first publish

```bash
git tag v1.0.0
git push --tags
```

GitHub Actions will detect the `v1.0.0` tag, run the `publish` workflow, and deploy the release JARs to `maven-releases`.

---

## 4. Versioning convention

| Situation | Target Nexus repository |
|---|---|
| Tag matching `v*` (e.g. `v1.2.3`) | `maven-releases` |
| Any other ref (branch push, `workflow_dispatch`) | `maven-snapshots` |

Follow [Semantic Versioning](https://semver.org/): `vMAJOR.MINOR.PATCH` (e.g. `v1.0.0`, `v2.3.1`).  
For **Maven** projects: ensure your `pom.xml` `<version>` matches the tag (e.g. `1.0.0` for tag `v1.0.0`).  
For **Gradle** projects: ensure the `version` property in `build.gradle` / `build.gradle.kts` matches the tag.

The example `publish.yml` callers trigger only on a `v*` tag push and on `workflow_dispatch`, so a branch push never publishes anything. To publish a SNAPSHOT version (e.g. `1.1.0-SNAPSHOT`) to `maven-snapshots`, run the workflow manually on that branch (**Actions → Publish to DPC Maven Repo → Run workflow**). To publish on every branch push instead, add a `branches:` filter under `on.push` in your copy of `publish.yml`.

Before building, both publish workflows check that the project version agrees with the target repository, and fail within seconds if it does not:

| Situation | Result |
|---|---|
| `v*` tag, version ends in `-SNAPSHOT` | Fails — `maven-releases` rejects SNAPSHOT versions |
| Any other ref, version does not end in `-SNAPSHOT` | Fails — `maven-snapshots` rejects release versions |

The Maven check reads `project.version` from the root `pom.xml`; the Gradle check reads the root project's `version`. Arguments passed through `maven-args` / `gradle-args` are applied to the check as well, so a version set on the command line (e.g. `-Drevision=1.2.3`) is the one checked.

---

## 5. Consuming published artifacts

To depend on an artifact published to the DPC Maven Repository, add the repository declarations and the dependency to your plugin's `pom.xml`:

```xml
<!-- Repository declaration — replace https://repo.dansplugins.com with your Nexus URL.
     maven-public is the Nexus group combining maven-releases, maven-snapshots, and
     maven-central, so one entry resolves both releases and snapshots. The id must match
     the <server> id in your settings.xml, or Maven resolves anonymously and fails with
     401 once anonymous access is disabled. -->
<repositories>
  <repository>
    <id>dpc-maven-repo</id>
    <url>https://repo.dansplugins.com/repository/maven-public/</url>
    <releases><enabled>true</enabled></releases>
    <snapshots><enabled>true</enabled></snapshots>
  </repository>
</repositories>

<!-- Example dependency -->
<dependencies>
  <dependency>
    <groupId>com.dansplugins</groupId>
    <artifactId>medieval-factions</artifactId>
    <version>5.0.0</version>
    <scope>provided</scope>
  </dependency>
</dependencies>
```

Replace the `groupId`, `artifactId`, and `version` values with those declared in the plugin's own `pom.xml`.

---

## 6. Troubleshooting

### 401 Unauthorized

Nexus returns 401 when credentials are missing or wrong. A valid user who lacks a privilege gets [403](#403-forbidden) instead.

- Verify `NEXUS_USERNAME` and `NEXUS_PASSWORD` secrets are set correctly and the user exists in Nexus.
- **When resolving dependencies rather than deploying:** confirm the `<repository>` id in your `pom.xml` matches a `<server>` id in your `~/.m2/settings.xml`. Maven matches credentials to repositories by id alone, so a mismatch makes it resolve anonymously — which succeeds until anonymous access is disabled, then fails with 401 and no other diagnostic. Both ids should be `dpc-maven-repo`.
- **Maven:** Run `mvn deploy -X` locally with the credentials to see the full error.
- **Gradle:** Run `./gradlew publish --info` locally with the env vars exported to see the full error.

### 403 Forbidden

- **Every request fails, even as `admin`:** the Community Edition license agreement has not been accepted. Maven and Gradle print only `Forbidden`. Finish the setup wizard in the web UI (see [Requests Fail with 403](docs/TROUBLESHOOTING.md#requests-fail-with-403) for how to check).
- **Deploys fail:** confirm the deploy user's role has the `edit` and `read` privileges on the target repository (`maven-releases` or `maven-snapshots`). See [Create a Nexus deploy role and user](#create-a-nexus-deploy-role-and-user).
- **Dependency resolution fails during a deploy:** with anonymous access disabled, the role also needs `nx-repository-view-maven2-maven-public-read`.

### 400 Repository version policy

- `Repository version policy: RELEASE does not allow version` means a SNAPSHOT version was sent to `maven-releases`, and `Repository version policy: SNAPSHOT does not allow version` means a release version was sent to `maven-snapshots`.
- The publish workflows catch both before building (see [Section 4](#4-versioning-convention)), but only for the root project's version. This error from a workflow usually means a submodule declares a different version than the root. Otherwise the deploy was run locally.

### Version does not match the target repository

- The `Verify version matches target repository` step failed before the build ran. Its error names the version it found and the repository the ref routed to.
- **SNAPSHOT under a `v*` tag:** set the release version (e.g. `1.0.0`), commit, then delete and re-push the tag so it points at that commit.
- **Release version on a branch or `workflow_dispatch`:** push a `v*` tag to publish a release, or append `-SNAPSHOT` to the version to publish a snapshot.

### Wrong repository URL

- Double-check that `NEXUS_URL` has **no trailing slash** and points to the Nexus base (e.g. `https://repo.dansplugins.com`).
- Verify the repository paths in Nexus UI match `/repository/maven-releases/` and `/repository/maven-snapshots/`.

### Missing `<distributionManagement>` (Maven)

- Maven requires a `<distributionManagement>` block (or `-DaltDeploymentRepository`) to know where to publish. The workflow supplies `-DaltDeploymentRepository` automatically, but having the block in `pom.xml` also allows local deploys.

### Missing `maven-publish` repository block (Gradle)

- Ensure each publishable module applies the `maven-publish` plugin and declares a repository that reads `NEXUS_URL`, `NEXUS_REPO_TYPE`, `NEXUS_USERNAME`, and `NEXUS_PASSWORD` from the environment. See [Section 3b](#3b-configure-the-maven-publish-repository-block) for the required snippet.
- For multi-module projects, verify every submodule that should be published has its own `publishing` block.

### Artifact version already exists (releases only)

- Nexus returns 400 with `cannot be updated` in the message: `maven-releases` defaults to the **Disable Redeploy** deployment policy, so a release version can be deployed only once.
- Bump the version in `pom.xml` / `build.gradle.kts` and create a new tag, or set the policy to **Allow Redeploy** in the repository's settings if you need to redeploy the same version.

### Build passes locally but fails in CI

- Ensure the Java version configured in the workflow (`java-version`) matches the version your project targets.
  - **Maven:** check `<maven.compiler.source>` / `<maven.compiler.target>` or `<java.version>` in `pom.xml`.
  - **Gradle:** check the `sourceCompatibility` / `targetCompatibility` settings or the `java.toolchain` block in `build.gradle.kts`.

---

For general Nexus connectivity issues see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).
