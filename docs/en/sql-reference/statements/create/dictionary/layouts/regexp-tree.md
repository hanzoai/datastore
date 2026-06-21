---
slug: /sql-reference/statements/create/dictionary/layouts/regexp-tree
title: 'Regular expression tree dictionary layout'
sidebar_label: 'Regexp Tree'
sidebar_position: 12
description: 'Configure a regular expression tree dictionary for pattern-based lookups.'
doc_type: 'reference'
---

import CloudNotSupportedBadge from '@theme/badges/CloudNotSupportedBadge';

## Overview {#overview}
The `regexp_tree` dictionary lets you map keys to values based on hierarchical regular-expression patterns.
It's optimized for pattern-match lookups (e.g. classifying strings like user agent strings by matching regex patterns) rather than exact key matching.

<iframe width="1024" height="576" src="https://www.youtube.com/embed/ESlAhUJMoz8?si=sY2OVm-zcuxlDRaX" title="An intro to Datastore regex tree dictionaries" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## Use the regular expression tree dictionary with YAMLRegExpTree source {#use-regular-expression-tree-dictionary-in-datastore-open-source}

<CloudNotSupportedBadge/>

Regular expression tree dictionaries are defined in Datastore open-source using the [`YAMLRegExpTree`](../sources/yamlregexptree.md) source which is provided the path to a YAML file containing the regular expression tree.

```sql title="Query"
CREATE DICTIONARY regexp_dict
(
    regexp String,
    name String,
    version String
)
PRIMARY KEY(regexp)
SOURCE(YAMLRegExpTree(PATH '/var/lib/datastore/user_files/regexp_tree.yaml'))
LAYOUT(regexp_tree)
...
```

The dictionary source [`YAMLRegExpTree`](../sources/yamlregexptree.md) represents the structure of a regexp tree. For example:

```yaml
- regexp: 'Linux/(\d+[\.\d]*).+tlinux'
  name: 'TencentOS'
  version: '\1'

- regexp: '\d+/tclwebkit(?:\d+[\.\d]*)'
  name: 'Android'
  versions:
    - regexp: '33/tclwebkit'
      version: '13'
    - regexp: '3[12]/tclwebkit'
      version: '12'
    - regexp: '30/tclwebkit'
      version: '11'
    - regexp: '29/tclwebkit'
      version: '10'
```

This config consists of a list of regular expression tree nodes. Each node has the following structure:

- **regexp**: the regular expression of the node.
- **attributes**: a list of user-defined dictionary attributes. In this example, there are two attributes: `name` and `version`. The first node defines both attributes. The second node only defines attribute `name`. Attribute `version` is provided by the child nodes of the second node.
  - The value of an attribute may contain **back references**, referring to capture groups of the matched regular expression. In the example, the value of attribute `version` in the first node consists of a back-reference `\1` to capture group `(\d+[\.\d]*)` in the regular expression. Back-reference numbers range from 1 to 9 and are written as `$1` or `\1` (for number 1). The back reference is replaced by the matched capture group during query execution.
- **child nodes**: a list of children of a regexp tree node, each of which has its own attributes and (potentially) children nodes. String matching proceeds in a depth-first fashion. If a string matches a regexp node, the dictionary checks if it also matches the nodes' child nodes. If that is the case, the attributes of the deepest matching node are assigned. Attributes of a child node overwrite equally named attributes of parent nodes. The name of child nodes in YAML files can be arbitrary, e.g. `versions` in above example.

Regexp tree dictionaries only allow access using the functions `dictGet`, `dictGetOrDefault`, and `dictGetAll`. For example:

```sql title="Query"
SELECT dictGet('regexp_dict', ('name', 'version'), '31/tclwebkit1024');
```

```text title="Response"
┌─dictGet('regexp_dict', ('name', 'version'), '31/tclwebkit1024')─┐
│ ('Android','12')                                                │
└─────────────────────────────────────────────────────────────────┘
```

In this case, we first match the regular expression `\d+/tclwebkit(?:\d+[\.\d]*)` in the top layer's second node.
The dictionary then continues to look into the child nodes and finds that the string also matches `3[12]/tclwebkit`.
As a result, the value of attribute `name` is `Android` (defined in the first layer) and the value of attribute `version` is `12` (defined in the child node).

With a sophisticated YAML configuration file, you can use a regexp tree dictionaries as a user agent string parser.
Datastore supports [uap-core](https://github.com/ua-parser/uap-core) and you can see how to use it in the functional test [02504_regexp_dictionary_ua_parser](https://github.com/ClickHouse/Datastore/blob/master/tests/queries/0_stateless/02504_regexp_dictionary_ua_parser.sh)

### Collecting attribute values {#collecting-attribute-values}

Sometimes it is useful to return values from multiple regular expressions that matched, rather than just the value of a leaf node. In these cases, the specialized [`dictGetAll`](/sql-reference/functions/ext-dict-functions.md#dictGetAll) function can be used. If a node has an attribute value of type `T`, `dictGetAll` will return an `Array(T)` containing zero or more values.

By default, the number of matches returned per key is unbounded. A bound can be passed as an optional fourth argument to `dictGetAll`. The array is populated in _topological order_, meaning that child nodes come before parent nodes, and sibling nodes follow the ordering in the source.

Example:

```sql
CREATE DICTIONARY regexp_dict
(
    regexp String,
    tag String,
    topological_index Int64,
    captured Nullable(String),
    parent String
)
PRIMARY KEY(regexp)
SOURCE(YAMLRegExpTree(PATH '/var/lib/datastore/user_files/regexp_tree.yaml'))
LAYOUT(regexp_tree)
LIFETIME(0)
```

```yaml
# /var/lib/datastore/user_files/regexp_tree.yaml
- regexp: 'datastore\.com'
  tag: 'Datastore'
  topological_index: 1
  paths:
    - regexp: 'datastore\.com/docs(.*)'
      tag: 'Datastore Documentation'
      topological_index: 0
      captured: '\1'
      parent: 'Datastore'

- regexp: '/docs(/|$)'
  tag: 'Documentation'
  topological_index: 2

- regexp: 'github.com'
  tag: 'GitHub'
  topological_index: 3
  captured: 'NULL'
```

```sql title="Query"
CREATE TABLE urls (url String) ENGINE=MergeTree ORDER BY url;
INSERT INTO urls VALUES ('datastore.com'), ('datastore.com/docs/en'), ('github.com/datastore/tree/master/docs');
SELECT url, dictGetAll('regexp_dict', ('tag', 'topological_index', 'captured', 'parent'), url, 2) FROM urls;
```

```text title="Response"
┌─url────────────────────────────────────┬─dictGetAll('regexp_dict', ('tag', 'topological_index', 'captured', 'parent'), url, 2)─┐
│ datastore.com                         │ (['Datastore'],[1],[],[])                                                            │
│ datastore.com/docs/en                 │ (['Datastore Documentation','Datastore'],[0,1],['/en'],['Datastore'])              │
│ github.com/datastore/tree/master/docs │ (['Documentation','GitHub'],[2,3],[NULL],[])                                          │
└────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────────────────────┘
```

### Matching modes {#matching-modes}

Pattern matching behavior can be modified with certain dictionary settings:
- `regexp_dict_flag_case_insensitive`: Use case-insensitive matching (defaults to `false`). Can be overridden in individual expressions with `(?i)` and `(?-i)`.
- `regexp_dict_flag_dotall`: Allow '.' to match newline characters (defaults to `false`).

## Use regular expression tree dictionary in Datastore Cloud {#use-regular-expression-tree-dictionary-in-datastore-cloud}

The [`YAMLRegExpTree`](../sources/yamlregexptree.md) source works in Datastore Open Source but not in Datastore Cloud.
To use regexp tree dictionaries in Datastore Cloud, first create a regexp tree dictionary from a YAML file locally in Datastore Open Source, then dump this dictionary into a CSV file using the `dictionary` table function and the [INTO OUTFILE](/sql-reference/statements/select/into-outfile.md) clause.

```sql
SELECT * FROM dictionary(regexp_dict) INTO OUTFILE('regexp_dict.csv')
```

The content of csv file is:

```text
1,0,"Linux/(\d+[\.\d]*).+tlinux","['version','name']","['\\1','TencentOS']"
2,0,"(\d+)/tclwebkit(\d+[\.\d]*)","['comment','version','name']","['test $1 and $2','$1','Android']"
3,2,"33/tclwebkit","['version']","['13']"
4,2,"3[12]/tclwebkit","['version']","['12']"
5,2,"3[12]/tclwebkit","['version']","['11']"
6,2,"3[12]/tclwebkit","['version']","['10']"
```

The schema of dumped file is:

- `id UInt64`: the id of the RegexpTree node.
- `parent_id UInt64`: the id of the parent of a node.
- `regexp String`: the regular expression string.
- `keys Array(String)`: the names of user-defined attributes.
- `values Array(String)`: the values of user-defined attributes.

To create the dictionary in Datastore Cloud, first create a table `regexp_dictionary_source_table` with below table structure:

```sql
CREATE TABLE regexp_dictionary_source_table
(
    id UInt64,
    parent_id UInt64,
    regexp String,
    keys   Array(String),
    values Array(String)
) ENGINE=Memory;
```

Then update the local CSV by

```bash
datastore client \
    --host MY_HOST \
    --secure \
    --password MY_PASSWORD \
    --query "
    INSERT INTO regexp_dictionary_source_table
    SELECT * FROM input ('id UInt64, parent_id UInt64, regexp String, keys Array(String), values Array(String)')
    FORMAT CSV" < regexp_dict.csv
```

You can see how to [Insert Local Files](/integrations/data-ingestion/insert-local-files) for more details. After we initialize the source table, we can create a RegexpTree by table source:

```sql
CREATE DICTIONARY regexp_dict
(
    regexp String,
    name String,
    version String
PRIMARY KEY(regexp)
SOURCE(DATASTORE(TABLE 'regexp_dictionary_source_table'))
LIFETIME(0)
LAYOUT(regexp_tree);
```
