# Publishing to the DPC Maven Repository

This guide explains how to wire up any **Dans-Plugins Community (DPC)** plugin repository so that every version tag automatically builds the JAR and publishes it to the self-hosted Nexus Maven repository.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Step-by-step setup for a plugin repo](#2-step-by-step-setup-for-a-plugin-repo)
3. [Versioning convention](#3-versioning-convention)
4. [Consuming published artifacts](#4-consuming-published-artifacts)
5. [Troubleshooting](#5-troubleshooting)

---

## 1. Prerequisites

| Requirement | Notes |
|---|---|
| Running DPC Nexus instance | See [QUICKSTART.md](QUICKSTART.md) to spin one up with Docker |
| Nexus deploy user | Must have **write** access to `maven-releases` and `maven-snapshots` repositories |
| GitHub repository secrets | Three secrets — details in the next section |

### Create a Nexus deploy user

1. Open the Nexus web UI (default: `http://localhost:8081`).
2. Go to **Security → Users → Create local user**.
3. Grant the user the **nx-deploy** or a custom role with write access to both `maven-releases` and `maven-snapshots`.
4. Note the username and password — you will add them as GitHub secrets.

---

## 2. Step-by-step setup for a plugin repo

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
    # Pin to a specific release tag or commit SHA for reproducible builds,
    # e.g. reusable-build.yml@v1. @main always uses the latest workflow.
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
    # Pin to a specific release tag or commit SHA for reproducible builds,
    # e.g. reusable-publish.yml@v1. @main always uses the latest workflow.
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

## 3. Versioning convention

| Situation | Target Nexus repository |
|---|---|
| Tag matching `v*` (e.g. `v1.2.3`) | `maven-releases` |
| Any other ref (branch push, `workflow_dispatch`) | `maven-snapshots` |

Follow [Semantic Versioning](https://semver.org/): `vMAJOR.MINOR.PATCH` (e.g. `v1.0.0`, `v2.3.1`).  
Ensure your `pom.xml` `<version>` matches the tag (e.g. `1.0.0` for tag `v1.0.0`).  
SNAPSHOT versions in `pom.xml` (e.g. `1.1.0-SNAPSHOT`) will be published to `maven-snapshots` on every branch push.

---

## 4. Consuming published artifacts

To depend on an artifact published to the DPC Maven Repository, add the repository declarations and the dependency to your plugin's `pom.xml`:

```xml
<!-- Repository declarations — replace https://repo.dansplugins.com with your Nexus URL -->
<repositories>
  <repository>
    <id>dpc-maven-repo-releases</id>
    <url>https://repo.dansplugins.com/repository/maven-releases/</url>
    <releases><enabled>true</enabled></releases>
    <snapshots><enabled>false</enabled></snapshots>
  </repository>
  <repository>
    <id>dpc-maven-repo-snapshots</id>
    <url>https://repo.dansplugins.com/repository/maven-snapshots/</url>
    <releases><enabled>false</enabled></releases>
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

## 5. Troubleshooting

### 401 Unauthorized

- Verify `NEXUS_USERNAME` and `NEXUS_PASSWORD` secrets are set correctly and the user exists in Nexus.
- Confirm the user has write permission for the target repository (`maven-releases` or `maven-snapshots`).
- Run `mvn deploy -X` locally with the credentials to see the full error.

### 403 Forbidden / Deployment policy violation

- In the Nexus UI, check that **Deployment Policy** for the `maven-releases` repository is set to **Allow Redeploy** (or **Disable Redeploy** if you intentionally block overwriting).
- SNAPSHOT versions cannot be pushed to `maven-releases`.

### Wrong repository URL

- Double-check that `NEXUS_URL` has **no trailing slash** and points to the Nexus base (e.g. `https://repo.dansplugins.com`).
- Verify the repository paths in Nexus UI match `/repository/maven-releases/` and `/repository/maven-snapshots/`.

### Missing `<distributionManagement>`

- Maven requires a `<distributionManagement>` block (or `-DaltDeploymentRepository`) to know where to publish. The workflow supplies `-DaltDeploymentRepository` automatically, but having the block in `pom.xml` also allows local deploys.

### Artifact version already exists (releases only)

- Release versions are immutable by default. Bump the version in `pom.xml` and create a new tag, or change the Nexus deployment policy if you need to redeploy the same version.

### Build passes locally but fails in CI

- Ensure the Java version configured in the workflow (`java-version`) matches the version your `pom.xml` targets in `<maven.compiler.source>` / `<maven.compiler.target>` or `<java.version>`.

---

For general Nexus connectivity issues see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).
