# Hanzo Datastore — the image this repo publishes, built FROM SOURCE.
#
# Why not docker/server/Dockerfile: that one installs prebuilt .deb packages from
# packages.hanzo.ai, an apt repository we have never stood up. The hostname is a
# rename artifact — the global rebrand rewrote the upstream package host into it,
# so the Dockerfile reads as if a repo exists and the build only discovers
# otherwise at `apt-get install`. Until we run a package repo, source is the ONLY
# path that yields OUR 26.7 rather than somebody else's binary, so this is the
# one builder the pipeline uses. docker/server/* is left alone: it is upstream
# machinery for a distribution channel we do not operate, and rewriting it would
# just conflict on the next upstream merge.
#
# Cost: hours, not minutes. That is normal for this codebase — a job still
# running after two hours is compiling, not hung.
#
# Versions are pinned to what ci/docker/fasttest/Dockerfile provisions, because
# that is the toolchain this tree is actually known to compile under:
# cmake/tools.cmake hard-fails below clang 21, and the Rust contribs want the
# exact pinned nightly. Bump these together with that file, never alone.

ARG UBUNTU_VERSION=24.04
ARG LLVM_VERSION=21
ARG RUST_TOOLCHAIN=nightly-2026-03-22

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
    && rm /tmp/llvm.key \
    && CODENAME="$(lsb_release --codename --short)" \
    && echo "deb https://apt.llvm.org/${CODENAME}/ llvm-toolchain-${CODENAME}-${LLVM_VERSION} main" \
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

# Rust: several contribs (corrosion-driven) are Rust, so a missing toolchain is
# a configure-time failure. The nightly is pinned because those crates use
# unstable features that move.
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
# submodule support and exposes no knob for it, so a build that assumed a
# populated contrib/ would fail on an empty directory 135 times over. Doing it in
# the builder keeps this image buildable from any checkout, shallow or not.
#
# update-submodules.sh is upstream's own script and does two things, both
# required: shallow-fetches each pinned SHA, then DELETES the third-party CMake
# files, without which the build picks up vendored cmake instead of this tree's.
RUN git config --global --add safe.directory /src \
    && ./contrib/update-submodules.sh --max-procs 16

# ENABLE_TESTS=0 is the one deviation from upstream defaults. unit_tests_dbms is
# a large fraction of the tree, and this image is gated by CI and by the smoke
# below — not by an in-tree unit suite nobody runs from a container. Everything
# else stays default ON so the image we ship has the same capability surface the
# .deb would have: dropping ENABLE_DATASTORE_ALL would silently remove keeper,
# which a deployment can depend on and which no error message would explain.
#
# COMPILER_CACHE=disabled, because a missing ccache is a hard FATAL_ERROR here,
# not a warning: FAIL_ON_UNSUPPORTED_OPTIONS_COMBINATION defaults ON, which makes
# RECONFIGURE_MESSAGE_LEVEL fatal, and cmake/ccache.cmake takes that path when it
# finds neither ccache nor sccache. `disabled` is the honest statement rather than
# apt-installing one: nothing in this Dockerfile or in hanzoai/ci mounts a cache,
# so a compiler cache would start cold on every run and cache nothing for the next.
# Install one only together with a cache mount that outlives the layer.
#
# PARALLEL_*_JOBS, because cmake/limit_jobs.cmake sizes them with
# cmake_host_system_information, which reports the NODE and not this container's
# cgroup. On the runner fleet that reads 64311 MB / 8 cores while the pod is
# capped at 26 GiB / 6 CPU, so it derives 64311/MAX_LINKER_MEMORY(5000) = 12 link
# jobs, clamps to 8 cores, and runs 8 concurrent links budgeted at 40 GB inside a
# 26 GiB pod. That dies as SIGKILL with no Kubernetes OOM event — the kill happens
# inside the pod's own dockerd, so the kubelet never records it and the build log
# simply stops. That is exactly how it presented: the log ended mid-line on
# [11637/15284] with no error, no FAILED:, no "ninja: build stopped", while the
# runner pod itself showed restarts=0 and an empty lastState.
#
# COMPILE_JOBS is 3 and not the 6 CPU limit, and the difference is measured
# rather than modelled. limit_jobs.cmake budgets MAX_COMPILER_MEMORY=2500 per
# compile, so 6 jobs should have peaked near 15 GB and fit easily. It died anyway,
# and it died in Functions/FunctionsConversion_impl*.cpp — the cluster upstream
# had to split into impl00..impl27 precisely because one translation unit could
# not be built. 2500 is an average across ~15k targets and those TUs are the tail
# it does not describe: 6 concurrent ones exhausted 26 GiB, so each must exceed
# ~3.9 GB. 3 jobs holds even if the true peak is 7 GB apiece. Half the cores idle
# during that stretch is the price of the build finishing at all; a run that dies
# at 75% has already spent three hours to buy nothing.
#
# The durable fix is not a smaller number here. git-runner is 20 replicas packed
# 10-per-node, each requesting 4Gi but limited to 26Gi — 260Gi of limit on a
# 62.8 GiB box. Raising this pod's limit would only move the kill to the node,
# where it is equally invisible. Right-sizing that fleet is a platform change.
RUN cmake -S /src -B /build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=clang-${LLVM_VERSION} \
        -DCMAKE_CXX_COMPILER=clang++-${LLVM_VERSION} \
        -DENABLE_TESTS=0 \
        -DCOMPILER_CACHE=disabled \
        -DPARALLEL_COMPILE_JOBS=3 \
        -DPARALLEL_LINK_JOBS=1 \
    && ninja -C /build datastore \
    && llvm-strip-${LLVM_VERSION} /build/programs/datastore

FROM ubuntu:${UBUNTU_VERSION} AS runtime

ARG DEBIAN_FRONTEND=noninteractive

# uid/gid 101 fixed on purpose and created before any package: a rootless
# container cannot chown its mounted volume, so the owner has to be predictable
# from the outside. Same pair upstream uses, so an existing volume's ownership
# still matches.
RUN groupadd -r datastore --gid=101 \
    && useradd -r -g datastore --uid=101 --home-dir=/var/lib/datastore --shell=/bin/bash datastore \
    && apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates locales tzdata \
    && rm -rf /var/lib/apt/lists/* /var/cache/debconf /tmp/* \
    && locale-gen en_US.UTF-8

COPY --from=builder /build/programs/datastore /usr/bin/datastore

# The binary is multi-call: it dispatches on argv[0], and the build already emits
# these as symlinks beside it. Only the ones the entrypoint and day-to-day
# operation actually invoke are recreated here — the full set is a package
# concern, not a container one.
RUN for tool in server client local keeper extract-from-config disks su benchmark; do \
        ln -sf /usr/bin/datastore "/usr/bin/datastore-$tool"; \
    done

COPY --from=builder /src/programs/server/config.xml /etc/datastore-server/config.xml
COPY --from=builder /src/programs/server/users.xml /etc/datastore-server/users.xml
COPY --from=builder /src/docker/server/docker_related_config.xml /etc/datastore-server/config.d/
# System-log retention overlay — bounds every system.*_log table with a 3-day TTL
# and caps text_log at `warning`. 2026-07: system.text_log reached ~115 GB with
# no TTL and filled the data disk, taking down api.hanzo.ai. It ships in the
# image so a fresh instance is bounded before anyone remembers to configure it.
COPY --from=builder /src/docker/server/datastore-log-retention.xml /etc/datastore-server/config.d/
COPY --from=builder /src/docker/server/entrypoint.sh /entrypoint.sh

# ugo+Xrw, not chown: OpenShift and friends start the container as an arbitrary
# uid that is in no group we control, and it still has to write here.
RUN mkdir -p /var/lib/datastore /var/log/datastore-server /etc/datastore-server/config.d /etc/datastore-client /docker-entrypoint-initdb.d \
    && chmod ugo+Xrw -R /var/lib/datastore /var/log/datastore-server /etc/datastore-server /etc/datastore-client \
    && chmod +x /entrypoint.sh

# Smoke the binary at build time. A server that cannot answer a trivial query is
# a broken image, and finding that out here costs one layer instead of one
# rollout. It also pins the version into the build log.
RUN datastore-local -q 'SELECT version()' \
    && datastore-local -q 'SELECT count() > 0 FROM system.build_options'

# 8123 HTTP, 9000 native wire protocol, 9009 interserver replication.
EXPOSE 8123 9000 9009
VOLUME /var/lib/datastore

ENV LANG=en_US.UTF-8 \
    TZ=UTC \
    DATASTORE_CONFIG=/etc/datastore-server/config.xml

ENTRYPOINT ["/entrypoint.sh"]
