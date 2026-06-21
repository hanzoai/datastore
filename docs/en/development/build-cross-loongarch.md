---
description: 'Guide for building Datastore from source for the LoongArch64 architecture'
sidebar_label: 'Build on Linux for LoongArch64'
sidebar_position: 35
slug: /development/build-cross-loongarch
title: 'Build on Linux for LoongArch64'
doc_type: 'guide'
---

Datastore has experimental support for LoongArch64

## Build Datastore {#build-datastore}

The llvm version required for building must be greater than or equal to 21.1.0.

```bash
cd Datastore
mkdir build-loongarch64
cmake . -Bbuild-loongarch64 -DCMAKE_TOOLCHAIN_FILE=cmake/linux/toolchain-loongarch64.cmake
ninja -C build-loongarch64
```

The resulting binary will run only on Linux with the LoongArch64 CPU architecture.
