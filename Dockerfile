# Build environment for the box: Packer, its qemu and vagrant plugins, and
# QEMU, so the host needs only Docker and /dev/kvm. `make image` builds it;
# `make box` runs the build inside it.

ARG QEMU_PLUGIN_VERSION=1.1.6
ARG VAGRANT_PLUGIN_VERSION=1.1.7

# The plugins are built from their release tags. Since v1.1.4 HashiCorp ships
# plugin binaries only through releases.hashicorp.com, not on GitHub, and a
# release-service outage then leaves `packer init` with nothing to install.
FROM golang:1.25-trixie AS plugins
ARG QEMU_PLUGIN_VERSION
ARG VAGRANT_PLUGIN_VERSION
ENV CGO_ENABLED=0
WORKDIR /src
RUN git clone --quiet --depth 1 --branch "v${QEMU_PLUGIN_VERSION}" \
      https://github.com/hashicorp/packer-plugin-qemu.git qemu \
 && git clone --quiet --depth 1 --branch "v${VAGRANT_PLUGIN_VERSION}" \
      https://github.com/hashicorp/packer-plugin-vagrant.git vagrant \
 && (cd qemu && go build -trimpath -o /out/packer-plugin-qemu .) \
 && (cd vagrant && go build -trimpath -o /out/packer-plugin-vagrant .)

FROM debian:trixie-slim

ARG PACKER_VERSION=1.16.1
# From packer_${PACKER_VERSION}_SHA256SUMS on releases.hashicorp.com.
ARG PACKER_SHA256=af38a9e93e4ed1b9ca68206ae969c64c300c82a3dde46a780dfa629f0867f651

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      qemu-system-x86 qemu-utils ca-certificates curl unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSLo /tmp/packer.zip \
      "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip" \
 && echo "${PACKER_SHA256}  /tmp/packer.zip" | sha256sum -c - \
 && unzip -q /tmp/packer.zip packer -d /usr/local/bin \
 && rm /tmp/packer.zip

# Plugins live in the image, not in the invoking user's home, so the build
# runs the same whatever uid it runs as.
ENV PACKER_PLUGIN_PATH=/opt/packer/plugins
COPY --from=plugins /out/ /tmp/plugins/
RUN packer plugins install --path /tmp/plugins/packer-plugin-qemu github.com/hashicorp/qemu \
 && packer plugins install --path /tmp/plugins/packer-plugin-vagrant github.com/hashicorp/vagrant \
 && rm -rf /tmp/plugins \
 && chmod -R a+rX /opt/packer

# Packer's cache (the ISO) and its per-user config go under the mounted
# repo and /tmp, never into the image.
ENV PACKER_CACHE_DIR=/work/packer_cache \
    HOME=/tmp \
    PACKER_CHECKPOINT_DISABLE=1

WORKDIR /work
ENTRYPOINT ["packer"]
