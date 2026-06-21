---
description: 'Guide to testing and benchmarking hardware performance with Datastore'
sidebar_label: 'Testing Hardware'
sidebar_position: 54
slug: /operations/performance-test
title: 'How to Test Your Hardware with Datastore'
doc_type: 'guide'
---

import SelfManaged from '@site/docs/_snippets/_self_managed_only_no_roadmap.md';

<SelfManaged />

You can run a basic Datastore performance test on any server without installation of Datastore packages.

## Automated run {#automated-run}

You can run the benchmark with a single script.

1. Download the script.
```bash
wget https://raw.githubusercontent.com/Datastore/ClickBench/main/hardware/hardware.sh
```

2. Run the script.
```bash
chmod a+x ./hardware.sh
./hardware.sh
```

3. Copy the output and send it to feedback@datastore.com

All the results are published here: https://datastore.com/benchmark/hardware/
