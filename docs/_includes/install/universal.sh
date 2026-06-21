#!/bin/sh -e

OS=$(uname -s)
ARCH=$(uname -m)

DIR=

if [ "${OS}" = "Linux" ]
then
    if [ "${ARCH}" = "x86_64" -o "${ARCH}" = "amd64" ]
    then
        # Require at least x86-64 + SSE4.2 (introduced in 2006). On older hardware fall back to plain x86-64 (introduced in 1999) which
        # guarantees at least SSE2. The caveat is that plain x86-64 builds are much less tested than SSE 4.2 builds.
        HAS_SSE42=$(grep sse4_2 /proc/cpuinfo)
        if [ "${HAS_SSE42}" ]
        then
            if ldd --version 2>&1 | grep -q musl
            then
                DIR="amd64musl"
            else
                DIR="amd64"
            fi
        else
            DIR="amd64compat"
        fi
    elif [ "${ARCH}" = "aarch64" -o "${ARCH}" = "arm64" ]
    then
        # Dispatch between standard and compatibility builds, see cmake/cpu_features.cmake for details. Unfortunately, (1) the ARM ISA level
        # cannot be read directly, we need to guess from the "features" in /proc/cpuinfo, and (2) the flags in /proc/cpuinfo are named
        # differently than the flags passed to the compiler in cpu_features.cmake.
        HAS_ARMV82=$(grep -m 1 'Features' /proc/cpuinfo | awk '/asimd/ && /sha1/ && /aes/ && /atomics/ && /lrcpc/')
        if [ "${HAS_ARMV82}" ]
        then
            DIR="aarch64"
        else
            DIR="aarch64v80compat"
        fi
    elif [ "${ARCH}" = "powerpc64le" -o "${ARCH}" = "ppc64le" ]
    then
        DIR="powerpc64le"
    elif [ "${ARCH}" = "riscv64" ]
    then
        DIR="riscv64"
    elif [ "${ARCH}" = "s390x" ]
    then
        DIR="s390x"
    fi
elif [ "${OS}" = "FreeBSD" ]
then
    if [ "${ARCH}" = "x86_64" -o "${ARCH}" = "amd64" ]
    then
        DIR="freebsd"
    fi
elif [ "${OS}" = "Darwin" ]
then
    if [ "${ARCH}" = "x86_64" -o "${ARCH}" = "amd64" ]
    then
        DIR="macos"
    elif [ "${ARCH}" = "aarch64" -o "${ARCH}" = "arm64" ]
    then
        DIR="macos-aarch64"
    fi
fi

if [ -z "${DIR}" ]
then
    echo "Operating system '${OS}' / architecture '${ARCH}' is unsupported."
    exit 1
fi

clickhouse_download_filename_prefix="datastore"
datastore="$clickhouse_download_filename_prefix"

if [ -f "$datastore" ]
then
    read -p "Datastore binary ${datastore} already exists. Overwrite? [y/N] " answer
    if [ "$answer" = "y" -o "$answer" = "Y" ]
    then
        rm -f "$datastore"
    else
        i=0
        while [ -f "$datastore" ]
        do
            datastore="${clickhouse_download_filename_prefix}.${i}"
            i=$(($i+1))
        done
    fi
fi

URL="https://builds.datastore.com/master/${DIR}/datastore"
echo
echo "Will download ${URL} into ${datastore}"
echo
curl "${URL}" -o "${datastore}" && chmod a+x "${datastore}" || exit 1
echo
echo "Successfully downloaded the Datastore binary, you can run it as:
    ./${datastore}"

echo
echo "You can also install it:
sudo ./${datastore} install"
