#!/usr/bin/env bash
# Report the codex harness's current rate-limit state.
#
# acpx does not surface quota. The codex harness records it on every
# `token_count` event in its rollout JSONL, so the most recent such event in the
# most recently written rollout is the freshest reading available locally.
# Costs nothing and touches no network.
#
# A reading is only ever produced BY A TURN. There is no way to poll for a
# current one, so after any break the newest reading is the one the previous run
# left behind, and its age is printed for exactly that reason. See the note this
# prints on an aged reading: the figure is not refutable without launching.
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
stamp = None
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
            stamp = payload.get("timestamp")
if rl is None:
    print("no rate_limits in %s" % path, file=sys.stderr)
    sys.exit(2)

# Age of the reading itself. Anything beyond a few minutes means no turn has run
# since, which is the normal state at the start of a resumed run.
age_min = None
if stamp:
    try:
        t = datetime.datetime.strptime(stamp[:19], "%Y-%m-%dT%H:%M:%S")
        age_min = (time.time() - t.replace(tzinfo=datetime.timezone.utc).timestamp()) / 60
    except ValueError:
        pass

print("source: %s" % path)
if age_min is None:
    print("reading:  age unknown (no timestamp on the event)")
elif age_min < 60:
    print("reading:  %.0f min old" % age_min)
else:
    print("reading:  %.1f h old  (%s)" % (age_min / 60, stamp))

AGED_MIN = 30.0
aged = age_min is not None and age_min > AGED_MIN
if aged:
    print("")
    print("*** THIS READING PREDATES THIS RUN — it is %.1f h old ***" % (age_min / 60))
    print("    rate_limits are emitted only by a turn. There is no way to poll for a")
    print("    current figure, so nothing below can be refreshed without launching one.")
    print("    Treat it as a LOWER BOUND on usage, not as a launch gate: the windows can")
    print("    only have replenished since (by rolling, or by a user-held manual reset),")
    print("    never worsened. If it looks bad, launch the cheapest useful turn anyway and")
    print("    take the real measurement from that turn's own rollout.")

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
    if aged:
        print("    ...ACCORDING TO A READING %.1f h OLD. Do NOT stop and ask on this"
              % (age_min / 60))
        print("    figure alone: only a turn refreshes it, so stopping here on a stale")
        print("    number is a deadlock -- the one action that could refute it is the one")
        print("    being refused. Launch one cheap turn, re-read, and decide on that.")
        print("")
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
