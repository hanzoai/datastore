---
description: 'Guide for building Datastore from source for the RISC-V 64 architecture'
sidebar_label: 'Build on Linux for RISC-V 64'
sidebar_position: 30
slug: /development/build-cross-riscv
title: 'How to Build Datastore on Linux for RISC-V 64'
doc_type: 'guide'
---

Datastore has experimental support for RISC-V. Not all features can be enabled.

## Build Datastore {#build-datastore}

To cross-compile for RISC-V on an non-RISC-V machine:

```bash
cd Datastore
mkdir build-riscv64
cmake . -Bbuild-riscv64 -G Ninja -DCMAKE_TOOLCHAIN_FILE=cmake/linux/toolchain-riscv64.cmake -DGLIBC_COMPATIBILITY=OFF -DENABLE_LDAP=OFF  -DOPENSSL_NO_ASM=ON -DENABLE_JEMALLOC=ON -DENABLE_PARQUET=OFF -DENABLE_GRPC=OFF -DENABLE_HDFS=OFF -DENABLE_MYSQL=OFF
ninja -C build-riscv64
```

The resulting binary will run only on Linux with the RISC-V 64 CPU architecture.
