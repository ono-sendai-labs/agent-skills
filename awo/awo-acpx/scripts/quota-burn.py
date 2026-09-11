#!/usr/bin/env python3
"""Per-turn weekly (secondary) rate-limit burn, grouped by codex rollout.

One acpx session == one rollout file. Each `token_count` event carries the
account-wide rate_limits snapshot, so the first and last snapshot inside a
rollout bracket what that session's turns cost against the weekly window.

Do NOT sum `last_token_usage.total_tokens` across events to estimate cost: with
prompt caching each request re-reports several hundred thousand cached tokens,
so the sum overcounts by more than an order of magnitude. The percentage is the
billed truth; tokens are shown only as scale.
"""
import json, glob, sys

rolls = {}
for path in sorted(glob.glob(f"{sys.argv[1]}/**/rollout-*.jsonl", recursive=True)):
    name = path.rsplit("/", 1)[-1]
    with open(path) as fh:
        for line in fh:
            if '"rate_limits"' not in line:
                continue
            try:
                p = json.loads(line)
            except ValueError:
                continue
            rl = p.get("payload", {}).get("rate_limits") or {}
            sec = (rl.get("secondary") or {}).get("used_percent")
            if sec is None:
                continue
            info = p.get("payload", {}).get("info") or {}
            peak = (info.get("last_token_usage") or {}).get("total_tokens") or 0
            r = rolls.setdefault(name, {"first": sec, "last": sec, "ts0": p.get("timestamp"),
                                        "ts1": p.get("timestamp"), "n": 0, "peak": 0})
            r["last"] = sec
            r["ts1"] = p.get("timestamp")
            r["n"] += 1
            r["peak"] = max(r["peak"], peak)

print(f"{'started':<17} {'weekly start':>12} {'end':>6} {'burn':>6} {'reqs':>6} {'peak ctx':>10}")
tot = 0.0
for name, r in sorted(rolls.items(), key=lambda kv: kv[1]["ts0"]):
    burn = r["last"] - r["first"]
    tot += burn
    print(f"{r['ts0'][:16]:<17} {r['first']:>11.1f}% {r['last']:>5.1f}% {burn:>5.1f}% {r['n']:>6} {r['peak']:>10,}")
print(f"\ntotal weekly burn across these rollouts: {tot:.1f}%")
