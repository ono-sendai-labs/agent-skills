#!/usr/bin/env bash
# Report the codex harness's current rate-limit state.
#
# acpx does not surface quota. The codex harness records it on every
# `token_count` event in its rollout JSONL, so the most recent such event in the
# most recently written rollout is the freshest reading available locally.
# Costs nothing and touches no network.
#
# Exit: 0 primary quota has headroom; 1 primary >= 95%; 2 no reading found.
set -uo pipefail

threshold="${1:-95}"
newest=$(ls -t "$HOME"/.codex/sessions/*/*/*/rollout-*.jsonl 2>/dev/null | head -1)
[ -n "$newest" ] || { echo "no codex rollout found" >&2; exit 2; }

python3 - "$newest" "$threshold" <<'PY'
import json, sys, time, datetime
path, threshold = sys.argv[1], float(sys.argv[2])
rl = None
with open(path) as fh:
    for line in fh:
        if '"rate_limits"' not in line:
            continue
        try:
            payload = json.loads(line)
        except ValueError:
            continue
        found = payload.get("payload", {}).get("rate_limits")
        if found:
            rl = found
if rl is None:
    print("no rate_limits in %s" % path, file=sys.stderr)
    sys.exit(2)

print("source: %s" % path)
primary_pct = None
for name in ("primary", "secondary"):
    win = rl.get(name)
    if not win:
        continue
    pct = win.get("used_percent")
    resets = win.get("resets_at")
    when = datetime.datetime.fromtimestamp(resets).strftime("%Y-%m-%d %H:%M:%S") if resets else "?"
    mins = round((resets - time.time()) / 60, 1) if resets else "?"
    print("%-9s %5.1f%% used  window=%smin  resets %s (in %s min)"
          % (name, pct, win.get("window_minutes"), when, mins))
    if name == "primary":
        primary_pct = pct
        if resets and resets <= time.time():
            print("          ^ reading is STALE: this window's reset time has passed.")
            print("            rate_limits refresh only when a turn runs, so the figure")
            print("            above predates the reset and quota has almost certainly")
            print("            replenished. Treat as headroom.")
            primary_pct = 0.0

secondary = rl.get("secondary") or {}
sec_pct = secondary.get("used_percent")
sec_resets = secondary.get("resets_at")
sec_stale = bool(sec_resets and sec_resets <= time.time())
if sec_pct is not None and sec_pct >= 93 and not sec_stale:
    print("")
    print("*** WEEKLY (secondary) QUOTA AT %.1f%% ***" % sec_pct)
    print("    The orchestrator MUST stop and tell the user when this window")
    print("    exhausts. The user holds manual GPT quota resets that replenish")
    print("    it, and there is no local API to trigger one -- it is a")
    print("    stop-and-ask, not something to wait out. A weekly reset is days")
    print("    away, so waiting is not a recovery strategy here.")
    print("")
    print("    93%% is the launch floor, not the exhaustion point: the largest")
    print("    single observed session burn is 5%% of the weekly window (a 67-min,")
    print("    2353-tool-call implementer turn), so launching above 94%% risks")
    print("    stalling that turn mid-flight. Below 93%%, launch freely.")

credits = rl.get("credits") or {}
print("credits:  has=%s unlimited=%s balance=%s  plan=%s  reached=%s"
      % (credits.get("has_credits"), credits.get("unlimited"),
         credits.get("balance"), rl.get("plan_type"), rl.get("rate_limit_reached_type")))

sys.exit(0 if (primary_pct is not None and primary_pct < threshold) else 1)
PY
