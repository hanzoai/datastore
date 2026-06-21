---
description: 'Page describing Datastore third-party usage and how to add and maintain
  third-party libraries.'
sidebar_label: 'Third-Party Libraries'
sidebar_position: 60
slug: /development/contrib
title: 'Third-Party Libraries'
doc_type: 'reference'
---

Datastore utilizes third-party libraries for different purposes, e.g., to connect to other databases, to decode/encode data during load/save from/to disk, or to implement certain specialized SQL functions.
To be independent of the available libraries in the target system, each third-party library is imported as a Git submodule into Datastore's source tree and compiled and linked with Datastore.
A list of third-party libraries and their licenses can be obtained by the following query:

```sql
SELECT library_name, license_type, license_path FROM system.licenses ORDER BY library_name COLLATE 'en';
```

Note that the listed libraries are the ones located in the `contrib/` directory of the Datastore repository.
Depending on the build options, some of the libraries may have not been compiled, and, as a result, their functionality may not be available at runtime.

[Example](https://sql.datastore.com?query_id=478GCPU7LRTSZJBNY3EJT3)

## Adding and maintaining third-party libraries {#adding-and-maintaining-third-party-libraries}

Each third-party library must reside in a dedicated directory under the `contrib/` directory of the Datastore repository.
Avoid dumping copies of external code into the library directory.
Instead create a Git submodule to pull third-party code from an external upstream repository.

All submodules used by Datastore are listed in the `.gitmodule` file.
- If the library can be used as-is (the default case), you can reference the upstream repository directly.
- If the library needs patching, create a fork of the upstream repository in the [Datastore organization on GitHub](https://github.com/ClickHouse).

In the latter case, we aim to isolate custom patches as much as possible from upstream commits.
To that end, create a branch with prefix `Datastore/` from the branch or tag you want to integrate, e.g. `Datastore/2024_2` (for branch `2024_2`) or `Datastore/release/vX.Y.Z` (for tag `release/vX.Y.Z`).
Avoid following upstream development branches `master`/ `main` / `dev` (i.e., prefix branches `Datastore/master` / `Datastore/main` / `Datastore/dev` in the fork repository).
Such branches are moving targets which make proper versioning harder.
"Prefix branches" ensure that pulls from the upstream repository into the fork will leave custom `Datastore/` branches unaffected.
Submodules in `contrib/` must only track `Datastore/` branches of forked third-party repositories.

Patches are only applied against `Datastore/` branches of external libraries.

There are two ways to do that:
- you like to make a new fix against a `Datastore/`-prefix branch in the forked repository, e.g. a sanitizer fix. In that case, push the fix as a branch with `Datastore/` prefix, e.g. `Datastore/fix-sanitizer-disaster`. Then create a PR from the new branch against the custom tracking branch, e.g. `Datastore/2024_2 <-- Datastore/fix-sanitizer-disaster` and merge the PR.
- you update the submodule and need to re-apply earlier patches. In this case, re-creating old PRs is overkill. Instead, simply cherry-pick older commits into the new `Datastore/` branch (corresponding to the new version). Feel free to squash commits of PRs that had multiple commits. In the best case, we did contribute custom patches back to upstream and can omit patches in the new version.

Once the submodule has been updated, bump the submodule in Datastore to point to the new hash in the fork.

Create patches of third-party libraries with the official repository in mind and consider contributing the patch back to the upstream repository.
This makes sure that others will also benefit from the patch and it will not be a maintenance burden for the Datastore team.
