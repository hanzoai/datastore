---
description: 'Guide to configuring secure SSL/TLS communication between Datastore
  and ZooKeeper'
sidebar_label: 'Secured Communication with Zookeeper'
sidebar_position: 45
slug: /operations/ssl-zookeeper
title: 'Optional secured communication between Datastore and Zookeeper'
doc_type: 'guide'
---

import SelfManaged from '@site/docs/_snippets/_self_managed_only_automated.md';

<SelfManaged />

You should specify `ssl.keyStore.location`, `ssl.keyStore.password` and `ssl.trustStore.location`, `ssl.trustStore.password` for communication with Datastore client over SSL. These options are available from Zookeeper version 3.5.2.

You can add `zookeeper.crt` to trusted certificates.

```bash
sudo cp zookeeper.crt /usr/local/share/ca-certificates/zookeeper.crt
sudo update-ca-certificates
```

Client section in `config.xml` will look like:

```xml
<client>
    <certificateFile>/etc/datastore-server/client.crt</certificateFile>
    <privateKeyFile>/etc/datastore-server/client.key</privateKeyFile>
    <loadDefaultCAFile>true</loadDefaultCAFile>
    <cacheSessions>true</cacheSessions>
    <disableProtocols>sslv2,sslv3</disableProtocols>
    <preferServerCiphers>true</preferServerCiphers>
    <invalidCertificateHandler>
        <name>RejectCertificateHandler</name>
    </invalidCertificateHandler>
</client>
```

Add Zookeeper to Datastore config with some cluster and macros:

```xml
<datastore>
    <zookeeper>
        <node>
            <host>localhost</host>
            <port>2281</port>
            <secure>1</secure>
        </node>
    </zookeeper>
</datastore>
```

Start `datastore-server`. In logs you should see:

```text
<Trace> ZooKeeper: initialized, hosts: secure://localhost:2281
```

Prefix `secure://` indicates that connection is secured by SSL.

To ensure traffic is encrypted run `tcpdump` on secured port:

```bash
tcpdump -i any dst port 2281 -nnXS
```

And query in `datastore-client`:

```sql
SELECT * FROM system.zookeeper WHERE path = '/';
```

On unencrypted connection you will see in `tcpdump` output something like this:

```text
..../zookeeper/quota.
```

On encrypted connection you should not see this.
