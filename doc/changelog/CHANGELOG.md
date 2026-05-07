**[English](CHANGELOG.md)** | **[繁體中文](CHANGELOG.zh-TW.md)** | **[简体中文](CHANGELOG.zh-CN.md)** | **[日本語](CHANGELOG.ja.md)**

# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- Template subtree pinned at v0.19.0.
