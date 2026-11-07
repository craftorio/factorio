# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository.

## What this repo is

Docker images for the **Factorio headless server**, published as `ghcr.io/craftorio/factorio` (and
`craftorio/factorio` on Docker Hub when the `DOCKERHUB_TOKEN` secret is set). Fork of
`goofball222/factorio`; keep the upstream attribution in `README.md`, `LICENSE` and the script headers.

Images are rebuilt automatically from the current Factorio release, so there is normally nothing to do
by hand when Factorio updates.

## Layout

| Path | Purpose |
| --- | --- |
| `stable/`, `experimental/` | Build contexts for the two channels. **They are identical except `VERSION`.** Any change to a Dockerfile or script must be applied to both directories. |
| `*/Dockerfile` | Debian (`debian:trixie-slim`) image. Trixie is required: the arm64 Factorio binary needs glibc >= 2.38. |
| `*/Dockerfile.alpine` | Alpine image on `frolvlad/alpine-glibc`. |
| `*/root/usr/local/bin/` | `docker-entrypoint.sh` and `entrypoint-functions.sh`, copied into the image. |
| `*/VERSION` | Factorio version for the channel. Written by `scripts/update-versions.sh`, do not edit by hand. |
| `scripts/update-versions.sh` | Reads `https://factorio.com/api/latest-releases`, updates `VERSION` files, the tag table in `README.md` and `README_uk.md` (rows marked `<!-- stable -->` / `<!-- experimental -->`) and prepends a `CHANGELOG.md` entry. Idempotent. |
| `docker-compose.yml` | Production compose: the server plus an `ofelia` job that pulls and recreates the server every 15 minutes. Config, mods and scenarios live in `./data` (git-ignored); saves live in the named volume `saves` (`factorio_saves`) so that `docker compose down -v` resets the world. |
| `.github/workflows/build.yml` | The build pipeline, see below. |
| `.github/workflows/lint.yml` | actionlint + shellcheck + compose validation for workflow/script/compose changes. |
| `Makefile`, `*/Makefile` | Local `docker build` helpers (`make stable`, `make experimental`). |

## CI pipeline (`build.yml`)

Triggers: cron every 2 hours (version check), push to `main` touching `stable/**` or `experimental/**`,
and `workflow_dispatch`. **Images must not be rebuilt for changes that do not affect them**: docs, compose,
scripts and workflow edits are covered by `lint.yml` (actionlint, shellcheck, `docker compose config`), not by
a build. Do not add such paths to the `build.yml` push trigger and do not add unconditional scheduled rebuilds.

1. `versions` job runs `scripts/update-versions.sh`. If versions changed it commits the result to `main`
   as `github-actions[bot]` (such pushes do not retrigger workflows). Outputs the versions and whether
   Docker Hub credentials exist.
2. `build` matrix: `channel` x `variant` (debian, alpine) x `arch` (amd64, arm64). Each arch builds
   **natively** on `ubuntu-24.04` / `ubuntu-24.04-arm` (no QEMU), runs a smoke test
   (`factorio --version` from the built image) and pushes by digest. On the cron the job is skipped
   unless a new Factorio version was found. To rebuild without a version change (e.g. to pick up a
   base image update) run the workflow manually.
3. `manifest` matrix merges the per-arch digests into multi-arch tags with `docker buildx imagetools`.

Tags: stable channel -> `latest`, `stable`, `<version>` (+ `-alpine` variants); experimental channel ->
`experimental`, `experimental-alpine`, and `<version>` only when it differs from stable.

## Conventions

* Dockerfiles take `VERSION`, `VCS_REF`, `BUILD_DATE` build args and use `TARGETARCH` to pick the
  download (`linux64` for amd64, `linux-arm64` for arm64). The binary lands in `bin/x64/` or
  `bin/arm64/`; the entrypoint locates it with a glob, do not hardcode the path.
* Pin GitHub Actions to major versions as upstream does (`actions/checkout@v7`); Dependabot bumps them.
* Keep `actionlint` clean: `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest`.
* Keep `hadolint` clean for `stable/Dockerfile` (CI runs it).
* `docker-compose.yml` must stay valid: `docker compose config --quiet`.
* Never commit anything under `data/` and never add Factorio credentials, tokens, RCON passwords or
  `server-id.json` to the repo, including in examples or docs.
* Do not edit `CHANGELOG.md` entries or `VERSION` files manually; run `scripts/update-versions.sh`.
* `README.md` (English) is the source of truth for documentation. `README_uk.md` is its Ukrainian translation
  and must be kept in sync: whenever the English README changes, apply the same change to `README_uk.md` in the
  same commit. Keep the section order, links, tables and code blocks identical; translate only the prose. Any
  future translation (`README_<lang>.md`) follows the same rule and must be added to `READMES` in
  `scripts/update-versions.sh` and to the language switcher at the top of every README.

## Verifying changes locally

```bash
# amd64 build + smoke test
docker build --build-arg VERSION=$(cat stable/VERSION) -t factorio:test stable
docker run --rm --entrypoint sh factorio:test -c '/opt/factorio/bin/*/factorio --version'

# arm64 build under QEMU (slow, only to validate Dockerfile changes)
docker run --privileged --rm tonistiigi/binfmt --install arm64
docker buildx build --platform linux/arm64 --load --build-arg VERSION=$(cat stable/VERSION) -t factorio:arm64 stable
docker run --rm --platform linux/arm64 --entrypoint sh factorio:arm64 -c '/opt/factorio/bin/*/factorio --version'
```

The binary must print `Version: <version> (build ..., linux64|linux-arm64, headless)`. A glibc
`version not found` error means the base image is too old for the Factorio build.

## Secrets and settings (GitHub repository)

* `DOCKERHUB_TOKEN` (optional): enables pushing to Docker Hub and updating the Hub description.
* `DOCKERHUB_USERNAME` (optional): Docker Hub login if it differs from the GitHub org name.
* `GITHUB_TOKEN` is used for GHCR and for the version-bump commit; workflow permissions are set in the
  workflow file (`contents: write`, `packages: write`).
