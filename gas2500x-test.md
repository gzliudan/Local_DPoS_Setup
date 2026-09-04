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
- The bulk transactions of cases T5/T6 are submitted to **pn3** (RPC 8548),
  so all tracker/journal/hold-back state lands on pn3, and the floor-drop
  experiment (T29) rewinds pn3 only. A non-signer cannot finalize anything on
  its own (1 vote < 1.998), so it just stalls at the rewound head without
  producing fork garbage.
- pn3 first receives funds from pn0's prefunded signer, then funds S1/S2.

Port map: pn0 RPC 8545 / metrics 6060, pn1 8546/6061, pn2 8547/6062,
**pn3 8548/6063** (regular `run-node.sh 3` uses 8548/6063 too).

## 2. One-time environment setup

```bash
cd ~/Local_DPoS_Setup
cp .env.sample .env            # if .env does not exist yet
cd ~/XDPoSChain && make all    # fresh XDC + bootnode binaries
```

Everything runs with `bash`, `curl` and `jq` — no compiled tooling is needed.
Sender keys (S1/S2/S3) live in `.env` as raw hex; each `T*.sh` script imports
its key into pn3's keystore (`XDC account import`, password `.pwd`) and
signs
via the node, so `eth_sendTransaction` works for every case.

## 3. Key numbers

- **Gas50x floor = `InitialBaseFee`:** 12,500,000,000 wei = 12.5 gwei
- **Gas2500x floor:** 625,000,000,000 wei = 625 gwei
- **Floor resolution height:** head+1 (with `gas2500xBlock: 90`, the reset
  landing on head 90 sweeps)
- **Replacement bump:** 10% (pool policy; unit-test pinned, see T8/T23)
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
  signing from the `.env` raw keys, pass/fail assertion, result-file writer
  (per-run `results/gas2500x-results-<timestamp>.md` when driven by the
  runner, shared `results/gas2500x-results.md` when a case runs alone).
- **`tests/t1.sh` … `tests/t31.sh`** — one script per test case; each prints
  PASS or FAIL with its evidence and appends a markdown table row to the
  result file.
- **`gas2500x-run.sh`** (repo root, next to `start-network.sh`) — runs all
  cases in order (the twice-cases run pre before the fork and post after it)
  and prints a summary.

Run one case: `tests/t2.sh`. Run everything: `./gas2500x-run.sh`.
Twice-cases take an argument when run alone:
`tests/t10.sh pre` / `tests/t10.sh post`.

## 6. Test cases

Cases are ordered by execution time, and **each case verifies exactly one
result** — one action (or one passive observation) with its expected outcome.
Observation-only cases (T4, T7, T17–T19, ...) share the trigger of the action
case they observe and add no new submissions; probe cases marked "twice" run
the same call on both sides of the fork. Fork height: **90**
(≈180 s after genesis at 2 s blocks). Hard timing rule: all pre-fork
submissions (T1–T9, plus the pre sides of T13/T14) must complete before
head ≈ 85 — queued (gap) transactions survive until the fork regardless, but
miss the window and the reset/start cycle starts over.

Out of scope here (covered by unit tests): TRC21/XDCx tier pricing
(`GetGasPriceForTRC21`, XDCx disabled locally), concurrent TrackAll races,
Osaka gas-cap discard, `MainnetChainConfig.Gas2500xBlock == nil`, and special
transactions (they cannot be crafted on a running network).

### Scheduled fork at block 90

### T1 — fund the senders

- **When:** head 20–25.
- **Steps:**
  1. Fund S1, S2 and S3 with 100 XDC each via pn0's signer at the suggested
     12.5 gwei.
  2. Fund pn3's own unlocked keystore account P3 with 10 XDC (address via
     `XDC account list --datadir nodes/pn3`) — P3 signs `eth_sendTransaction`
     later, which requires a keystore key.

- **Expected:** `eth_getBalance` on pn3's RPC (8548) reflects all four new
  balances; the funding txs are sealed within ~2 blocks.

### T2 — at-floor execution on the pre-fork tier (12.5 gwei)

- **When:** head 25–30.
- **Steps:** S3 submits one executable transfer at **exactly 12.5 gwei** and
  the receipt is fetched.
- **Expected:** sealed within ~2 blocks; receipt `effectiveGasPrice` = 12.5
  gwei, status 1; S3's nonce advances 0 → 1. The pre-fork floor admits a tx at
  exactly the floor.

### T3 — below-floor rejection on the pre-fork tier (12.5 gwei − 1)

- **When:** head 30–35.
- **Steps:** S3 submits one executable transfer at 12.5 gwei − 1 wei
  (12499999999).
- **Expected:** rejected with `under min gas price`; nothing sealed. With T2:
  the pre-fork floor is exactly 12.5 gwei, inclusive.

### T4 — the below-floor reject is not tracked (#2541)

- **When:** immediately after T3.
- **Steps:** compare the journal size (`nodes/pn3/XDC/transactions.rlp`)
  across T3 and one tracker rotation; read the gauge `txpool/local/belowfloor`.
- **Expected:** journal size unchanged, gauge stays 0 — a non-temporary reject
  never enters the tracker or the journal.

### T5 — queue seeding, sender S1 (60 queued)

- **When:** head 30–40.
- **Steps:** S1 submits 60 transfers at nonces 1–60 (`--count 60
  --start-nonce 1`) while S1's pending nonce is 0: the missing nonce 0 parks
  them all in the pool's **queue**, which masternodes cannot seal. (A plain
  pending burst would not survive: 4.7M block gas fits ~223 txs and pn0–pn2
  seal a block every 2 s. S1 must never receive a tx at its executable nonce 0
  — that would promote and mine the batch within seconds.)
- **Expected:** pn3 `txpool_status` shows `pending=0, queued=60`; pn0–pn2
  pools stay empty (queued transactions are not announced).

### T6 — queue seeding, sender S2 (10 queued)

- **When:** head 35–45.
- **Steps:** S2 submits 10 transfers at nonces 3–12 (`--count 10
  --start-nonce 3`) the same way — a second queued sender, still within the
  64-slot per-account queue cap.
- **Expected:** pn3 queued 60 → 70, pending stays 0; pn0–pn2 pools empty.

### T7 — the queued batch is not sealed

- **When:** head 40–60 (passive).
- **Steps:** sample `eth_getBlockTransactionCountByNumber` over ~10
  consecutive blocks after the seeding.
- **Expected:** count 0 on every sampled block — the only pooled txs are
  queued and cannot be sealed; the head advances on empty blocks.

### T8 — same-nonce replacement accepted (pre-fork, #2541)

- **When:** head 45–60.
- **Steps:**
  1. S2 submits P1 at nonce 20 (12.5 gwei) — queued behind the gap, tracked.
  2. S2 submits P2 at the same nonce 20 with P2 ≥ 1.1 × P1 (e.g. 14 gwei).
- **Expected:** P2 accepted; the tracker logs `Replaced tracked local
  transaction` and holds only P2; the pool's nonce-20 slot holds only P2.

### T9 — journal load converges on the replacement (pre-fork, #2541)

- **When:** head 60–80, after T8.
- **Steps:** restart pn3 (`./stop-network.sh 3 && ./run-node.sh 3`).
- **Expected:** after the journal load the pool holds only P2 at nonce 20; P1
  never wins the nonce back. (Pending-side replacement rules — the 10% bump,
  special-transaction priority — cannot be held for observation on a live
  chain and stay unit-test territory.)

### T10 — `eth_gasPrice` on both sides of the fork (#2516)

- **When:** pre side head ≈ 50; post side head ≈ 95.
- **Steps:** call `eth_gasPrice` on each side; check `result`.
- **Expected:** `result` = 12,500,000,000 wei pre-fork and 625,000,000,000 wei
  post-fork — one clean step; the quote never drops below the enforced floor.

### T11 — `eth_maxPriorityFeePerGas` on both sides of the fork (#2516)

- **When:** pre side head ≈ 50; post side head ≈ 95.
- **Steps:** call `eth_maxPriorityFeePerGas` on each side; check `result`.
- **Expected:** a sane tip suggestion on both sides, bounded well below the
  tier price, no fork-induced error.

### T12 — `eth_getBlockByNumber` baseFeePerGas on both sides (#2516)

- **When:** pre side head ≈ 50; post side head ≥ 91.
- **Steps:** call `eth_getBlockByNumber("latest", false)` on each side and
  check `baseFeePerGas`; post-fork also fetch blocks 89 and 90 directly.
- **Expected:** `baseFeePerGas` = 12.5 gwei pre-fork and = 625 gwei
  post-fork; block 89 carries 12.5 gwei and block 90 carries 625 gwei — the
  step is visible between the two blocks.

### T13 — `eth_sendTransaction` without gasPrice (#2516)

- **When:** pre side head ≈ 55; post side head ≈ 105.
- **Steps:** from pn3's unlocked account P3, submit one `eth_sendTransaction`
  with no gasPrice argument; follow the receipt. (P3 was funded in T1;
  `eth_sendTransaction` signs from the node's keystore, which is why it uses
  P3 and not the raw senders.)
- **Expected:** the tx defaults to the tier-aware suggestion — sealed at
  `effectiveGasPrice` 12.5 gwei pre-fork and 625 gwei post-fork.

### T14 — `txpool_contentFrom` mirrors the queue (#2532)

- **When:** pre side head ≈ 60; post side head ≈ 110.
- **Steps:** call `txpool_contentFrom(S1)` on pn3 on each side.
- **Expected:** pre-fork 60 entries under `queued` (pending empty); post-fork
  empty — the sweep removed them (T17).

### T15 — `eth_estimateGas` on both sides (#2516)

- **When:** pre side head ≈ 55; post side head ≈ 110.
- **Steps:** call `eth_estimateGas` for a plain transfer on each side.
- **Expected:** 21000 (or the node's own estimate for a bare transfer) on both
  tiers, no error.

### T16 — sealing continuity across the fork

- **When:** head 90–95.
- **Steps:** watch the heads of pn0–pn2 across block 90.
- **Expected:** sealing never stalls; the three masternode heads agree 5+
  blocks past the fork.

### T17 — the fork sweep empties the queue (#2532, core case)

- **When:** head 90–95, immediately after the fork fires.
- **Steps:** `txpool_status` on all four nodes.
- **Expected:** queued drops 70 → 0 everywhere. (The pending-section half of
  the sweep is pinned by unit tests, `TestSweepUnderpricedOnGasScheduleFork`:
  a live chain mines every executable transaction within seconds, so no
  pending tx can be held for observation across the fork.)

### T18 — sweep observables on pn3 (#2532)

- **When:** head 90–95.
- **Steps:** read pn3's `txpool/belowfloor` meter; grep its log.
- **Expected:** the meter increased by ~70; the log contains `Dropped pooled
  transaction ... reason=below-gas-price-floor` (trace level).

### T19 — the sweep leaves a hold-back gauge (#2541)

- **When:** head 90–95.
- **Steps:** read the gauge `txpool/local/belowfloor` on all nodes.
- **Expected:** pn3 = k (the queued batch was local to pn3); pn0–pn2 = 0 —
  those transactions never reached them.

### T20 — at-floor execution on the new tier (625 gwei)

- **When:** head 95–105, after the sweep settled.
- **Steps:** S1 submits one executable transfer at **exactly 625 gwei** (the
  sweep freed S1's executable nonce 0) and the receipt is fetched.
- **Expected:** sealed within ~2 blocks; receipt `effectiveGasPrice` = 625
  gwei; S1's nonce advances to 1 — mirror of T2 on the new tier.

### T21 — below-floor rejection on the new tier (625 gwei − 1)

- **When:** head 100–110, after T20.
- **Steps:** S1 submits one executable transfer at 624999999999.
- **Expected:** rejected with `under min gas price`. With T20: the post-fork
  floor is exactly 625 gwei, inclusive — the same boundary T3 probed, now at
  the new tier.

### T22 — the post-fork reject is not tracked (#2541)

- **When:** immediately after T21.
- **Steps:** journal size before/after; gauge read.
- **Expected:** journal unchanged; gauge still k — the reject did not touch
  the tracker.

### T23 — same-nonce replacement accepted on the new tier (#2541)

- **When:** head 100–115.
- **Steps:**
  1. S2 submits P1 at nonce 3 (625 gwei) — S2's pending nonce is 0 after the
     sweep, so the tx parks in the queue behind missing nonces 0–2, tracked.
  2. S2 submits P2 at the same nonce 3 with P2 ≥ 1.1 × P1 (e.g. 690 gwei).
- **Expected:** P2 accepted; log `Replaced tracked local transaction`; the
  nonce-3 slot holds only P2. Same mechanics as T8 at the new price.

### T24 — journal load converges on the new-tier replacement (#2541)

- **When:** head 110–120, after T23.
- **Steps:** restart pn3.
- **Expected:** only P2 at nonce 3 after the load; P1 never returns.

### T25 — a swept transaction cannot re-enter at the old price (#2532/#2541)

- **When:** head 95–115.
- **Steps:** resubmit one swept 12.5 gwei tx unchanged.
- **Expected:** rejected with `under min gas price` — the old tier price is
  now below the floor.

### T26 — no tracker revival within the recheck (#2541)

- **When:** within one recheck (≤ 60 s) after T25.
- **Steps:** wait one recheck; re-read pools, gauge and journal size.
- **Expected:** the gauge stays k, no `need-resubmit` success log, pools stay
  empty — the tracker holds the txs back instead of retrying them into a
  rejection loop.

### T27 — effectiveGasPrice matches the block's base fee on both tiers (#2516)

- **When:** head ≥ 95, once the T2 and T20 receipts exist.
- **Steps:** compare each receipt's `effectiveGasPrice` with the
  `baseFeePerGas` of its own block (T2's tx: 12.5 gwei; T20's tx: 625 gwei).
- **Expected:** every receipt matches its block — pre-fork txs paid the 12.5
  gwei tier, post-fork txs pay 625 gwei, no cross-tier mixing.

### T28 — the `--gasprice 1` knob is inert (#2516)

- **When:** any time after T3 and T21.
- **Steps:** confirm every node still runs with `--gasprice 1` (stock
  `run-node.sh`; check the process command line); cross-reference the T3 and
  T21 rejections.
- **Expected:** with `--gasprice 1` present the enforced floor was still 12.5
  gwei, then 625 gwei — the floor is a pure function of the chain config; the
  removed `miner.gasprice` knob cannot move it.

### T29 — revival when the floor drops (#2541)

- **When:** after T20–T26 settle (head ≥ 115); ~2 min including resync.
- **Steps:** run `tests/t29.sh`, which stops pn3, restarts it
  isolated (`--nodiscover`, empty static peers; aborts if `admin.peers` ≠ 0),
  calls `debug.setHead(30)` so the floor falls back to 12.5 gwei, waits for
  the next tracker recheck (10 s/60 s cadence), then restores the regular pn3.
- **Expected:** within one recheck the held-back txs are resubmitted — pool
  counts rise, the gauge drops to 0, the log shows `Tx tracker status ...
  below-floor=0, need-resubmit=k`. **Veto criterion: a below-floor tx must
  never be sealed nor appear in another node's pool at any point.**

### T30 — the re-cross sweep fires again (#2532)

- **When:** after T29's resync crosses block 90.
- **Steps:** re-read pn3's gauge, meter and pools.
- **Expected:** the gauge rises back to k, the meter increases a second time,
  pools empty again — the revived txs were swept again by the fork.

### T31 — the hold-back survives a restart (#2541)

- **When:** right after T30, with the gauge at k.
- **Steps:** plain `./stop-network.sh 3 && ./run-node.sh 3`.
- **Expected:** the txs stay held back (gauge = k, pool empty) — the journal
  persists the hold-back state and no resubmit storm happens.

**After the run** (cleanup is not a test case, just the way back to the
unmodified genesis): remove the `"gas2500xBlock": 90` line from `genesis.json`,
then `./stop-network.sh && ./reset.sh -f` and restart with
`./start-network.sh && ./run-node.sh 3`.
