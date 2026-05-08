**[English](CHANGELOG.md)** | **[繁體中文](CHANGELOG.zh-TW.md)** | **[简体中文](CHANGELOG.zh-CN.md)** | **[日本語](CHANGELOG.ja.md)**

# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **`call-publish` job in `main.yaml`**: opts into template v0.20.0's
  new `publish-worker.yaml` reusable workflow (template#232 / template#233).
  On tag push, each of the 4 matrix variants publishes a Docker image
  to `ghcr.io/ycpss91255-docker/ros_distro:<tag>-<entry-name>`, and the
  default variant (`noetic-desktop-full`) additionally publishes
  `:latest-noetic-desktop-full`. Auth via GITHUB_TOKEN (no extra
  secrets); `target: devel`.

  **Consumption pattern: CI build cache only.** These published images
  are NOT intended as a Docker `FROM` base for downstream app repos.
  Future app-pair consolidations (urg_node / realsense / sick) keep
  their own self-contained Dockerfile that `FROM`s upstream
  `osrf/ros:` / `ros:` directly; their CI may pass
  `cache-from: type=registry,ref=ghcr.io/.../ros_distro:<tag>-<variant>`
  to BuildKit as a best-effort hint to skip the cached sys/base/devel
  layers. When GHCR is unreachable (air-gapped, firewalled networks),
  app builds fall through to the full upstream rebuild without
  failing -- no hard dependency on GHCR.

### Changed
- Template subtree upgraded to `v0.20.0` (was `v0.19.0`).
  `main.yaml` reusable-workflow `@tag` references bumped accordingly.

## [v0.1.0] - 2026-05-07

### Added
- **Initial release.** Single repo, single Dockerfile, single `BASE_IMAGE`
  ARG to switch ROS 1 distro / variant at build time. Replaces the four
  legacy repos `ros_noetic`, `ros_kinetic`, `osrf_ros_noetic`, and
  `osrf_ros_kinetic` -- all four shared 90% of their Dockerfile and
  diverged only on the `FROM` line.
- Default `BASE_IMAGE` is `osrf/ros:noetic-desktop-full-focal`. Common
  alternatives are listed in the Dockerfile header comment and in the
  README's Build targets section: noetic + kinetic, `ros:` (custom,
  amd64+arm64) and `osrf/ros:` (desktop / desktop-full, amd64).
- Distro- and variant-agnostic smoke test: GUI-only assertions
  (`rviz` / `rqt` / `gazebo`) skip cleanly when their binaries aren't in
  the chosen variant; core ROS CLI assertions skip on `ros-core`.
- Uses the `TEST_TOOLS_IMAGE` Dockerfile pattern from template v0.18.0+
  (no inline `bats-src` / `bats-extensions` / `lint-tools` stages); the
  saving versus the legacy four-repo split is roughly -100 lines net.
- **`build` stage between `devel` and `runtime`**: contract slot for
  downstream consumers to compile their packages. Empty no-op upstream
  (just `mkdir /opt/ros/install`); downstream forks override
  `FROM devel AS build` with `catkin_make_isolated --install-space
  /opt/ros/install` (or equivalent). `runtime` `COPY --from=build
  /opt/ros/install/` so the production image contains only binaries,
  no `src/` / build artifacts. README's Architecture section documents
  the full layer cake (`sys → base → devel → {test, build}` and
  `sys → runtime-base → runtime ← COPY from build`).
- **CI build matrix (4 entries / push)**: `noetic-desktop-full` (osrf,
  default), `noetic-ros-base` (ros:, cross-registry), `kinetic-desktop-full`
  (osrf), `kinetic-ros-base` (ros:). Validates the multi-distro promise
  on every push without burning CI on rarely-used variants (`ros-core`
  intentionally excluded -- the smoke suite half-skips on it).
- Template subtree pinned at v0.19.0.
