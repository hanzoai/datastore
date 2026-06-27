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
