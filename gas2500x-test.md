# gas2500x test plan (Local_DPoS_Setup)

Field test for the gas price floor change to the Gas2500x tier (625 gwei), as
shipped by three XDPoSChain commits on `dev-upgrade`:

- **`7823fc7f`** (#2516) — `Gas2500xBlock` fork: pool floor, chain default gas
  price and EIP-1559 base fee move from the Gas50x tier (12.5 gwei) to 625 gwei.
  The floor becomes a pure function of the chain config — `--gasprice` can no
  longer move it.
- **`68695806`** (#2532) — On a floor rise, sweep every non-special
  transaction priced below the new floor from both pending and queue. Swept
  transactions do not come back. Meter `txpool/belowfloor`.
- **`06582401`** (#2541) — Local tracker: same-nonce supersede fix; hold back
  tracked local txs below the floor (gauge `txpool/local/belowfloor`), revive
  them when the floor drops (reorg / `debug.setHead`); `ErrUnderMinGasPrice` is
  not a temporary reject and must not enter the tracker.

Node under test baseline: `XDPoSChain` `dev-upgrade` @ `5501a1f1e5` (contains
all three commits).

## Quick start

All commands run from `~/Local_DPoS_Setup`. This branch (`gas2500x`) keeps
`"gas2500xBlock": 120` in `genesis.json` permanently — no file restoration is
needed before or after a test run. Everything runs with `bash`, `curl`, `jq`
and foundry's `cast`; all signer keys (S1/S2/S3 and P3) live in `.env` as raw
hex and every submission is signed locally with
`cast send --private-key ... --legacy`.

```bash
# one-time setup (if not done yet)
cp .env.sample .env                 # sender/node keys
cd ~/XDPoSChain && make all         # fresh XDC + bootnode binaries; cd back

# the one command that does everything: stops any leftover nodes, wipes the
# datadirs, starts the whole network (3 masternodes + the observer), runs the
# cases, then stops the network (data and logs are kept for inspection;
# transcript lands in results/gas2500x-<timestamp>.log)
./gas2500x-run.sh

# stop everything manually (e.g. after an interrupted run)
./stop-network.sh
```

## Topology

Three masternodes (pn0–pn2, genesis signers, 2/3 ≥ 0.666 quorum) plus a fourth
**observer node pn3** that is *not* in the genesis signer list:

- pn0–pn2 keep sealing throughout the whole plan — no quorum risk, no timeout
  wobble, masternode data untouched by the set-head experiment.
- Every pool case submits its transactions via **pn3** (RPC 8548), so all
  tracker/journal/hold-back state lands on pn3, and the floor-drop experiment
  (T29) rewinds pn3 only. A non-signer cannot finalize anything on
  its own (1 vote < 1.998), so it just stalls at the rewound head without
  producing fork garbage.
- pn0's prefunded signer funds S1/S2/S3 (1 XDC each) and pn3's own account P3
  (10 XDC) in T01.

Port map (stock `run-node.sh`): pn0 RPC 8545 / metrics 6060, pn1 8546/6061,
pn2 8547/6062, **pn3 8548/6063**.

## Key numbers

- **Gas50x floor = `InitialBaseFee`:** 12,500,000,000 wei = 12.5 gwei
- **Gas2500x floor:** 625,000,000,000 wei = 625 gwei
- **Floor resolution height:** head+1 (with `gas2500xBlock: 120`, the sweep
  fires when the head crosses 120)
- **Replacement bump:** 10% (pool policy; unit-test pinned) — a replacement
  must exceed the old price by strictly more than 10%, so the cases use
  112% / 110.4% bumps (see T08/T23)
- **Tracker recheck:** 10 s after start, then every 60 s
  (`locals.recheckInterval`)

## Test scripts

Shell layer, `bash` + `curl` + `jq` + `cast` (foundry) only, all under
`tests/`:

- **`tests/gas2500x-lib.sh`** — shared helpers (RPC via curl+jq, local `cast`
  signing from the `.env` raw keys, fork-window guards, pool/meter/journal
  readers) plus the case frame: every case opens with a
  `Tnn: test number=<head> expected=<n>s name=<case>` line and ends in one
  verdict line `Tnn: pass|fail|skip number=<head> elapsed=<n>s result=<evidence>`
  on stdout. The expected time is injected by the runner from its per-item
  `EXPECTED` table (ceil of the last full run's elapsed, min 1); standalone
  case runs default to 1s.
- **`tests/t1.sh` … `tests/t46.sh`** — one script per test case, one case ID
  per script. The runner drives everything; the only remaining twice-cases
  (T10–T15, T34) are invoked internally as pre/post sides.
- **`gas2500x-run.sh`** (repo root, next to `start-network.sh`) — the only
  entry point and the owner of the full lifecycle: stop leftovers → wipe
  datadirs → start the network → run cases → stop (bootstrap chatter stays
  on the console, out of the transcript; no per-case arguments). Cases run
  in schedule order (pre sides before the fork, post sides after), starting
  each case only once pn3's head has moved strictly past the previous
  case's verdict-time block (the verdict line's `number=`; the chain seals
  a block every 2 s, so the wait is usually ~2 s); the whole
  stamped run is recorded in
  `results/gas2500x-<timestamp>.log` — the log opens with
  `start: cases=N` and closes with `end: pass=X fail=Y skip=Z`
  (no results `.md` is created) — and the network is stopped when the run
  ends.

## Test cases

Cases are ordered by execution time, and **each case verifies exactly one
result** — one action (or one passive observation) with its expected outcome.
Observation-only cases (T04, T07, T17–T19, T22, T26–T28) share the trigger of
the action case they observe and add no new submissions; the twice-cases
(T10–T15, T34) run on both sides of the fork (pre before it, post after).
Fork height: **120** (≈240 s after genesis at 2 s blocks). Hard timing rule:
all pre-fork submissions (T01–T09, plus the pre sides of T13 and T34 and
the creation cases T35–T40) must complete before head ≈ 115 — if the window
is missed, simply re-run the runner (it resets the chain). Queued (gap)
transactions survive until the fork regardless.

One benign interference source: every ~30 s each masternode broadcasts an
XDPoS consensus signing tx (`to` = the `0x…0089` system contract,
`gasPrice` = 0). As txs from a genesis signer they enter every node's pool
as executable-special entries for ~2 s until the block carrying them
imports — a raw pending read can transiently show up to 3. The
pending-side assertions (T05, T06, T26, T31) therefore count only
non-signing txs (shape-based filter, immune to the `xdc`/`0x` key prefix
difference in `txpool_content`).

Out of scope here (covered by unit tests): TRC21/XDCx tier pricing
(`GetGasPriceForTRC21`, XDCx disabled locally), concurrent TrackAll races,
Osaka gas-cap discard, `MainnetChainConfig.Gas2500xBlock == nil`, and special
transactions (they cannot be crafted on a running network).

### T01 — fund the senders

- **Steps:**
  1. Fund S1–S4 with 1 XDC each via pn0's signer at the suggested 12.5 gwei
     (S4 sends T34's above-floor survivor).
  2. Fund P3 — pn3's own account (address via
     `XDC account list --datadir nodes/pn3`) — with 10 XDC; P3's key signs
     T13's default-price transfer.
- **Expected:** `eth_getBalance` on pn3's RPC (8548) reflects all five new
  balances; the funding txs are sealed within ~2 blocks.

### T02 — at-floor execution on the pre-fork tier (12.5 gwei)

- **Steps:** S3 submits one executable transfer at **exactly 12.5 gwei** and
  the receipt is fetched.
- **Expected:** sealed within ~2 blocks; receipt `effectiveGasPrice` = 12.5
  gwei, status 1; S3's nonce advances 0 → 1. The pre-fork floor admits a tx at
  exactly the floor.

### T03 — below-floor rejection on the pre-fork tier (12499999999 wei)

- **Steps:** S3 submits one executable transfer at 12.5 gwei − 1 wei
  (12499999999).
- **Expected:** rejected with `under min gas price`; nothing sealed. With T02:
  the pre-fork floor is exactly 12.5 gwei, inclusive.

### T04 — the below-floor reject is not tracked (#2541)

- **Steps:** compare the journal size (`nodes/pn3/XDC/transactions.rlp`)
  across T03 and one tracker rotation; read the gauge `txpool/local/belowfloor`.
- **Expected:** journal size unchanged, gauge stays 0 — a non-temporary reject
  never enters the tracker or the journal.

### T05 — queue seeding, sender S1 (10 queued)

- **Steps:** S1 submits transfers at nonces 1–10 while S1's pending nonce is
  0: the missing nonce 0 parks them all in the pool's **queue**, which
  masternodes cannot seal. The pool rejects nonces beyond pending+10
  (`LimitThresholdNonceInQueue`), so 10 is the maximum one account can park.
  (A plain pending burst would not survive: 4.7M block gas fits ~223 txs and
  pn0–pn2 seal a block every 2 s.)
- **Expected:** pn3 holds 10 queued (S1's batch) and no pending user txs
  (signer txs excluded); pn0–pn2 pools stay empty (queued transactions are
  not announced).

### T06 — queue seeding, sender S2 (8 queued)

- **Steps:** S2 submits transfers at nonces 2–9 the same way — a second
  queued sender (gap at 0–1; nonce 10 stays free for T08's replacement pair).
- **Expected:** pn3 queued 10 → 18, no pending user txs; pn0–pn2 pools
  empty.

### T07 — the queued batch is not sealed

- **Steps:** sample `eth_getBlockTransactionCountByNumber` over ~10
  consecutive blocks after the seeding.
- **Expected:** count 0 on every sampled block — the only pooled txs are
  queued and cannot be sealed; the head advances on empty blocks.

### T08 — same-nonce replacement accepted (pre-fork, #2541)

- **Steps:**
  1. S2 submits P1 at nonce 10 (12.5 gwei) — queued behind the gap, tracked.
  2. S2 submits P2 at the same nonce 10 with a 12% bump (14 gwei; the 110%
     threshold must be exceeded, hence not exactly 10%).
- **Expected:** P2 accepted; the tracker holds only P2 and the pool's
  nonce-10 slot holds only P2 (P1 is gone).

### T09 — journal load converges on the replacement (pre-fork, #2541)

- **Steps:** restart pn3 (`./stop-network.sh 3 && ./run-node.sh 3`) and wait
  for the tracker's first recheck (~10 s timer) to reload the journal.
- **Expected:** the pool holds S2's nonces 2–9 plus P2 at nonce 10 (9 txs);
  P1 never wins the nonce back. (Pending-side replacement rules — the 10%
  bump, special-transaction priority — cannot be held for observation on a
  live chain and stay unit-test territory.)

### T10 — `eth_gasPrice` on both sides of the fork (#2516)

- **Steps:** call `eth_gasPrice` on each side; check `result`.
- **Expected:** `result` = 12,500,000,000 wei pre-fork and 625,000,000,000 wei
  post-fork — one clean step; the quote never drops below the enforced floor.

### T11 — `eth_maxPriorityFeePerGas` on both sides of the fork (#2516)

- **Steps:** call `eth_maxPriorityFeePerGas` on each side; check `result`.
- **Expected:** a sane tip suggestion on both sides, bounded well below the
  tier price, no fork-induced error.

### T12 — `eth_getBlockByNumber` baseFeePerGas on both sides (#2516)

- **Steps:** call `eth_getBlockByNumber("latest", false)` on each side and
  check `baseFeePerGas`; post-fork also fetch the last pre-fork block and
  the first post-fork block directly.
- **Expected:** `baseFeePerGas` = 12.5 gwei pre-fork and = 625 gwei
  post-fork; the last pre-fork block carries 12.5 gwei and the first
  post-fork block carries 625 gwei — the step is visible between the two.

### T13 — the tier-aware default gas price (#2516)

- **Steps:** P3 (pn3's own account, funded in T01) submits one transfer with
  no gas price at all; cast signs locally and omits the price, so the tx
  carries the node's tier-aware suggested gas price. Follow the receipt.
- **Expected:** sealed at `effectiveGasPrice` 12.5 gwei pre-fork and 625 gwei
  post-fork — the default price follows the tier.

### T14 — `txpool_contentFrom` mirrors the queue (#2532)

- **Steps:** call `txpool_contentFrom(S1)` on pn3 on each side.
- **Expected:** pre-fork 10 entries under `queued` (pending empty); post-fork
  empty — the sweep removed them (T17).

### T15 — `eth_estimateGas` on both sides (#2516)

- **Steps:** call `eth_estimateGas` for a plain transfer on each side.
- **Expected:** 21000 (or the node's own estimate for a bare transfer) on both
  tiers, no error.

### T16 — sealing continuity across the fork

- **Steps:** watch the heads of pn0–pn2 across the fork block.
- **Expected:** sealing never stalls; the three masternode heads agree 5+
  blocks past the fork.

### T17 — the fork sweep empties the queue (#2532, core case)

- **Steps:** `txpool_status` on all four nodes.
- **Expected:** queued drops 18 → 0 on pn0–pn2 (queued txs were never
  announced to them). On pn3 exactly one tx survives when T34 seeded its
  above-floor pre-fork tx — 700 gwei is above the new floor and the sweep
  only drops; without the T34 seed pn3 is empty too. (The pending-section
  half of the sweep is pinned by unit tests,
  `TestSweepUnderpricedOnGasScheduleFork`: a live chain mines every
  executable transaction within seconds, so no pending tx can be held for
  observation across the fork.)

### T18 — sweep observables on pn3 (#2532)

- **Steps:** read pn3's `txpool/belowfloor` meter; grep its log.
- **Expected:** the meter increased to ~19 (the seeded 18 plus T08's P2); the
  log contains `Dropped pooled transaction ... reason=below-gas-price-floor`.

### T19 — the sweep leaves a hold-back gauge (#2541)

- **Steps:** read the gauge `txpool/local/belowfloor` on all nodes.
- **Expected:** pn3 = k (the queued batch was local to pn3); pn0–pn2 = 0 —
  those transactions never reached them.

### T20 — at-floor execution on the new tier (625 gwei)

- **Steps:** S1 submits one executable transfer at **exactly 625 gwei** (the
  sweep freed S1's executable nonce 0) and the receipt is fetched.
- **Expected:** sealed within ~2 blocks; receipt `effectiveGasPrice` = 625
  gwei; S1's nonce advances to 1 — mirror of T02 on the new tier.

### T21 — below-floor rejection on the new tier (624999999999 wei)

- **Steps:** S1 submits one executable transfer at 624999999999.
- **Expected:** rejected with `under min gas price`. With T20: the post-fork
  floor is exactly 625 gwei, inclusive — the same boundary T03 probed, now at
  the new tier.

### T22 — the post-fork reject is not tracked (#2541)

- **Steps:** journal size before/after; gauge read.
- **Expected:** journal unchanged; gauge still k — the reject did not touch
  the tracker.

### T23 — same-nonce replacement accepted on the new tier (#2541)

- **Steps:**
  1. S2 submits P1 at nonce 3 (625 gwei) — S2's pending nonce is 0 after the
     sweep, so the tx parks in the queue behind missing nonces 0–2, tracked.
  2. S2 submits P2 at the same nonce 3 with a 110.4% bump (690 gwei).
- **Expected:** P2 accepted; the nonce-3 slot holds only P2. Same mechanics
  as T08 at the new price.

### T24 — journal load converges on the new-tier replacement (#2541)

- **Steps:** restart pn3 and let the tracker's first recheck (~10 s) reload
  the journal into the pool.
- **Expected:** only P2 at nonce 3 after the load; P1 never returns.

### T25 — a swept transaction cannot re-enter at the old price (#2532/#2541)

- **Steps:** resubmit one swept 12.5 gwei tx unchanged.
- **Expected:** rejected with `under min gas price` — the old tier price is
  now below the floor.

### T26 — no tracker revival within the recheck (#2541)

- **Steps:** wait one recheck; re-read pools, gauge and journal size.
- **Expected:** the gauge stays k and the pools stay stable across the
  rechecks (no refill, no growth, journal unchanged) — the tracker holds the
  txs back instead of retrying them into a rejection loop.

### T27 — effectiveGasPrice matches the block's base fee on both tiers (#2516)

- **Steps:** read the `baseFeePerGas` of the last pre-fork block and the
  first post-fork block directly (blocks 119 and 120 at the current fork
  height), and check the run transcript for the T02/T20 pass verdicts (their
  txs paid the tier prices of their own blocks).
- **Expected:** the pre-fork block carries 12.5 gwei and the post-fork one
  carries 625 gwei — no cross-tier mixing; both at-floor cases passed.

### T28 — the `--gasprice 1` knob is inert (#2516)

- **Steps:** confirm every node still runs with `--gasprice 1` (stock
  `run-node.sh`; check the process command line); cross-reference the T03 and
  T21 rejections.
- **Expected:** with `--gasprice 1` present the enforced floor was still 12.5
  gwei, then 625 gwei — the floor is a pure function of the chain config; the
  removed `miner.gasprice` knob cannot move it.

### T29 — revival when the floor drops (#2541)

- **Steps:** run `tests/t29.sh`, which stops pn3 and restarts it isolated
  (`--nodiscover`, `--port 0`, empty static peers; aborts if `admin.peers`
  ≠ 0) with the `--set-head 30` startup flag, so the chain — and with it the
  floor — rewinds before the pool is created (`debug.setHead` is a
  Local-only API and is rejected over HTTP). It then waits for the tracker's
  first recheck and leaves pn3 isolated for T30.
- **Expected:** within one recheck the held-back txs are resubmitted — the
  gauge drops to 0 and the pools refill. **Veto criterion: a below-floor tx
  must never be sealed nor appear in another node's pool at any point.**
  (The verdict line's `number=30` is the rewound head — the transcript's
  block numbers intentionally dip across T29/T30 and recover once T30
  re-syncs past the fork.)

### T30 — the re-cross sweep fires again (#2532)

- **Steps:** run `tests/t30.sh`, which reconnects the rewound pn3 to pn0 via
  `admin_addPeer`, waits for it to sync across the fork block, then re-reads
  the gauge, meter and pools. Its test line reads `number=30` — the rewound
  head left by T29, not an ordering violation: an isolated non-sealing
  observer with no peers cannot advance its head, so reconnecting IS the
  case's first step and the runner deliberately disarms the head gate once
  between T29 and T30.
- **Expected:** the gauge rises back to k, the meter increases a second time
  (same process), pools empty again — the revived txs were swept again by the
  fork (the above-floor P2 may stay queued). The pass line's `number=` is the
  re-synced head (well past the fork), which is the actual assertion point.

### T31 — the hold-back survives a restart (#2541)

- **Steps:** plain `./stop-network.sh 3 && ./run-node.sh 3`.
- **Expected:** the txs stay held back (gauge = k, pool empty) — the journal
  persists the hold-back state and no resubmit storm happens.

### T32 — EIP-1559 admission at the new floor (fee cap = 625 gwei, #2516)

- **Steps:** S1 submits one type-2 transfer at its executable nonce with
  `--max-fee-per-gas` 625 gwei and a 1 gwei tip (no `--legacy`); the receipt
  is fetched.
- **Expected:** sealed; receipt `type` = 0x2 and `effectiveGasPrice` = 625
  gwei — the pool floor compares a dynamic-fee tx's fee cap, and the floor
  price caps what the tx effectively pays. T20 is the legacy mirror of the
  same boundary.

### T33 — EIP-1559 rejection below the new floor (625 gwei − 1, #2516)

- **Steps:** S1 submits one type-2 transfer with `--max-fee-per-gas`
  624999999999 at its executable nonce.
- **Expected:** rejected with `under min gas price` — for a dynamic-fee tx
  the floor compares the fee cap, not the tip. T21 is the legacy mirror.

### T34 — an above-floor pre-fork tx survives the sweep and seals at its own price (#2532)

- **Steps:**
  1. (pre) S4 (funded in T01) submits one transfer at nonce 1 priced 700 gwei
     while nonce 0 is still missing, so it parks in the queue — the only
     place a tx survives to the fork — admitted under the 12.5 gwei pre-fork
     floor.
  2. (post) S4 fills the gap with one transfer at nonce 0 at 625 gwei, and
     the survivor's receipt is fetched.
- **Expected:** (pre) the tx sits in pn3's queue, and T17 finds exactly it
  still queued after the sweep — 700 gwei is above the new floor and the
  sweep only drops. (post) once the gap is filled the survivor seals at
  `effectiveGasPrice` 700 gwei — its own price, not the 625 gwei base fee:
  the sweep never reprices what it keeps. (The runner places t34-post right
  after T17 so the seal blocks land well before T29's rewind, and T30 syncs
  to fork+20 so the revival of these two txs is dropped again by re-importing
  their seal blocks.)

### T35 — a legacy creation below the tier floor is rejected (#2516)

- **Steps:** S5 (funded in T01) submits one `cast send --create` of a
  minimal runtime (legacy) at 12499999999 wei — one below the pre-fork
  floor — via pn3's RPC.
- **Expected:** rejected at once with `under min gas price`; consumes no
  nonce and is never tracked.

### T36 — a legacy creation at the tier floor seals (#2516)

- **Steps:** S5 submits one legacy creation at exactly the pre-fork floor
  (12500000000 wei) at its pending nonce.
- **Expected:** sealed; `effectiveGasPrice` = 12500000000 wei.

### T37 — a legacy creation above the tier floor seals (#2516)

- **Steps:** S5 submits one legacy creation at floor+1 (12500000001 wei).
- **Expected:** sealed; `effectiveGasPrice` = 12500000001 wei — above-floor
  admission passes through at its own price.

### T38 — an EIP-1559 creation below the tier floor is rejected (#2516)

- **Steps:** S5 submits one type-2 creation with only a fee cap at
  12499999999 wei.
- **Expected:** rejected at once with `under min gas price` — for a
  dynamic-fee tx the floor compares the fee cap (T33's rule, creation
  variant).

### T39 — an EIP-1559 creation at the tier floor seals (#2516)

- **Steps:** S5 submits one type-2 creation with only a fee cap at exactly
  the pre-fork floor.
- **Expected:** sealed; receipt `type` = 0x2 and `effectiveGasPrice` =
  12500000000 wei — the mirror of T32 for creation txs.

### T40 — an EIP-1559 creation with tip 0 seals at the base fee (#2516)

- **Steps:** S5 submits one type-2 creation setting only
  `--priority-gas-price 0` (fee cap = cast's estimate).
- **Expected:** sealed; receipt `type` = 0x2 and `effectiveGasPrice` = the
  base fee (which the floor pins to the pre-fork tier value).

### T41 — a legacy creation below the post-fork floor is rejected (#2516)

- **Steps:** T35's tx re-probed on the post-fork tier: S5 submits one
  legacy creation at 624999999999 wei (post-fork floor 625 gwei − 1),
  scheduled after T33 and the T29–T31 saga.
- **Expected:** rejected at once with `under min gas price`; consumes no
  nonce and is never tracked.

### T42 — a legacy creation at the post-fork floor seals (#2516)

- **Steps:** T36's tx re-probed post-fork: S5 submits one legacy creation
  at exactly 625 gwei.
- **Expected:** sealed; `effectiveGasPrice` = 625000000000 wei.

### T43 — a legacy creation above the post-fork floor seals (#2516)

- **Steps:** T37's tx re-probed post-fork: S5 submits one legacy creation
  at 625000000001 wei.
- **Expected:** sealed; `effectiveGasPrice` = 625000000001 wei.

### T44 — an EIP-1559 creation below the post-fork floor is rejected (#2516)

- **Steps:** T38's tx re-probed post-fork: S5 submits one type-2 creation
  with only a fee cap at 624999999999 wei.
- **Expected:** rejected at once with `under min gas price`.

### T45 — an EIP-1559 creation at the post-fork floor seals (#2516)

- **Steps:** T39's tx re-probed post-fork: S5 submits one type-2 creation
  with only a fee cap at exactly 625 gwei.
- **Expected:** sealed; receipt `type` = 0x2 and `effectiveGasPrice` =
  625000000000 wei.

### T46 — an EIP-1559 creation with tip 0 seals at the base fee (#2516)

- **Steps:** T40's tx re-probed post-fork: S5 submits one type-2 creation
  setting only `--priority-gas-price 0`.
- **Expected:** sealed; receipt `type` = 0x2 and `effectiveGasPrice` =
  625000000000 wei (the base fee, pinned by the floor).
