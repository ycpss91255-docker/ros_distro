#!/usr/bin/env bats

setup() {
    load "${BATS_TEST_DIRNAME}/test_helper"
}

# Tests are written distro-agnostic and variant-agnostic. Variant-specific
# tools (GUI / sim / full perception stack) skip cleanly when the binary
# is absent so the same suite is reusable across:
#   - ros:<distro>-ros-core-* (minimal — no rostopic/etc.)
#   - ros:<distro>-ros-base-* (CLI tools available)
#   - osrf/ros:<distro>-desktop-* (GUI tools added)
#   - osrf/ros:<distro>-desktop-full-* (Gazebo etc. added)

# -------------------- ROS environment --------------------

@test "ROS_DISTRO is set" {
    assert [ -n "${ROS_DISTRO}" ]
}

@test "ROS setup.bash exists" {
    assert [ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]
}

@test "ROS environment can be sourced" {
    run bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && echo ok"
    assert_success
    assert_output "ok"
}

@test "rostopic command is available after sourcing ROS (ros-base+)" {
    run bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && command -v rostopic" \
        || skip "ros-core variant — rostopic not installed"
    assert_success
}

@test "rosrun command is available after sourcing ROS (ros-base+)" {
    run bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && command -v rosrun" \
        || skip "ros-core variant — rosrun not installed"
    assert_success
}

@test "rosnode command is available after sourcing ROS (ros-base+)" {
    run bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && command -v rosnode" \
        || skip "ros-core variant — rosnode not installed"
    assert_success
}

@test "roslaunch command is available after sourcing ROS (ros-base+)" {
    run bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && command -v roslaunch" \
        || skip "ros-core variant — roslaunch not installed"
    assert_success
}

@test "rosmsg command is available after sourcing ROS (ros-base+)" {
    run bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && command -v rosmsg" \
        || skip "ros-core variant — rosmsg not installed"
    assert_success
}

# -------------------- GUI tools (desktop / desktop-full only) --------------------

@test "rviz command is available (desktop / desktop-full)" {
    run bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && command -v rviz"
    if [ "${status}" -ne 0 ]; then
        skip "no rviz — ros-base / ros-core variant"
    fi
    assert_success
}

@test "rqt command is available (desktop / desktop-full)" {
    run bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && command -v rqt"
    if [ "${status}" -ne 0 ]; then
        skip "no rqt — ros-base / ros-core variant"
    fi
    assert_success
}

@test "gazebo command is available (desktop-full only)" {
    run command -v gazebo
    if [ "${status}" -ne 0 ]; then
        skip "no gazebo — non-desktop-full variant"
    fi
    assert_success
}

# -------------------- Base tools --------------------

@test "python3 is available" {
    run which python3
    assert_success
}

@test "pip3 is available" {
    run which pip3
    assert_success
}

@test "git is available" {
    run which git
    assert_success
}

@test "vim is available" {
    run which vim
    assert_success
}

@test "curl is available" {
    run which curl
    assert_success
}

@test "wget is available" {
    run which wget
    assert_success
}

@test "tmux is available" {
    run which tmux
    assert_success
}

@test "tree is available" {
    run which tree
    assert_success
}

@test "htop is available" {
    run which htop
    assert_success
}

@test "sudo is available" {
    run which sudo
    assert_success
}

@test "sudo works without password" {
    run sudo -n true
    assert_success
}

# -------------------- System --------------------

@test "user is not root" {
    run id -u
    assert_success
    refute_output "0"
}

@test "HOME is set and exists" {
    assert [ -n "${HOME}" ]
    assert [ -d "${HOME}" ]
}

@test "timezone is Asia/Taipei" {
    run cat /etc/timezone
    assert_success
    assert_output "Asia/Taipei"
}

@test "LANG is en_US.UTF-8" {
    assert_equal "${LANG}" "en_US.UTF-8"
}

@test "LC_ALL is en_US.UTF-8" {
    assert_equal "${LC_ALL}" "en_US.UTF-8"
}

@test "NVIDIA_VISIBLE_DEVICES is set" {
    assert_equal "${NVIDIA_VISIBLE_DEVICES}" "all"
}

@test "NVIDIA_DRIVER_CAPABILITIES is set" {
    assert_equal "${NVIDIA_DRIVER_CAPABILITIES}" "all"
}

@test "entrypoint.sh exists and is executable" {
    assert [ -x "/entrypoint.sh" ]
}

@test "work directory exists" {
    assert [ -d "${HOME}/work" ]
}

@test "work directory is writable" {
    run bash -c "touch '${HOME}/work/.smoke_test' && rm '${HOME}/work/.smoke_test'"
    assert_success
}

@test "bash-completion is installed" {
    assert [ -f "/usr/share/bash-completion/bash_completion" ]
}
