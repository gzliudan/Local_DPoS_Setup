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
all three commits). Rebuild before the test day: `cd ~/XDPoSChain && make all`.

## 1. Topology

Three masternodes (pn0–pn2, genesis signers, 2/3 ≥ 0.666 quorum) plus a fourth
**observer node pn3** that is *not* in the genesis signer list:

- pn0–pn2 keep sealing throughout the whole plan — no quorum risk, no timeout
  wobble, masternode data untouched by the set-head experiment.
- The bulk transactions of cases T05/T06 are submitted to **pn3** (RPC 8548),
  so all tracker/journal/hold-back state lands on pn3, and the floor-drop
  experiment (T29) rewinds pn3 only. A non-signer cannot finalize anything on
  its own (1 vote < 1.998), so it just stalls at the rewound head without
  producing fork garbage.
- pn0's prefunded signer funds S1/S2/S3 (1 XDC each) and pn3's own keystore
  account P3 (10 XDC) in T01.

Port map: pn0 RPC 8545 / metrics 6060, pn1 8546/6061, pn2 8547/6062,
**pn3 8548/6063** (regular `run-node.sh 3` uses 8548/6063 too).

## 2. One-time environment setup

```bash
cd ~/Local_DPoS_Setup
cp .env.sample .env            # if .env does not exist yet
cd ~/XDPoSChain && make all    # fresh XDC + bootnode binaries
```

Everything runs with `bash`, `curl`, `jq` and foundry's `cast`. Sender keys
(S1/S2/S3) live in `.env` as raw hex and every submission is signed locally
with `cast send --private-key ... --legacy`; only T13 signs through pn3's
unlocked keystore (`eth_sendTransaction` as account P3).

## 3. Key numbers

- **Gas50x floor = `InitialBaseFee`:** 12,500,000,000 wei = 12.5 gwei
- **Gas2500x floor:** 625,000,000,000 wei = 625 gwei
- **Floor resolution height:** head+1 (with `gas2500xBlock: 90`, the reset
  landing on head 90 sweeps)
- **Replacement bump:** 10% (pool policy; unit-test pinned) — a replacement
  must exceed the old price by strictly more than 10%, so the cases use
  112% / 110.4% bumps (see T08/T23)
- **Tracker recheck:** 10 s after start, then every 60 s
  (`locals.recheckInterval`)

## 4. Genesis configuration (scheduled fork)

The tested configuration mirrors the mainnet shape — every historical fork
active since genesis, the new fork scheduled at a future height — with the
future height pinned to block 90 so the 12.5 g → 625 g transition (sweep,
hold-back, revival) happens within minutes:

- inject `"gas2500xBlock": 90` into `genesis.json`; London/EIP1559 stay
  backfilled to 0 ≤ 90, so the BASEFEE-window guard is satisfied;
- this plan exercises only the scheduled-fork `genesis.json` directly — no
  backup copy is kept; the unmodified baseline (2500x tier active from block 0
  through the Localnet backfill) is not exercised by this plan;

**Every config switch needs a clean slate**: a config change on an existing
datadir is refused by the config-mismatch guard.

```bash
# edit genesis.json: inject "gas2500xBlock": 90 into config
# each switch:
./stop-network.sh && ./reset.sh -f && ./start-network.sh && ./run-node.sh 3
```

## 5. Test scripts

Shell layer, `bash` + `curl` + `jq` + `cast` (foundry) only, all under
`tests/`:

- **`tests/gas2500x-lib.sh`** — shared helpers: RPC via cast/curl+jq, local
  signing from the `.env` raw keys, pass/fail assertion; each case prints its
  verdict line to stdout, and the runner records the whole run in
  `results/gas2500x-<timestamp>.log` (no results `.md` is created).
- **`tests/t1.sh` … `tests/t31.sh`** — one script per test case; each prints
  its verdict line (`Tn: pass/fail/skip - evidence`) to stdout, and the
  runner keeps the whole transcript in `results/`.
- **`gas2500x-run.sh`** (repo root, next to `start-network.sh`) — runs all
  cases in order (the twice-cases run pre before the fork and post after it)
  and prints a summary.

Run one case: `tests/t2.sh`. Run everything: `./gas2500x-run.sh`.
Twice-cases take an argument when run alone:
`tests/t10.sh pre` / `tests/t10.sh post`.

## 6. Test cases

Cases are ordered by execution time, and **each case verifies exactly one
result** — one action (or one passive observation) with its expected outcome.
Observation-only cases (T04, T07, T17–T19, ...) share the trigger of the
action case they observe and add no new submissions; the T10–T15 probes run
the same call on both sides of the fork (pre before it, post after). Fork height: **90**
(≈180 s after genesis at 2 s blocks). Hard timing rule: all pre-fork
submissions (T01–T09, plus the pre sides of T13/T14) must complete before
head ≈ 85 — queued (gap) transactions survive until the fork regardless, but
miss the window and the reset/start cycle starts over.

Out of scope here (covered by unit tests): TRC21/XDCx tier pricing
(`GetGasPriceForTRC21`, XDCx disabled locally), concurrent TrackAll races,
Osaka gas-cap discard, `MainnetChainConfig.Gas2500xBlock == nil`, and special
transactions (they cannot be crafted on a running network).

### T01 — fund the senders

- **Steps:**
  1. Fund S1, S2 and S3 with 1 XDC each via pn0's signer at the suggested
     12.5 gwei.
  2. Fund pn3's own unlocked keystore account P3 with 10 XDC (address via
     `XDC account list --datadir nodes/pn3`) — P3 signs `eth_sendTransaction`
     later, which requires a keystore key.
- **Expected:** `eth_getBalance` on pn3's RPC (8548) reflects all four new
  balances; the funding txs are sealed within ~2 blocks.

### T02 — at-floor execution on the pre-fork tier (12.5 gwei)

- **Steps:** S3 submits one executable transfer at **exactly 12.5 gwei** and
  the receipt is fetched.
- **Expected:** sealed within ~2 blocks; receipt `effectiveGasPrice` = 12.5
  gwei, status 1; S3's nonce advances 0 → 1. The pre-fork floor admits a tx at
  exactly the floor.

### T03 — below-floor rejection on the pre-fork tier (12.5 gwei − 1)

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
- **Expected:** pn3 `txpool_status` shows `pending=0, queued=10`; pn0–pn2
  pools stay empty (queued transactions are not announced).

### T06 — queue seeding, sender S2 (8 queued)

- **Steps:** S2 submits transfers at nonces 2–9 the same way — a second
  queued sender (gap at 0–1; nonce 10 stays free for T08's replacement pair).
- **Expected:** pn3 queued 10 → 18, pending stays 0; pn0–pn2 pools empty.

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
  check `baseFeePerGas`; post-fork also fetch blocks 89 and 90 directly.
- **Expected:** `baseFeePerGas` = 12.5 gwei pre-fork and = 625 gwei
  post-fork; block 89 carries 12.5 gwei and block 90 carries 625 gwei — the
  step is visible between the two blocks.

### T13 — `eth_sendTransaction` without gasPrice (#2516)

- **Steps:** from pn3's unlocked account P3, submit one `eth_sendTransaction`
  with no gasPrice argument; follow the receipt. (P3 was funded in T01;
  `eth_sendTransaction` signs from the node's keystore, which is why it uses
  P3 and not the raw senders.)
- **Expected:** the tx defaults to the tier-aware suggestion — sealed at
  `effectiveGasPrice` 12.5 gwei pre-fork and 625 gwei post-fork.

### T14 — `txpool_contentFrom` mirrors the queue (#2532)

- **Steps:** call `txpool_contentFrom(S1)` on pn3 on each side.
- **Expected:** pre-fork 10 entries under `queued` (pending empty); post-fork
  empty — the sweep removed them (T17).

### T15 — `eth_estimateGas` on both sides (#2516)

- **Steps:** call `eth_estimateGas` for a plain transfer on each side.
- **Expected:** 21000 (or the node's own estimate for a bare transfer) on both
  tiers, no error.

### T16 — sealing continuity across the fork

- **Steps:** watch the heads of pn0–pn2 across block 90.
- **Expected:** sealing never stalls; the three masternode heads agree 5+
  blocks past the fork.

### T17 — the fork sweep empties the queue (#2532, core case)

- **Steps:** `txpool_status` on all four nodes.
- **Expected:** queued drops 18 → 0 everywhere. (The pending-section half of
  the sweep is pinned by unit tests, `TestSweepUnderpricedOnGasScheduleFork`:
  a live chain mines every executable transaction within seconds, so no
  pending tx can be held for observation across the fork.)

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

### T21 — below-floor rejection on the new tier (625 gwei − 1)

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

- **Steps:** restart pn3.
- **Expected:** only P2 at nonce 3 after the load; P1 never returns.

### T25 — a swept transaction cannot re-enter at the old price (#2532/#2541)

- **Steps:** resubmit one swept 12.5 gwei tx unchanged.
- **Expected:** rejected with `under min gas price` — the old tier price is
  now below the floor.

### T26 — no tracker revival within the recheck (#2541)

- **Steps:** wait one recheck; re-read pools, gauge and journal size.
- **Expected:** the gauge stays k, no `need-resubmit` success log, pools stay
  empty — the tracker holds the txs back instead of retrying them into a
  rejection loop.

### T27 — effectiveGasPrice matches the block's base fee on both tiers (#2516)

- **Steps:** read the `baseFeePerGas` of blocks 89 and 90 directly, and check
  the run transcript for the T02/T20 pass verdicts (their txs paid the tier
  prices of their own blocks).
- **Expected:** block 89 carries 12.5 gwei and block 90 carries 625 gwei —
  no cross-tier mixing; both at-floor cases passed.

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

### T30 — the re-cross sweep fires again (#2532)

- **Steps:** run `tests/t30.sh`, which reconnects the rewound pn3 to pn0 via
  `admin_addPeer`, waits for it to sync across block 90, then re-reads the
  gauge, meter and pools.
- **Expected:** the gauge rises back to k, the meter increases a second time
  (same process), pools empty again — the revived txs were swept again by the
  fork (the above-floor P2 may stay queued).

### T31 — the hold-back survives a restart (#2541)

- **Steps:** plain `./stop-network.sh 3 && ./run-node.sh 3`.
- **Expected:** the txs stay held back (gauge = k, pool empty) — the journal
  persists the hold-back state and no resubmit storm happens.

**After the run** (cleanup is not a test case, just the way back to the
unmodified genesis): remove the `"gas2500xBlock": 90` line from `genesis.json`,
then `./stop-network.sh && ./reset.sh -f` and restart with
`./start-network.sh && ./run-node.sh 3`.
