# gas2500x test plan (Local_DPoS_Setup)

Field test for the Gas2500x tier (625 gwei) shipped by three XDPoSChain
commits on `dev-upgrade` (baseline `5501a1f1e5`, all three included):

- **`7823fc7f`** (#2516) — `Gas2500xBlock` fork: the pool floor, the chain
  default gas price and the EIP-1559 base fee move 12.5 gwei → 625 gwei, and
  `--gasprice` can no longer move the floor.
- **`68695806`** (#2532) — on a floor rise the pool sweeps every non-special
  tx below the new floor from pending and queue; swept txs never come back.
- **`06582401`** (#2541) — the local tracker holds back below-floor local
  txs and revives them when the floor drops; below-floor rejects never
  enter the tracker.

## Test environment

- OS: Ubuntu 24.04.4 LTS (Linux 7.0.0, x86_64)
- bash: GNU bash 5.2.21
- jq: jq 1.7
- cast: foundry `cast` 1.8.1
- curl: curl 8.5.0
- Go: go 1.25.14 (builds the XDC binaries)

## Quick start

```bash
cp .env.sample .env                 # once: sender/node keys (S1–S5, P3)
cd ~/XDPoSChain && make all         # once: XDC binaries
./gas2500x-run.sh                   # reset → start network → 53 cases → stop
./stop-network.sh                   # only after an interrupted run
```

The runner does the whole lifecycle itself — wipes the datadirs, starts the
network, runs every case, stops the network.

## Topology

| Node | Role                       | RPC  | Metrics |
| ---- | -------------------------- | ---- | ------- |
| pn0  | masternode, genesis signer | 8545 | 6060    |
| pn1  | masternode, genesis signer | 8546 | 6061    |
| pn2  | masternode, genesis signer | 8547 | 6062    |
| pn3  | observer, non-signer       | 8548 | 6063    |

Masternodes keep sealing the whole run — 2/3 quorum is intact. All pool
cases submit via pn3, so tracker/journal state lands there and the rewind
experiment touches pn3 only.

## Key numbers

- Gas50x floor: 12.5 gwei
- Gas2500x floor: 625 gwei
- gas2500xBlock: 120
- Tracker recheck: 10s after start, then every 60 s (`locals.recheckInterval`)

## Test scripts

```text
Local_DPoS_Setup/
├── gas2500x-run.sh          # the only entry point
├── gas2500x-test.md         # this document
├── results/
│   └── gas2500x-<ts>.log    # runner transcript (start/end tally inside)
└── tests/
    ├── gas2500x-lib.sh      # shared helpers
    ├── t01.sh … t23.sh      # pre-fork
    ├── t24.sh … t34.sh      # fork sweep
    ├── t35.sh … t42.sh      # post-fork probes
    ├── t43.sh … t45.sh      # rewind saga
    └── t46.sh … t53.sh      # creation matrix
```

## Test cases

53 cases, one verifiable result each. The fork (block 120) splits them into
mirrored pairs, one case per side (T02/T27 reject, T09/T29 at-floor seal,
T13/T32 replace, T21 parks / T30 seals the survivor, T15/T42 default price);
observation-only cases add no submissions (T10, T22, T24–T26, T34, T44,
T45); the survivor chain T21→T24→T30 and the rewind saga T43→T44→T45 are
fixed state chains (via `/tmp` markers); the creation matrix t46–t53 cases
are mutually independent. Missed the pre-fork window? Just re-run the runner
— it resets the chain.

One benign interference: every ~30 s each masternode broadcasts a consensus
signing tx (`gasPrice` 0) that transiently enters every pool as
executable-special for ~2 s. The pending-side assertions (T11, T12, T34,
T45) therefore count only non-signing txs (shape-based filter).

Out of scope (unit-test covered): TRC21/XDCx tier pricing, concurrent
TrackAll races, Osaka gas-cap discard, `Gas2500xBlock == nil`, special txs.

Case names are verb-object and paren-free. The table below is generated
from the scripts' `begin_case` args — regenerate it after renaming a case.

| Case                | Name                                                              |
| ------------------- | ----------------------------------------------------------------- |
| [T01](tests/t01.sh) | fund the senders                                                  |
| [T02](tests/t02.sh) | reject a tx 1 wei below the pre-fork floor                        |
| [T03](tests/t03.sh) | verify eth_gasPrice on the pre-fork tier                          |
| [T04](tests/t04.sh) | verify eth_maxPriorityFeePerGas on the pre-fork tier              |
| [T05](tests/t05.sh) | verify the block baseFeePerGas on the pre-fork tier               |
| [T06](tests/t06.sh) | verify eth_estimateGas on the pre-fork tier                       |
| [T07](tests/t07.sh) | reject a legacy creation below the pre-fork floor                 |
| [T08](tests/t08.sh) | reject a 1559 creation below the pre-fork floor                   |
| [T09](tests/t09.sh) | seal a tx at the pre-fork floor of 12.5 gwei                      |
| [T10](tests/t10.sh) | verify the below-floor reject is not tracked                      |
| [T11](tests/t11.sh) | seed 10 queued txs from S1                                        |
| [T12](tests/t12.sh) | seed 8 queued txs from S2                                         |
| [T13](tests/t13.sh) | replace a pre-fork queued tx at the same nonce                    |
| [T14](tests/t14.sh) | verify txpool_contentFrom mirrors the pre-fork queue              |
| [T15](tests/t15.sh) | seal a tx at the pre-fork default gas price                       |
| [T16](tests/t16.sh) | seal a legacy creation at the pre-fork floor                      |
| [T17](tests/t17.sh) | seal a legacy creation above the pre-fork floor                   |
| [T18](tests/t18.sh) | seal a 1559 creation at the pre-fork floor                        |
| [T19](tests/t19.sh) | seal a tip-0 creation at the pre-fork base fee                    |
| [T20](tests/t20.sh) | verify the journal load keeps the pre-fork replacement            |
| [T21](tests/t21.sh) | park a 700 gwei tx from S4 for the sweep                          |
| [T22](tests/t22.sh) | verify the queued batch is not sealed                             |
| [T23](tests/t23.sh) | verify sealing continuity across the fork                         |
| [T24](tests/t24.sh) | verify the fork sweep empties the queue                           |
| [T25](tests/t25.sh) | verify the sweep meter and drop log on pn3                        |
| [T26](tests/t26.sh) | verify the sweep leaves a hold-back gauge                         |
| [T27](tests/t27.sh) | reject a tx 1 wei below the post-fork floor                       |
| [T28](tests/t28.sh) | reject a swept tx re-entering at the old price                    |
| [T29](tests/t29.sh) | seal a tx at the post-fork floor of 625 gwei                      |
| [T30](tests/t30.sh) | seal the parked 700 gwei tx above the new floor                   |
| [T31](tests/t31.sh) | verify the post-fork reject is not tracked                        |
| [T32](tests/t32.sh) | replace a post-fork queued tx at the same nonce                   |
| [T33](tests/t33.sh) | verify the journal load keeps the new-tier replacement            |
| [T34](tests/t34.sh) | verify no tracker revival within the recheck                      |
| [T35](tests/t35.sh) | verify effectiveGasPrice matches the block base fee on both tiers |
| [T36](tests/t36.sh) | verify the --gasprice 1 knob is inert                             |
| [T37](tests/t37.sh) | verify eth_gasPrice on the post-fork tier                         |
| [T38](tests/t38.sh) | verify eth_maxPriorityFeePerGas on the post-fork tier             |
| [T39](tests/t39.sh) | verify the block baseFeePerGas on the post-fork tier              |
| [T40](tests/t40.sh) | verify txpool_contentFrom mirrors the post-fork queue             |
| [T41](tests/t41.sh) | verify eth_estimateGas on the post-fork tier                      |
| [T42](tests/t42.sh) | seal a tx at the post-fork default gas price                      |
| [T43](tests/t43.sh) | revive the held-back txs when the floor drops                     |
| [T44](tests/t44.sh) | verify the re-cross sweep fires again                             |
| [T45](tests/t45.sh) | verify the hold-back survives a restart                           |
| [T46](tests/t46.sh) | reject a 1559 tx 1 wei below the post-fork floor                  |
| [T47](tests/t47.sh) | reject a legacy creation below the post-fork floor                |
| [T48](tests/t48.sh) | reject a 1559 creation below the post-fork floor                  |
| [T49](tests/t49.sh) | seal a legacy creation at the post-fork floor                     |
| [T50](tests/t50.sh) | seal a legacy creation above the post-fork floor                  |
| [T51](tests/t51.sh) | seal a 1559 creation at the post-fork floor                       |
| [T52](tests/t52.sh) | seal a tip-0 creation at the post-fork base fee                   |
| [T53](tests/t53.sh) | seal a 1559 tx at the post-fork floor                             |
