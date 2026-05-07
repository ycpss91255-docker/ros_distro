# TEST.md

**33 tests** in `test/smoke/ros_env.bats`, plus shared smoke tests from
`template/test/smoke/` (script_help + display_env, ~27 more).

The suite is **distro- and variant-agnostic**: variant-specific tests
(GUI tools / Gazebo) `skip` cleanly when the chosen `BASE_IMAGE` doesn't
include the binary, so the same suite works across:

- `ros:<distro>-ros-core-*` (minimal — core ROS CLI tests skip)
- `ros:<distro>-ros-base-*` (CLI tools available — GUI tests skip)
- `osrf/ros:<distro>-desktop-*` (GUI tools added)
- `osrf/ros:<distro>-desktop-full-*` (full Gazebo + perception)

## test/smoke/ros_env.bats (33)

### ROS environment (6)

| Test | Description |
|------|-------------|
| `ROS_DISTRO is set` | Verify `ROS_DISTRO` env var is non-empty (no version assert) |
| `ROS setup.bash exists` | `/opt/ros/${ROS_DISTRO}/setup.bash` present |
| `ROS environment can be sourced` | Sourcing setup.bash exits 0 |
| `rostopic command is available after sourcing ROS (ros-base+)` | Skip on ros-core |
| `rosrun command is available after sourcing ROS (ros-base+)` | Skip on ros-core |
| `rosnode command is available after sourcing ROS (ros-base+)` | Skip on ros-core |

(`roslaunch` and `rosmsg` follow the same skip-on-ros-core pattern, total 5 ros-base+ assertions.)

### GUI tools — desktop / desktop-full only (3)

| Test | Description |
|------|-------------|
| `rviz command is available (desktop / desktop-full)` | Skip on ros-base / ros-core |
| `rqt command is available (desktop / desktop-full)` | Skip on ros-base / ros-core |
| `gazebo command is available (desktop-full only)` | Skip on non-desktop-full |

### Base tools (11)

`python3` / `pip3` / `git` / `vim` / `curl` / `wget` / `tmux` / `tree` /
`htop` / `sudo` / `sudo -n` -- all on PATH and (sudo) usable without
password.

### System (11)

| Test | Description |
|------|-------------|
| `user is not root` | Container runs as non-root |
| `HOME is set and exists` | `$HOME` set and directory present |
| `timezone is Asia/Taipei` | `/etc/timezone` matches |
| `LANG is en_US.UTF-8` | Locale env var |
| `LC_ALL is en_US.UTF-8` | Locale env var |
| `NVIDIA_VISIBLE_DEVICES is set` | NVIDIA runtime env var |
| `NVIDIA_DRIVER_CAPABILITIES is set` | NVIDIA runtime env var |
| `entrypoint.sh exists and is executable` | `/entrypoint.sh` ready |
| `work directory exists` | `${HOME}/work` directory present |
| `work directory is writable` | Touch + rm works in `${HOME}/work` |
| `bash-completion is installed` | `/usr/share/bash-completion/bash_completion` present |

## Shared tests from template

The Dockerfile's `test` stage also runs the shared smoke specs from
`template/test/smoke/` (`script_help.bats` for the four wrapper scripts'
`-h` / `--help` / `--lang` behaviour, and `display_env.bats` for the
generated `compose.yaml`'s GUI block). See the template repo for the
exact list; new repo inherits them automatically via the
`COPY template/test/smoke/ /smoke_test/` line in the Dockerfile's
`test` stage.
