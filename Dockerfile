# ─────────────────────────────────────────────────────────────────────────────
# Yocto Scarthgap (5.0 LTS) build environment for Raspberry Pi CM4
# Base: Ubuntu 22.04 (officially supported Yocto host)
# ─────────────────────────────────────────────────────────────────────────────
FROM ubuntu:22.04

# Suppress interactive prompts during apt installs
ARG DEBIAN_FRONTEND=noninteractive

# Match the container user's UID/GID to the host user to avoid
# permission issues on bind-mounted volumes.
# Override at build time: docker compose build --build-arg HOST_UID=$(id -u)
ARG HOST_UID=1000
ARG HOST_GID=1000

# ─── Host dependencies required by Yocto Scarthgap ───────────────────────────
# Full list from: https://docs.yoctoproject.org/5.0/ref-manual/system-requirements.html
RUN apt-get update && apt-get install -y --no-install-recommends \
    gawk \
    wget \
    git \
    diffstat \
    unzip \
    texinfo \
    gcc \
    build-essential \
    chrpath \
    socat \
    cpio \
    python3 \
    python3-pip \
    python3-pexpect \
    python3-git \
    python3-jinja2 \
    python3-subunit \
    python3-setuptools \
    xz-utils \
    debianutils \
    iputils-ping \
    zstd \
    liblz4-tool \
    lz4 \
    file \
    locales \
    libacl1 \
    rsync \
    curl \
	vim \
    fzf \
	trickle \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# ─── Locale ──────────────────────────────────────────────────────────────────
# Yocto requires a UTF-8 locale; en_US.UTF-8 is the standard choice.
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# ─── Non-root user ───────────────────────────────────────────────────────────
# Yocto refuses to run as root. We create a 'yocto' user whose UID/GID
# matches the HOST_UID/HOST_GID build args so that files written into
# bind-mounted volumes are owned by the host user, not by root.
RUN groupadd -g "${HOST_GID}" yocto \
    && useradd -m -u "${HOST_UID}" -g "${HOST_GID}" -s /bin/bash yocto \
    && echo "yocto ALL=(root) NOPASSWD: /usr/bin/trickle, /usr/sbin/tc" \
       > /etc/sudoers.d/yocto-net \
    && chmod 0440 /etc/sudoers.d/yocto-net

# ─── Volume mount points ─────────────────────────────────────────────────────
# /workspace   – Yocto source tree (poky + layers + build dir)
# /downloads   – DL_DIR:   shared download cache; survives container rebuilds
# /sstate-cache– SSTATE_DIR: shared state cache; dramatically speeds up rebuilds
RUN mkdir -p /workspace /downloads /sstate-cache /mirror \
    && chown -R yocto:yocto /workspace /downloads /sstate-cache /mirror

## ─── Embedded scripts and config templates ───────────────────────────────────
## These are baked into the image so no extra mounts are needed at runtime.
COPY --chown=yocto:yocto scripts/ /opt/yocto/scripts/
#COPY --chown=yocto:yocto conf/    /opt/yocto/conf/
RUN chmod +x /opt/yocto/scripts/*.sh

RUN echo "PS1='\[\e[32m\](container)\[\e[0m\][\u \w]\$ '" >> /home/yocto/.bashrc

# ─── Switch to non-root user ─────────────────────────────────────────────────
USER yocto
WORKDIR /workspace

ENTRYPOINT ["/opt/yocto/scripts/entrypoint.sh"]
CMD ["/bin/bash"]
