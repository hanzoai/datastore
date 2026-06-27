# Keeper-on-Quasar proof

`keeper_quasar_poc.cpp` drives the **real** `KeeperStateMachine<KeeperMemoryStorage>`
— the exact class `ReplicatedMergeTree` coordinates through — with native Lux
consensus (Quasar, `libluxconsensus`) instead of NuRaft.

It is the concrete demonstration of the Raft→Quasar migration seam: Keeper is two
separable things, a ZooKeeper API (`KeeperStateMachine` over `KeeperStorage`) and a
consensus engine (NuRaft) that orders the log and calls `commit`. This program keeps
the state machine untouched and replaces only the engine — Quasar orders the log and
the state machine is applied on Quasar finality, in two phases exactly as the
dispatcher drives NuRaft (`preprocess` at append, `commit` at quorum/finality).

The state machine cannot tell the difference. That is the whole thesis.

## Build & run

This example is opt-in and never part of a normal build. It needs a built `pkg/c`
checkout of [luxfi/consensus](https://github.com/luxfi/consensus):

```bash
# 1. build libluxconsensus (static)
git clone https://github.com/luxfi/consensus
cd consensus/pkg/c && make lib/libluxconsensus.a
LUXC=$(pwd)

# 2. configure datastore with examples + this target enabled
cd /path/to/datastore/build
cmake -DENABLE_EXAMPLES=1 -DLUXCONSENSUS_DIR="$LUXC" ..

# 3. build & run
ninja keeper_quasar_poc
./src/Coordination/examples/keeper_quasar_poc
```

Expected tail (exit 0):

```
== REAL Keeper state machine reached consensus on Quasar — zero Raft, zero ZK ensemble ==
```

The program asserts the real `KeeperStorage` tree reflects every committed
ZooKeeper request, applied exactly once, in Quasar-decided log order, and exits
non-zero on any mismatch.

> Build-verified on a 26.6.1.1 source tree (aarch64, clang-21): all 10 coordination
> writes preprocessed, ordered through Quasar, finalized and committed to the real
> `KeeperStorage`; `blocks_accepted == 10`; assertions pass.

# QuasarKeeperConsensus — the reusable engine

`keeper_quasar_poc` proves the seam inline; `QuasarKeeperConsensus`
(`src/Coordination/QuasarKeeperConsensus.h`) is the same mechanism factored into a
reusable engine class — the component that replaces the NuRaft `raft_server` slot.
It exposes the contract the dispatcher needs: `append(batch)` orders + commits a
batch through the state machine and returns the committed log index;
`isLeader`/`isLeaderAlive`/`lastCommittedIndex` for the dispatcher's routing and
read-after-write barrier.

`keeper_quasar_engine_test.cpp` drives that engine against the real
`KeeperStateMachine<KeeperMemoryStorage>` over two batches and asserts the full
commit contract: `append` returns accepted + correct last log index; the
`commit_callback` fires once per entry in strict log order; `KeeperContext`'s
committed index advances; the real `KeeperStorage` tree is exactly correct
(parents before children, both `SET`s applied in order). Build + run:

```bash
ninja keeper_quasar_engine_test
./src/Coordination/examples/keeper_quasar_engine_test
# == QuasarKeeperConsensus drives the real Keeper commit path — zero Raft ==
```

> Build-verified on a 26.6.1.1 source tree (aarch64, clang-21): 2 batches, 9
> ordered commits, monotonic committed index, real `KeeperStorage` correct.

## Staged plan to drop NuRaft entirely

Replacing a Raft-backed ZooKeeper is staged so each step lands under green tests,
never breaking everything at once:

1. **Engine proven against real types** (this directory) — single-node ordering +
   commit through the real state machine. ✅
2. **Engine into `dbms` + `KeeperServer` uses it** — wire `libluxconsensus` as a
   contrib, move `QuasarKeeperConsensus.cpp` into `dbms`, and make `KeeperServer`
   construct it instead of `nuraft::raft_server` for the single-node path; the
   whole NuRaft surface (`KeeperServer.cpp`) the dispatcher depends on
   (`putRequestBatch`, leadership, snapshots) is satisfied by the engine.
3. **Multi-node Quasar over ZAP** — replace NuRaft's asio peer transport with ZAP;
   leadership and membership derive from the Quasar validator set.
4. **Excise residual `nuraft::` data types** (`buffer`/`log_entry`/`snapshot`) and
   **delete `contrib/NuRaft`** + its cmake. ZooKeeper *API* (`KeeperStorage`) stays;
   the Raft *engine* is gone.
