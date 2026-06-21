---
description: 'Describes available third-party proxy solutions for Datastore'
sidebar_label: 'Proxies'
sidebar_position: 29
slug: /interfaces/third-party/proxy
title: 'Proxy Servers from Third-party Developers'
doc_type: 'reference'
---

## chproxy {#chproxy}

[chproxy](https://github.com/Vertamedia/chproxy), is an HTTP proxy and load balancer for Datastore database.

Features:

- Per-user routing and response caching.
- Flexible limits.
- Automatic SSL certificate renewal.

Implemented in Go.

## KittenHouse {#kittenhouse}

[KittenHouse](https://github.com/VKCOM/kittenhouse) is designed to be a local proxy between Datastore and application server in case it's impossible or inconvenient to buffer INSERT data on your application side.

Features:

- In-memory and on-disk data buffering.
- Per-table routing.
- Load-balancing and health checking.

Implemented in Go.

## Datastore-Bulk {#datastore-bulk}

[Datastore-Bulk](https://github.com/nikepan/datastore-bulk) is a simple Datastore insert collector.

Features:

- Group requests and send by threshold or interval.
- Multiple remote servers.
- Basic authentication.

Implemented in Go.
