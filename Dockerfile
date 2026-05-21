# ros_distro -- ROS 1 multi-distro Docker environment.
#
# Default: osrf/ros:noetic-desktop-full-focal (Ubuntu 20.04, full GUI + simulators).
#
# Override BASE_IMAGE to switch distro / variant. Any image whose layout
# matches `/opt/ros/<distro>/setup.bash` works.
#
#   ROS 1 Noetic (Ubuntu 20.04 focal, supported until 2025-05):
#     osrf/ros:noetic-desktop-full-focal   (default -- full GUI + Gazebo + RViz + perception)
#     osrf/ros:noetic-desktop-focal        (GUI minus simulators)
#     ros:noetic-ros-base-focal            (custom base, headless, smallest)
#     ros:noetic-ros-core-focal            (minimal core, no rosbag/etc.)
#
#   ROS 1 Kinetic (Ubuntu 16.04 xenial, EOL 2021-04 -- kept for legacy):
#     osrf/ros:kinetic-desktop-full-xenial
#     ros:kinetic-ros-base-xenial
#
# Build:
#   ./build.sh                                                            # default target
#   ./build.sh --build-arg BASE_IMAGE=ros:noetic-ros-base-focal           # custom variant
#
# ROS_DISTRO comes from BASE_IMAGE's own ENV (every official ros: /
# osrf/ros: image sets `ENV ROS_DISTRO=<distro>`); subsequent stages
# read ${ROS_DISTRO} directly without needing a separate ARG.
ARG BASE_IMAGE="osrf/ros:noetic-desktop-full-focal"
ARG TEST_TOOLS_IMAGE="test-tools:local"

############################## sys ##############################
FROM ${BASE_IMAGE} AS sys

ARG USER="initial"
ARG GROUP="initial"
ARG UID="1000"
ARG GID="${UID}"
ARG SHELL="/bin/bash"
ARG HARDWARE="x86_64"
ENV HOME="/home/${USER}"

# Env vars for nvidia-container-runtime.
ENV NVIDIA_VISIBLE_DEVICES="all"
ENV NVIDIA_DRIVER_CAPABILITIES="all"

SHELL ["/bin/bash", "-x", "-euo", "pipefail", "-c"]

# Sanity-check ROS_DISTRO inherited from BASE_IMAGE.
RUN if [ -z "${ROS_DISTRO:-}" ] || [ ! -d "/opt/ros/${ROS_DISTRO}" ]; then \
        echo "FATAL: ROS_DISTRO unset or /opt/ros/${ROS_DISTRO:-?} missing -- is BASE_IMAGE a ros: / osrf/ros: image?" >&2; \
        exit 1; \
    fi

# Setup users and groups
RUN if getent group "${GID}" >/dev/null; then \
        existing_grp="$(getent group "${GID}" | cut -d: -f1)"; \
        if [ "${existing_grp}" != "${GROUP}" ]; then \
            groupmod -n "${GROUP}" "${existing_grp}"; \
        fi; \
    else \
        groupadd -g "${GID}" "${USER}"; \
    fi; \
    \
    if getent passwd "${UID}" >/dev/null; then \
        existing_user="$(getent passwd "${UID}" | cut -d: -f1)"; \
        if [ "${existing_user}" != "${USER}" ]; then \
            usermod -l "${USER}" "${existing_user}"; \
        fi; \
        usermod -g "${GID}" -s "${SHELL}" -d "${HOME}" -m "${USER}"; \
    elif id -u "${USER}" >/dev/null 2>&1; then \
        usermod -u "${UID}" -g "${GID}" -s "${SHELL}" -d "/home/${USER}" -m "${USER}"; \
    else \
        useradd -u "${UID}" -g "${GID}" -s "${SHELL}" -m "${USER}"; \
    fi; \
    \
    mkdir -p /etc/sudoers.d; \
    echo "${USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${USER}"; \
    chmod 0440 "/etc/sudoers.d/${USER}"

# Setup locale, timezone and replace apt urls (Taiwan mirror)
ENV TZ="Asia/Taipei"
ENV LC_ALL="en_US.UTF-8"
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"

ARG APT_MIRROR_UBUNTU="tw.archive.ubuntu.com"
RUN sed -i "s@archive.ubuntu.com@${APT_MIRROR_UBUNTU}@g" /etc/apt/sources.list || true && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        tzdata \
        locales && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen "${LANG}" && \
    update-locale LANG="${LANG}" && \
    ln -snf /usr/share/zoneinfo/"${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone

############################## devel-base ##############################
FROM sys AS devel-base

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sudo \
        psmisc \
        htop \
        # Shell
        tmux \
        terminator \
        # base tools
        ca-certificates \
        software-properties-common \
        wget \
        curl \
        git \
        vim \
        tree \
        # python3 tools
        python3-pip \
        python3-dev \
        python3-setuptools \
        bash-completion \
        # GPU/OpenGL (Intel + software fallback; harmless on headless variants).
        # `libgl1-mesa-glx` was removed in Ubuntu 24.04 noble; `libgl1` exists
        # on every supported Ubuntu (xenial / focal / jammy / noble) so the
        # multi-distro build path stays compatible.
        libgl1-mesa-dri \
        libgl1 \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

############################## devel ##############################
FROM devel-base AS devel

ARG USER
ARG GROUP
ARG ENTRYPOINT_FILE="script/entrypoint.sh"
ARG CONFIG_DIR="/tmp/config"
# <repo>/config is a per-repo copy of .base/config seeded by init.sh.
# Edit files there freely; template upgrades do not touch this directory.
ARG CONFIG_SRC="config"

# ROS 1 dev tools. plotjuggler-ros only ships for noetic; kinetic doesn't
# have a binary, so the install is best-effort to keep the multi-distro
# build path working across both distros.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3-osrf-pycommon \
        python3-catkin-tools \
        && \
    apt-get install -y --no-install-recommends \
        "ros-${ROS_DISTRO}-plotjuggler-ros" \
        || echo "plotjuggler-ros not packaged for ROS_DISTRO=${ROS_DISTRO}, skipping"; \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 "./${ENTRYPOINT_FILE}" "/entrypoint.sh"
COPY --chown="${USER}":"${GROUP}" --chmod=0755 "${CONFIG_SRC}" "${CONFIG_DIR}"

USER "${USER}"

# Setup shell, terminator, tmux
RUN cat "${CONFIG_DIR}"/shell/bashrc >> "${HOME}/.bashrc" && \
    chown "${USER}":"${GROUP}" "${HOME}/.bashrc" && \
    "${CONFIG_DIR}"/shell/terminator/setup.sh && \
    "${CONFIG_DIR}"/shell/tmux/setup.sh && \
    sudo rm -rf "${CONFIG_DIR}"

WORKDIR "${HOME}/work"

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

############################## devel-test (ephemeral) ##############################
# Resolves to test-tools:local (local build.sh) or ghcr.io/.../test-tools:vX.Y.Z (CI).
FROM ${TEST_TOOLS_IMAGE} AS test-tools-stage

FROM devel AS devel-test

USER root

# Lint tools (from pre-built test-tools image; see TEST_TOOLS_IMAGE at top)
COPY --from=test-tools-stage /usr/local/bin/shellcheck /usr/local/bin/shellcheck
COPY --from=test-tools-stage /usr/local/bin/hadolint /usr/local/bin/hadolint

# Lint: ShellCheck (.sh) + Hadolint (Dockerfile)
COPY .hadolint.yaml /lint/.hadolint.yaml
COPY Dockerfile /lint/Dockerfile
COPY script/*.sh /lint/
COPY .base/script/docker/_lib.sh \
     .base/script/docker/i18n.sh \
     .base/script/docker/_tui_conf.sh \
     /lint/
COPY .base/script/docker/lib /lint/lib
RUN shellcheck -S warning /lint/*.sh /lint/lib/*.sh
RUN cd /lint && hadolint Dockerfile

# Bats (from pre-built test-tools image; see TEST_TOOLS_IMAGE at top)
COPY --from=test-tools-stage /opt/bats /opt/bats
COPY --from=test-tools-stage /usr/lib/bats /usr/lib/bats
RUN ln -sf /opt/bats/bin/bats /usr/local/bin/bats

ENV BATS_LIB_PATH="/usr/lib/bats"

# Smoke test (shared tests from template + repo-specific tests)
COPY .base/test/smoke/ /smoke_test/
COPY test/smoke/ /smoke_test/

ARG USER
USER "${USER}"

RUN bats /smoke_test/

############################## build (downstream contract slot) ##############################
# Empty no-op in upstream ros_distro -- compile your packages here and put the
# install tree at /opt/ros/install/ so the runtime stage below can COPY it.
#
# Downstream usage (in a fork / consumer repo, override this stage):
#
#   FROM devel AS build
#
#   ARG USER
#   ARG GROUP
#
#   COPY --chown=${USER}:${GROUP} src/ /home/${USER}/work/src/
#
#   RUN source /opt/ros/${ROS_DISTRO}/setup.bash && \
#       cd /home/${USER}/work && \
#       catkin_make_isolated --install --install-space /opt/ros/install \
#                            --use-ninja \
#                            -DCMAKE_BUILD_TYPE=Release
#
# `runtime` below `COPY --from=build /opt/ros/install/` so the production
# image only contains binaries, not src/ / .o / catkin_ws build directory.
FROM devel AS build

ARG USER
ARG GROUP

USER root
RUN mkdir -p /opt/ros/install && \
    chown -R "${USER}":"${GROUP}" /opt/ros/install
USER "${USER}"

############################## runtime-base ##############################
FROM sys AS runtime-base

# tini is missing from xenial's archive (kinetic), but available on focal+;
# install best-effort so the multi-distro path stays compatible.
RUN apt-get update && \
    apt-get install -y --no-install-recommends sudo && \
    (apt-get install -y --no-install-recommends tini \
        || echo "tini not packaged for this distro (xenial?), runtime will use bash as PID 1"); \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

############################## runtime ##############################
FROM runtime-base AS runtime

ARG USER

# Baseline ROS runtime libs. Downstream can drop these if their `build`
# stage already pulls in the right deps via rosdep + COPY.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        "ros-${ROS_DISTRO}-rospy" \
        "ros-${ROS_DISTRO}-roscpp" \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Pull in the install tree produced by the `build` stage. Empty in upstream
# (build is a no-op); downstream's overridden `build` populates this with
# their compiled packages.
COPY --from=build /opt/ros/install/ /opt/ros/install/

COPY --chmod=0755 script/entrypoint.sh /entrypoint.sh

USER "${USER}"
WORKDIR "${HOME}/work"

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

############################## runtime-test (ephemeral) ##############################
# Install-check smoke for the runtime image (template v0.21.1+ #243).
# Default smoke verifies USER + bash on PATH. Override per-repo via
# build_args: RUNTIME_SMOKE_CMD=<command> (constraint: CLI-only, no
# GUI binaries that init Qt / OGRE on --version / --help).
#
# `sh -c` wrapper required: bare `RUN ${ARG}` word-splits operators
# (&&, ||) and nested quotes. The wrapper passes the value as a
# single string for sh to parse normally.
FROM runtime AS runtime-test

ARG RUNTIME_SMOKE_CMD='whoami && bash --version'
RUN sh -c "${RUNTIME_SMOKE_CMD}"
