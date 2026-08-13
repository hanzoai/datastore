# Hanzo Datastore 26.2 — built FROM SOURCE, speaking our own HTTP wire.
#
# This image exists to retire the nginx sidecar. The engine that runs today is an
# upstream binary with `mv /usr/bin/clickhouse /usr/bin/hanzo-datastore` applied
# to it, so it answers with upstream-branded headers and a proxy in front rewrites
# them. Building the header rename from source removes the reason the proxy is
# there. Nothing else about the deployment changes.
#
# WHY 26.2 AND NOT THE 26.7 IN main. Live is 26.2.3.2 with ~180 days of parts.
# Crossing 26.3 rewrites the part format, and the way back from that is a volume
# snapshot rather than a tag revert. Removing a proxy and migrating a storage
# format are two changes that deserve to fail independently, so this one holds the
# version still: same engine version, same parts, and a bad cutover is a revert.
# 26.7 remains a separate reviewed migration on its own evidence.
#
# THE CONTRACT THIS IMAGE MUST HOLD. The live StatefulSet sets no `command` and no
# `args`, so the ENTRYPOINT here is the whole contract, and every path below is
# one the cluster already has something mounted at:
#
#   /usr/bin/hanzo-datastore        the binary the entrypoint execs
#   /etc/hanzo-datastore-server/    where universe mounts config.d/*, including
#                                   paths.xml — the file that actually resolves
#                                   `path`, and which no image bakes
#   /var/lib/hanzo-datastore/       where the 200Gi PVC is mounted
#
# Spelling any of those the way `main` does (/usr/bin/datastore,
# /etc/datastore-server/, /var/lib/datastore/) does not fail. The server starts,
# reads none of the mounted config, initializes an empty database on the
# container's ephemeral layer, answers /ping 200, and reports 1/1 — green and
# holding nothing. That is the failure this file is written to avoid.
#
# Versions are pinned to what ci/docker/fasttest/Dockerfile provisions for THIS
# branch: cmake/tools.cmake sets CLANG_MINIMUM_VERSION 21, and the Rust contribs
# want the exact nightly named there. Bump these together with that file.

ARG UBUNTU_VERSION=24.04
ARG LLVM_VERSION=21
ARG RUST_TOOLCHAIN=nightly-2025-07-07

FROM ubuntu:${UBUNTU_VERSION} AS builder

ARG LLVM_VERSION
ARG RUST_TOOLCHAIN
ENV DEBIAN_FRONTEND=noninteractive

# Retry apt: a transient mirror 5xx hours into a build is an expensive way to
# learn the network blipped.
RUN printf 'Acquire::Retries "5";\n' > /etc/apt/apt.conf.d/99-datastore-build \
    && apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates curl gnupg lsb-release wget git \
        cmake ninja-build python3 xxd zstd \
        nasm yasm \
    && rm -rf /var/lib/apt/lists/*

# clang from apt.llvm.org — Ubuntu 24.04 ships clang 18, below the hard floor in
# cmake/tools.cmake. The key is pinned by hash so a compromised or swapped key
# fails here rather than silently signing a different toolchain.
RUN wget -nv -O /tmp/llvm.key https://apt.llvm.org/llvm-snapshot.gpg.key \
    && echo "5ffc7c9a9299ce774f81cada703e23ebba5bdfb0345b6c3b667b3ead7aa21c75ef62ccd74f7a8f2aa0cbe158d3068bbe  /tmp/llvm.key" | sha384sum -c \
    && gpg --dearmor -o /etc/apt/trusted.gpg.d/llvm.gpg /tmp/llvm.key \
    && echo "deb http://apt.llvm.org/$(lsb_release -cs)/ llvm-toolchain-$(lsb_release -cs)-${LLVM_VERSION} main" \
        > /etc/apt/sources.list.d/llvm.list \
    && apt-get update \
    && apt-get install --yes --no-install-recommends \
        clang-${LLVM_VERSION} lld-${LLVM_VERSION} \
        llvm-${LLVM_VERSION}-dev libclang-${LLVM_VERSION}-dev libclang-rt-${LLVM_VERSION}-dev \
        `# llvm-N (not just -dev) carries llvm-ar/ranlib/objcopy/nm/strip.` \
        `# cmake/tools.cmake resolves each by versioned name and raises` \
        `# FATAL_ERROR when one is missing, so omitting this package fails the` \
        `# build at configure — cheap to install, expensive to debug.` \
        llvm-${LLVM_VERSION} \
    && rm -rf /var/lib/apt/lists/* \
    # cmake resolves the linker as plain `ld.lld`; the apt package only ships the
    # versioned name.
    && ln -sf /usr/bin/lld-${LLVM_VERSION} /usr/bin/ld.lld \
    # Debian's llvm packaging exports import checks for targets it does not ship
    # (mlir, bolt, merge-fdata); cmake aborts on the missing files. Upstream
    # carries this same workaround.
    && sed -i '/_IMPORT_CHECK_FILES_FOR_\(mlir-\|llvm-bolt\|merge-fdata\|MLIR\)/ {s|^|#|}' \
        /usr/lib/llvm-${LLVM_VERSION}/lib/cmake/llvm/LLVMExports-*.cmake

# Rust: several contribs (corrosion-driven) are Rust, so a missing toolchain is a
# configure-time failure. The nightly is pinned because those crates use unstable
# features that move.
ENV RUSTUP_HOME=/rust/rustup CARGO_HOME=/rust/cargo
ENV PATH=/rust/cargo/bin:${PATH}
RUN curl -fsSL -o /tmp/rustup-init \
        "https://static.rust-lang.org/rustup/archive/1.28.1/x86_64-unknown-linux-gnu/rustup-init" \
    && chmod +x /tmp/rustup-init \
    && /tmp/rustup-init -y --no-modify-path --default-toolchain "${RUST_TOOLCHAIN}" \
    && rm /tmp/rustup-init \
    && rustup component add rust-src \
    && rustup target add x86_64-unknown-linux-gnu

COPY . /src
WORKDIR /src

# Submodules are fetched HERE, not by the CI checkout: the shared reusable
# (hanzoai/ci .hanzo/workflows/build.yml) runs a bare actions/checkout@v4 with no
# submodule support, so a build that assumed a populated contrib/ would fail on an
# empty directory 135 times over. update-submodules.sh is upstream's own script
# and does two things, both required: shallow-fetches each pinned SHA, then
# DELETES the third-party CMake files, without which the build picks up vendored
# cmake instead of this tree's.
RUN git config --global --add safe.directory /src \
    && ./contrib/update-submodules.sh --max-procs 16

# ENABLE_TESTS=0 is the one deviation from upstream defaults: unit_tests_dbms is a
# large fraction of the tree and this image is gated by the smoke below, on the
# real artifact. Everything else stays default ON so the capability surface
# matches what the .deb would ship — dropping the "all" switch would silently
# remove keeper, which this deployment embeds and which no error would explain.
#
# COMPILER_CACHE=disabled is the honest statement, not laziness: a missing ccache
# is a FATAL_ERROR here (FAIL_ON_UNSUPPORTED_OPTIONS_COMBINATION defaults ON), and
# nothing mounts a cache across runs, so an installed one would start cold every
# time and cache nothing for the next.
#
# PARALLEL_*_JOBS are pinned because cmake/limit_jobs.cmake sizes them with
# cmake_host_system_information, which reports the NODE rather than this
# container's cgroup — on the runner fleet that reads 8 cores while the pod is
# capped at 6, and derives link jobs from node memory the pod cannot have.
#
# 6 compile jobs is the pod's CPU limit. It was briefly 3, on a misreading of a
# failure that looked like memory and was not: the real cause was `#if
# CLICKHOUSE_CLOUD` reading a macro this tree spells DATASTORE_CLOUD, which
# -Werror,-Wundef turns into a hard error about two hours in, where it reads as
# exhaustion. That miss does not exist on this branch — the base is the release
# tag, so its macros are internally consistent and only the headers are renamed.
RUN cmake -S /src -B /build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=clang-${LLVM_VERSION} \
        -DCMAKE_CXX_COMPILER=clang++-${LLVM_VERSION} \
        -DENABLE_TESTS=0 \
        -DCOMPILER_CACHE=disabled \
        -DPARALLEL_COMPILE_JOBS=6 \
        -DPARALLEL_LINK_JOBS=1 \
    && ninja -C /build clickhouse \
    && llvm-strip-${LLVM_VERSION} /build/programs/clickhouse

FROM ubuntu:${UBUNTU_VERSION} AS runtime

ARG DEBIAN_FRONTEND=noninteractive

# uid/gid 101 fixed on purpose and created before any package: a rootless
# container cannot chown its mounted volume, so the owner has to be predictable
# from the outside. Same pair the live image uses, so the existing PVC's
# ownership still matches.
#
# bash, not just sh: the entrypoint uses readarray and [[ ]].
RUN groupadd -r hanzo-datastore --gid=101 \
    && useradd -r -g hanzo-datastore --uid=101 \
        --home-dir=/var/lib/hanzo-datastore --shell=/bin/bash hanzo-datastore \
    && apt-get update \
    && apt-get install --yes --no-install-recommends \
        bash ca-certificates locales tzdata \
    && rm -rf /var/lib/apt/lists/* /var/cache/debconf /tmp/* \
    && locale-gen en_US.UTF-8

COPY --from=builder /build/programs/clickhouse /usr/bin/hanzo-datastore

# The binary is multi-call, but its dispatch matches `datastore-*` on argv[0] and
# nothing else — a `hanzo-datastore-server` symlink silently falls through to
# `local` mode, because the prefix it carries is `hanzo-datastore-`. So these exist
# for operator convenience only, and every real invocation (here and in the
# entrypoint) uses SUBCOMMAND syntax: `hanzo-datastore server`, never
# `hanzo-datastore-server`.
RUN for tool in server client local keeper extract-from-config disks su benchmark; do \
        ln -sf /usr/bin/hanzo-datastore "/usr/bin/hanzo-datastore-$tool"; \
    done

COPY --from=builder /src/programs/server/config.xml /etc/hanzo-datastore-server/config.xml
COPY --from=builder /src/programs/server/users.xml /etc/hanzo-datastore-server/users.xml
COPY --from=builder /src/docker/server/docker_related_config.xml /etc/hanzo-datastore-server/config.d/
# Points every path at /var/lib/hanzo-datastore. universe mounts its own paths.xml
# over config.d/ as well and the two agree; this one is here so the image is
# coherent on its own rather than depending on a mount to find its data.
COPY --from=builder /src/docker/server/hanzo-paths.xml /etc/hanzo-datastore-server/config.d/
COPY --from=builder /src/docker/server/entrypoint.sh /entrypoint.sh

# ugo+Xrw, not chown: the pod may start as an arbitrary uid in no group we
# control, and it still has to write here.
RUN mkdir -p /var/lib/hanzo-datastore /var/log/hanzo-datastore-server \
        /etc/hanzo-datastore-server/config.d /etc/hanzo-datastore-server/users.d \
        /etc/hanzo-datastore-client /docker-entrypoint-initdb.d \
    && chmod ugo+Xrw -R /var/lib/hanzo-datastore /var/log/hanzo-datastore-server \
        /etc/hanzo-datastore-server /etc/hanzo-datastore-client \
    && chmod +x /entrypoint.sh

# Smoke the real artifact. A server that cannot answer a trivial query is a broken
# image, and finding that out here costs one layer instead of one rollout. The
# third assertion is the reason this image exists: the engine must name the header
# itself, with no proxy loaded, or the cutover would silently regress the wire
# back to the upstream brand.
RUN hanzo-datastore local -q 'SELECT version()' \
    && hanzo-datastore local -q 'SELECT count() > 0 FROM system.build_options' \
    && grep -qa 'X-Datastore-Query-Id' /usr/bin/hanzo-datastore \
    && ! grep -qa 'X-ClickHouse-' /usr/bin/hanzo-datastore \
    && echo 'wire: binary carries X-Datastore-*, and no X-ClickHouse- literal remains'

# 8123 HTTP, 9000 native wire protocol, 9009 interserver replication. 8123 is the
# engine's own listener here — there is no proxy in front of it and no port
# override moving it to 8124, which is exactly the change this image ships.
EXPOSE 8123 9000 9009
VOLUME /var/lib/hanzo-datastore

ENV LANG=en_US.UTF-8 \
    TZ=UTC \
    DATASTORE_CONFIG=/etc/hanzo-datastore-server/config.xml

ENTRYPOINT ["/entrypoint.sh"]
