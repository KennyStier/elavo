# Folio (the panel, the dock, and Lens), built at a pinned tag. Same Fedora
# release as base-main, so the binaries link against the GTK the image ships.
FROM registry.fedoraproject.org/fedora:44 AS folio
ARG ELAVO_FOLIO_REF=v0.2.0
RUN dnf5 install -y git gcc pkgconf-pkg-config rust cargo \
        gtk4-devel gtk4-layer-shell-devel wayland-devel && \
    dnf5 clean all
RUN git clone --depth 1 --branch "${ELAVO_FOLIO_REF}" \
        https://github.com/elavo-io/elavo-folio.git /src
WORKDIR /src
RUN cargo build --release --locked && DESTDIR=/out scripts/install

# System Settings, built the same way. Its Desktop & Dock pane embeds Folio's
# dock settings page, which Cargo fetches at the tag in its Cargo.toml.
# main until the first tag; pin it like Folio after that.
FROM registry.fedoraproject.org/fedora:44 AS system-settings
ARG ELAVO_SYSTEM_SETTINGS_REF=main
RUN dnf5 install -y git gcc pkgconf-pkg-config rust cargo \
        gtk4-devel gtk4-layer-shell-devel wayland-devel pulseaudio-libs-devel && \
    dnf5 clean all
RUN git clone --depth 1 --branch "${ELAVO_SYSTEM_SETTINGS_REF}" \
        https://github.com/elavo-io/elavo-system-settings.git /src
WORKDIR /src
RUN cargo build --release --locked && DESTDIR=/out scripts/install

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files
COPY config /config
COPY --from=folio /out /folio_files
COPY --from=system-settings /out /system_settings_files

# Base Image
FROM ghcr.io/ublue-os/base-main:latest
## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:testing
# FROM ghcr.io/ublue-os/aurora:stable
# FROM ghcr.io/ublue-os/bluefin-nvidia-open:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:44
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
