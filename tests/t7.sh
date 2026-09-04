#!/bin/bash
# T7 — the queued batch is not sealed: blocks stay empty while txs sit queued.
source "$(dirname "$0")/gas2500x-lib.sh"
begin_case "T7" "the queued batch is not sealed"

head0=$(head3)
for i in $(seq 1 10); do
    wait_head $((head0 + i)) 30 || fail_case "head did not advance to $((head0 + i))"
    cnt=$(hex2dec "$(rpc3 eth_getBlockTransactionCountByNumber \
        "[\"$(printf '0x%x' $((head0 + i)))\"]" | jq -r .)")
    if [ "$cnt" != "0" ]; then
        # XDPoS masternodes seal system txs (signingTX/randomize) FROM THEIR
        # OWN signer accounts — run-3 evidence: senders 0x77cb…/0x9650…/0x2526…
        # (the genesis signers) with tiny nonces. Regular S1/S2-type user txs
        # are what would break the invariant, so exempt the signer set.
        regular=$(rpc3 eth_getBlockByNumber "[\"$(printf '0x%x' $((head0 + i)))\", true]" |
            jq -r --arg a0 "$(addr_of PRIVATE_KEY_0 | tr 'A-F' 'a-f')" \
                 --arg a1 "$(addr_of PRIVATE_KEY_1 | tr 'A-F' 'a-f')" \
                 --arg a2 "$(addr_of PRIVATE_KEY_2 | tr 'A-F' 'a-f')" '
            [.transactions[]?
             | select((.from | ascii_downcase) != $a0 and
                      (.from | ascii_downcase) != $a1 and
                      (.from | ascii_downcase) != $a2)] | length')
        [ "$regular" = "0" ] || fail_case "block $((head0 + i)) has $regular non-signer txs"
    fi
done
pass_case "10 consecutive blocks with no regular user txs"
