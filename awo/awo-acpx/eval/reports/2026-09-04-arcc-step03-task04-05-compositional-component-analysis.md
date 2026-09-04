# awo-acpx RUN 4 (part 2) — arcc, step 03 tasks 04–05

Verbatim continuation of the orchestrator's `work_log` for RUN 4, picking up where
[part 1](2026-09-03-arcc-step03-task04-compositional-component-analysis.md) stopped.
Skill revision under test: `ecb43935`. New findings **F-60, F-61**.

Read part 1 first — but read this one for the mechanism.

## Why this part exists

Part 1 ended by identifying the kill vector: Claude Code's own low-memory watchdog
`kill()`ing the turn's explicit pid alongside a `killpg` on the wrapper's group. **That
identification stands and is confirmed again here** (kill #6, byte-identical signature).
What does **not** stand is the *account of the condition* part 1 gave for it. Two more
kills and, more usefully, **three surviving turns under host-side tracing** have corrected
it twice.

Corrections carried in this part, each of which reverses something asserted earlier:

1. **`Committed_AS` overcommit is not the discriminator.** Part 1 argued from
   `Committed_AS` at 2.1× `CommitLimit`. Across a 37-minute window with two survivals and
   one kill, `Committed_AS` moved 2 % and was *lower* at one survival than at another.
   What tracks the outcome is **absolute `MemAvailable`**.
2. **"Spawn allocation rather than residency" was also wrong**, and was inferred from the
   same bad gauge. Residency matters — it determines how much headroom a spawn has. The
   working model is now: the watchdog watches real free memory; a **fresh adapter spawn** is
   the transient allocation that crosses the line; everything else resident sets the margin.
   F-59's *remedy* survives intact; its *mechanism* is replaced.
3. **The `Stop` hook is not the trigger.** The new hook probe made it look like one — a
   `Stop` 13 s before the kill. It fires 8–12 s after *every* backgrounded launch, including
   both survivals. Recorded as falsified so it is not re-chased.
4. **§4.2's producer-count wording was right and part 1's sharpening of it was wrong.**
   Part 1 claimed the miscount had a deterministic cause and always undercounts by one, on
   two samples. Task 05's producer counted correctly under identical conditions, including
   the inherited empty `@`. Four observations, two miscounts.

**F-61** is the new actionable item and it is not about acpx at all: the project's own
Bazel server grew to **1261 MB** inside an agent turn, making it the largest process in the
sandbox — larger than any adapter, larger than `claude`. It belongs to no session and
survives every session close and every session restart. Mitigation aimed only at adapters
attacks the second-largest term.

**F-60** covers a gap on the deferral path: §4.6 tells you to describe the change with "the
*approved* review's `merge_request`", but §4.4's deferral branch reaches §4.6 with no
approved review, and §4.6's preservation rule only reaches findings "left open as a
suggestion" — not the `important` ones a deferred task actually ships with.

Also verified positively here, both for the first time in four runs:

- **§4.7's bookmark fixes §4.1.** Task 05's base carried
  `pr/awo-record-…-step03-task-04`, so §4.1 was satisfiable with **no deviation** — the
  defect RUN 3 recorded as F-41 after having to pick between two conflicting MUSTs.
- **§4.4's deferral branch and §4.6/§4.7 finalization**, end to end, on a task that ended
  `changes_requested` with `max_rework_rounds` exhausted.
- **`setsid` demonstrably takes effect.** The hook probe's mid-turn process snapshot shows
  the turn holding its own SID and PGID, so the `killpg` genuinely could not reach it and
  only the explicit `kill(pid)` could. The defence works against the attack it was designed
  for; the harness simply also does something else.

---

# RUN 4 (resumed, 3rd time) — additional probes installed; run until the next kill

The user resumed the session with more probes in `~/acpx-forensics/`, watched by a separate
skill-writing agent, and asked me to continue until another kill.

## New probe surface (read before resuming)

- **`hooklog.sh` + `hooks.log`** — a Claude Code **hook** logger wired into `settings.json`
  (a backup, `settings.json.bak-1788490511`, sits beside it). It logs `SessionStart`,
  `PreToolUse`, `PostToolUse` and — critically — takes a **full in-sandbox process snapshot**
  on `PreCompact`, `Stop`, `SessionEnd` and `SubagentStop`. It records each Bash call's
  `run_in_background` flag and `timeout`. This is aimed squarely at the remaining open
  question: *what harness-side event coincides with the sweep*. It always exits 0 so it
  cannot perturb the session under observation.
- **`pstree.out`**, and rotated **`sigtrace.log.1` / `pidmap.log.1`** from the previous window.
- `sigtrace.log` is now owned by `nobody:nogroup` — the tracer was restarted under a different
  privilege context. Fresh: mtime 2026-09-04T03:14:51Z, ~70 s before I looked.

## Starting state — **the sandbox was NOT restarted, and that matters**

```
claude     415 MB     70 s   ← only this is new; the session was resumed, not the sandbox
java       742 MB   5054 s   ← Bazel server from round 4's `just ci`, still resident
opencode   478 MB   5396 s   ← implementer adapter awo-impl-…-task04b, held by --ttl 0
codex      172 MB   6875 s   ┐
bun        100 MB   5396 s   │ reviewer adapter awo-rev-…-task04d chain,
bun         99 MB   6876 s   │ held by --ttl 0
node        80 MB   6875 s   ┘

MemAvailable:   11 093 856 kB
CommitLimit:    48 856 360 kB
Committed_AS:  102 511 968 kB   ← 2.10x, essentially identical to the value at kill #5
```

So this run **re-enters at the same overcommit that produced kill #5**, with every adapter
from before still held by `--ttl 0`. That is F-59 demonstrated rather than argued: a session
restart does not reclaim them; only a sandbox restart or an explicit close does.

## A falsifiable prediction, stated before launching

F-59's mechanism says the front-loading is driven by **adapter spawn** — a launch allocates a
new adapter, which trips the watchdog, which kills the launch. If that is right, then a turn
issued into an **already-warm adapter should be at markedly lower risk**, because it allocates
almost nothing at launch.

The round-4 review goes to `awo-rev-…-step03-task04d`, whose codex adapter chain has been
**alive for 6875 s**. No new adapter will be spawned. **Prediction: this turn survives**,
despite the overcommit being as bad as it was at kill #5, and despite kill #5 having struck the
very same session 6 seconds in — because kill #5 came 5 s after `acpx-open.sh` had spawned that
adapter, and this one does not spawn anything.

If it is killed anyway, at comparable latency, the spawn-allocation part of F-59's mechanism is
**wrong** and the trigger is something else — most likely a periodic or event-driven sweep that
the new `hooks.log` will now be able to correlate. Either outcome is informative; recording the
prediction first so it cannot be fitted after the fact.

I am deliberately **not** reducing memory before this turn — not closing the idle implementer
adapter, not touching the stale 742 MB Bazel server — because doing so would confound exactly
the observation the user asked for. Noting that the Bazel JVM is the single largest reclaimable
item and is nobody's live session.

## Loop position

Unchanged: step 3, task 04, **round-4 review outstanding**. `max_rework_rounds` is fully
consumed (4 of 4), so whatever this review returns, no further rework round is available and
§4.4's deferability judgement is the next decision.

## §4.4 Round 4 — re-review. **PREDICTION CONFIRMED: no kill.**

```
elapsed=136s   tool_calls=16
tokens: totalTokens=495880 inputTokens=383 cachedReadTokens=495360 outputTokens=137 thoughtTokens=15
stopReason=end_turn   EXIT=0   compaction: none
```

Topology diff pre/post: **IDENTICAL**. `jj st` clean.

### The F-59 spawn-allocation prediction held

Stated before launch: a turn into an **already-warm adapter** should survive despite overcommit
as bad as at kill #5, because it allocates almost nothing at launch. It did.

| | kill #5 | this turn |
|---|---|---|
| session | `…-task04d` | **same session** |
| adapter age at launch | ~5 s (just spawned by `acpx-open.sh`) | **6875 s (warm)** |
| `Committed_AS` / `CommitLimit` | 2.10× | **2.10×** |
| outcome | **killed at 6 s** | **completed, 136 s** |

Same session, same host, same overcommit, opposite outcome — and the one variable that changed
is whether the launch spawned an adapter. That is about as clean a natural control as this
environment allows, and it **supports the spawn-allocation half of F-59** specifically, not
merely the residency half. The practical implication is concrete: **the dangerous moment is
`acpx-open.sh` + first prompt, not the turn itself**, so reducing *how often sessions are
opened* matters more than shortening turns.

It also retro-explains the whole kill series. Every one of the five kills landed on a turn
whose adapter had just been spawned (kills #2/#3/#4 were three successive `acpx-open.sh`
attempts, each spawning again — hence 24 s → 26 s → 4 s as residency climbed). No kill has ever
struck a turn issued into an adapter that was already warm.

**A session restart reclaims nothing**, incidentally proven this run: only `claude` was new; the
opencode adapter (5396 s), codex chain (6875 s) and Bazel JVM (5054 s) all survived it, so we
re-entered at exactly the pressure that produced kill #5.

> **Context headroom flag.** Reviewer at **495 880 / 850 000 = 58 %**, past the 50 % threshold
> and now past RUN 3's peak of 34 %. Still no compaction, and 58 % is well inside the 790 000
> auto-compact limit, so per §Prompting I am not restarting the session. Recording the crossing.

**Not degradation.** 16 tool calls is far below this task's earlier reviews (338 cold, 136, 76),
which is the shape §Troubleshooting says to be suspicious of. It is not degradation here: the
findings cite exact `file:line` and exact inputs (`store.Load[(int, string)]`,
`example.com/2x.T`, `func(x ...int)`, `&^`), and one of them is a genuine cross-file
contradiction — `validatePathTail` at `capslock.go:632` rejects digit-leading path elements that
the package's own shared `validPackagePath` at `symbol.go:132-150` accepts. That is a *new*
observation requiring both files, not a re-assertion. The low tool count is warmth: this session
has now read this code three times.

**Verdict: `changes_requested`** — 2 important, both AC2 type-grammar. The reviewer answered the
deferability question I put to it directly: *"Those AC2 gaps are blocking for this task; no
findings are safely deferrable to a follow-up while this parser is intended to be the canonical
normalizer."*

---

# RUN STOP — §4.4 block: `max_rework_rounds` exhausted without approval

This is not the kill-triggered stop the user asked for; **no kill occurred.** It is the skill's
own blocking condition, and it is a MUST: *"When `max_rework_rounds` is exhausted without
approval… if the outstanding findings are genuinely deferrable, record them and proceed to §4.6;
otherwise treat as a block and stop."* Rounds 1–4 are consumed. No further rework round exists.

## My deferability judgement, which differs from the reviewer's — and still lands on stop

The reviewer's non-deferability argument rests on the parser being "the canonical normalizer".
**That is true eventually but not yet**, and the task says so: TR7 requires the new code to be
additive and explicitly forbids it altering current verdicts, with the live cutover deferred to
**Step 6**. `ParseCapslock` is not on the production path today. On that reading the residual
grammar gaps are defects in unused code, and a follow-up task before Step 6 would be a
defensible route — an argument the reviewer did not weigh.

I am nonetheless stopping, for a reason that outranks it: **four consecutive reviews have ended
with the same `suggested_action`** — stop inferring structure from text; use Go's real type
syntax, or carry Capslock's structured output. Four rounds of increasingly sophisticated
hand-rolled parsers have each fixed the named cases and each introduced or revealed new ones.
That is the signature of a requirement that may not be satisfiable as written, not of an
implementer failing to try. TR3's "reject names that cannot be mapped safely instead of
guessing" and AC2's fail-closed clause may simply not be achievable from Capslock's *textual*
output alone.

Under §E.2 that is **the user's call, not mine**: choosing between (a) requiring structured
classifier output, (b) narrowing AC2 to an explicitly enumerated supported subset, (c) deferring
the residual gaps to a pre-Step-6 follow-up task, or (d) accepting the current parser is an
*architectural decision*, not the correction of a clear defect — and §E.2 says to stop and
surface exactly that rather than repair inline. Note no producer ever escalated this; I offered
the escalation route once (declared, round 3) and the implementer declined it on the merits.

## State — clean, complete, nothing lost

`@ = uqtpnwpv` empty and childless; `jj st` clean; topology identical to the pre-review
snapshot across 13 ancestors. Task 04's implementation is **complete and committed** through
rework round 4 — ten changes, `just ci` green 79/79 at every round. Unbookmarked and
un-finalized, correctly: §4.6 has not run and must not until the block is resolved.

**Sessions left open** (mid-task stop — **no sweep**, per §Closing a session):
- `awo-impl-…-step03-task04b` (opencode, adapter 5396 s) — holds four rework rounds.
- `awo-rev-…-step03-task04d` (codex, adapter 6875 s) — holds four reviews, 58 % context.

Both are healthy and hold the context a resumption would want. Naming them so they are not
silently orphaned. The stale **Bazel JVM (742 MB, 5054 s)** belongs to no session and is the
single largest reclaimable item if pressure needs reducing.

## To get more kill data

The vector now has a testable model, and the cheapest way to exercise it is **session opens**,
not long turns. Continuing the plan into step 3 task 05 would do that naturally — but it
requires either a decision on task 04, or explicit permission to record it as deferred under
§5.1 and move on. That is one sentence away, and I have deliberately not assumed it.


---

# Task 04 finalized as DEFERRED (user decision)

The user authorized deferring task 04 and flagging its open findings for the step reviewer.
§4.4's "if the outstanding findings are genuinely deferrable, record them in `work_log` and
proceed to §4.6" branch therefore applies.

## §4.6 — the `merge_request` needed rewriting, for the fifth time on this task

**Title.** The reviewer emitted
`fix(symbol): harden Capslock type grammar [Compositional Symbols: Step 03/Task 04]`.
`Compositional Symbols` is **invented**. Verified against the plan's actual convention by
reading the sibling commits, which is what §4.6 says to do:

```
[Compositional Analysis: Step 01/Task 03 rework 1]
[Compositional Analysis: Step 02/Task 01] … [Step 02/Task 03]
[Compositional Analysis: Step 03/Task 01] … [Step 03/Task 03]
```

Seven siblings, all `Compositional Analysis`. **All five reviews of this task invented the same
wrong tag**, so it is stable and deliberate rather than a slip — this reviewer believes the
project is called something it is not. Corrected to `[Compositional Analysis: Step 03/Task 04]`.

**Body.** Reviewer voice again — *"Reviews the complete ten-change series from the supplied base
through the supplied current change… nukpzvow preserves the interrupted first rework; xqvosyps
verifies it…"* — addressed to an orchestrator, carrying raw change-id prefixes that mean nothing
to a PR reader, and saying nothing about what the change *does*. **And it omitted the two open
important findings entirely**, which for a deferred task is the single most important thing the
description has to carry.

Rewritten in the change's voice, preserving every substantive claim and **adding** a `DEFERRED`
section that states: the deferral and who authorized it, both open findings with their exact
`file:line` and reproducing inputs, the internal contradiction between `validatePathTail`
(`capslock.go:632`) and `validPackagePath` (`symbol.go:132`), and the four-review pattern with
the open question about whether TR3/AC2 are satisfiable from textual Capslock output at all.
Nothing the reviewer said was softened or dropped.

> **F-60 — §4.6 — medium.** §4.6 says to describe the oldest change with **"the *approved*
> review's `merge_request`"**. On the deferral path there **is no approved review** — the final
> verdict is `changes_requested` — so the section names an artifact that cannot exist on a route
> §4.4 explicitly provides. I used the final review's `merge_request` and rewrote it, which is
> obviously the intent, but the text does not say so. Worse, §4.6's preservation rule says to
> keep "any finding left open **as a suggestion**" — on this path the open findings are
> `important`, not suggestions, and the rule's wording does not reach them. A deferred task's
> permanent description is the *only* tracked record that it shipped with known defects; the
> skill should require it explicitly. Suggested fix: on the §4.4 deferral branch, mandate a
> `DEFERRED` section listing every open finding at any severity, and change "approved review" to
> "the final review".

`jj describe mumrltmt` reported `Rebased 10 descendant commits`, as §4.6 predicts. Verified
afterwards: all ten change ids unchanged, only commit ids rewritten, and the `wip(symbol)`
recovery description on `nukpzvow` is intact — §4.6's recovery-note rule did not apply here
because the `wip` is the sixth change, not the oldest, so nothing overwrote it.

Bookmark created on the **newest** produced change (`rqmylkmz`):
`pr/2026-08-04-compositional-component-analysis/step03/task-04-implement-symbol-id-grammar.code-task`.
Both sessions closed.

## §4.7 — record committed, and **the new bookmark is verified working**

Copied to `.agents/awo/runs/…/step03/task-04-implement-symbol-id-grammar/`: `task-record.json`,
ten `round-{N}.{result,review}.yaml`, and the **interpreted** kill-evidence tier for all five
lost turns. `raw/` excluded — checked explicitly (`find -name raw -o -name out.json` → 0).

**F-51 does not recur.** `du` reported 340 K, which alarmed me given RUN 3's task-03 record is
600 K and F-51 was exactly this defect. It is a false alarm: every file is ≤ 1607 B and the real
content is **117 905 bytes**; `du` was reporting 4 K block allocation across ~50 small files.
Five kills' worth of interpreted evidence costs ~35 KB, against the ~250 KB *per kill* that raw
would have added. The two-tier split works as designed.

Committed as `chore(awo): record bookkeeping for step03 task 04` and bookmarked
`pr/awo-record-2026-08-04-compositional-component-analysis-step03-task-04`.

> **§4.7's new bookmark — VERIFIED, and it fixes F-41.** The next task's base is this commit,
> and it now carries one of the two names §4.1 sanctions. §4.1 is therefore satisfiable on task
> 05 **without deviating**, which is precisely what RUN 3 could not do (F-41, which it recorded
> as a medium-high judgement call after picking one of two conflicting MUSTs). The fix works.
> It also restores §Recovering's `jj abandon` anchor to the correct change, closing the
> secondary hazard I pre-registered in F-52.


---

# Step 3 · Task 05 — `task-05-add-canonical-artifact-io`

§4.1 clean. **Base carried `pr/awo-record-…-step03-task-04`** — §4.7's bookmark, one of the two
names §4.1 sanctions. **First task in four runs where §4.1 was satisfiable with no deviation.**

## §4.3 Round 0 — implementation (survived)

```
elapsed=1531s  tool_calls=764   totalTokens=120372  cachedReadTokens=120064
stopReason=end_turn  EXIT=0  compaction: none
```

Three changes: `osyvqoun` canonical encode/decode/digest, `plzvnlto` atomic write with
failure-injection seams, `tomnpmyw` component registration. `just ci` green. `@` empty and
childless, `@-` described and unbookmarked, `result.change_id` = `tomnpmyw…` exact match, base
still an ancestor, all three ids `ok`.

### §4.2 — the producer's count was **correct** this time, and I over-read task 04

Producer said three; the revset says three — **and it correctly counted the inherited empty `@`**
(`osyvqoun`), which is the exact thing it got wrong on task 04. Same mechanism available, right
answer.

**Correcting myself.** After task 04 I wrote that §4.2's "not biased, it is unreliable" framing
was "generous", because the error had "a deterministic cause (inheriting `@`) and always
undercounts by exactly one". That was two samples and it is now falsified: 4 observations, 2
miscounts, both directions of behaviour under identical conditions. **§4.2's wording is right
and my sharpening of it was wrong.** The revset remains mandatory precisely *because* you cannot
tell from outside which kind you got.

## §4.4 Round 0 — review: **KILL #6**

```
LAUNCH 03:53:37Z   SIGTERM 03:54:01Z (24s)
2026-09-04T03:54:01Z SIGTERM after 24s; turn pid 177082 alive; parent 176989 alive
acpx-progress.sh → DEAD, 6 tool events, adapter status=idle pid=-
```

Topology diff pre/post **IDENTICAL**; `jj st` clean. Reviewer loss, provably inert → **loop guard
not charged**, `max_rework_rounds` not charged. Session closed; fresh one needed to retry.

Same signature as kill #5, confirmed in `sigtrace.log`:

```
20:54:01.637608 CALL kill(pid=-176989, sig=15) by 2584279/2584279(claude) ppid=1932148(bash) gp=1932147(sh) ggp=1932146(script)
20:54:01.637624 CALL kill(pid=177066, sig=15) by 2584279(claude)
```

`kill(-176989)` = killpg on `wrapper_ppid`'s group, then `kill(177066)` = the wrapper, by
**`claude` directly**. Identical to kill #5. The mechanism is settled.

### The `Stop`-hook hypothesis — tested and **FALSIFIED**

The new hook probe showed a `Stop` event at **03:53:48.972Z**, 11 s after launch and **13 s
before the kill** — an obvious candidate trigger (the harness reaping background work when the
main loop goes idle). It is not the trigger. Every backgrounded launch is followed by a `Stop`
8–12 s later, because that is simply me ending my message:

| bg launch | Stop | Δ | outcome |
|---|---|---|---|
| 03:17:10 | 03:17:18 | 8 s | **survived** (round-4 review, 136 s) |
| 03:27:24 | 03:27:36 | 12 s | **survived** (task-05 implementer, 1531 s) |
| 03:53:37 | 03:53:48 | 11 s | **KILLED** at 03:54:01 |

`Stop` is present in every case including both survivals, so it is **necessary-looking and
actually incidental**. Recording it explicitly so the skill-writing agent does not re-chase it.

### What *does* discriminate: absolute free memory, not `Committed_AS`

Three launches in 37 minutes, two survived, one died. The variable that moved:

| | 03:17 (survived) | 03:27 (survived) | 03:53 (**killed**) |
|---|---|---|---|
| adapter | warm, no spawn | **fresh spawn** | **fresh spawn** |
| `java` (Bazel server) RSS | 742 MB | 742 MB | **1261 MB** |
| `MemAvailable` | 11.09 GB | 11.09 GB | **10.59 GB** |
| `Committed_AS` | 102.5 GB | 101.9 GB | 104.0 GB |

`Committed_AS` moved **+2 %** across the whole window and was *lower* at one survival than at
another — it does not discriminate. What changed is that the **Bazel JVM grew 742 MB → 1261 MB
(+519 MB) during the task-05 implementer turn's `just ci`**, and `MemAvailable` fell by ~500 MB.
The next fresh adapter spawn then tipped it over.

**This corrects my earlier reasoning twice over.** I had argued from `Committed_AS` at 2.1×
`CommitLimit` (kill #5) that overcommit was the condition; and after closing two adapters barely
moved `Committed_AS` I inferred that "spawn-time allocation" rather than residency was the term.
Both were reading the wrong gauge. The consistent story across all six kills is simpler:
**the harness watches real available memory, and a fresh adapter spawn is the transient
allocation that crosses the line — so whatever else is resident determines how much headroom
that spawn has.**

That keeps F-59's *remedy* (close sessions promptly; do not hold two adapters open across a
task) and replaces its *mechanism*: residency matters because it consumes headroom, not because
commit accounting trips a threshold.

> **F-61 — new, medium-high, and actionable.** **The project's own build gate is the largest
> single consumer and it grows monotonically inside agent turns.** The Bazel server reached
> **1261 MB** and is the biggest process in the sandbox — larger than any adapter, larger than
> `claude`. It belongs to no acpx session, survives every session close and every session
> restart, and each `just ci` grows it further. Any mitigation that only closes adapters is
> attacking the second-largest term. The skill cannot fix a project's build system, but it can
> (a) note that a JVM-based gate inside turns is a first-order input to the kill risk, and
> (b) make "reclaim the build daemon between tasks" an available step at task boundaries, where
> `@` is empty and nothing is in flight.

### Additional detail the enhanced probe gave us

`wrapper-signals.log` now carries a process line, and the `Stop` snapshot caught the full tree
mid-turn:

```
177082  177066  PGID=177082  SID=177082  node  acpx …     ← the turn: own session AND own group
177100  177082  PGID=177100  SID=177100  bun   __queue-owner   ← adapter chain, CHILD of the turn
177119  177100  node  codex-acp
177131  177119  bun   codex.js app-server
177142  177131  codex codex app-server
```

Two things confirmed: **`setsid` did take effect** (the turn holds its own SID and PGID, so the
`killpg(-176989)` genuinely could not reach it — only the explicit `kill(pid)` could); and on a
*fresh* session the whole adapter chain is a **child of the turn**, which is why
`acpx-progress.sh` reported `adapter: status=idle pid=-` — killing the turn took the newborn
adapter with it. On a warm session the queue owner is already reparented to pid 1 and survives,
which is exactly what was observed at kills #1–#5.

## STOP — kill #6 observed, as instructed

Repository clean: `@ = sszqzuyu` empty and childless, task 05's three changes committed and
unbookmarked (correct — §4.6 has not run), task 04 finalized and bookmarked.
No sessions left open: the task-05 implementer completed and its reviewer was closed after the
kill. **To resume:** open a fresh reviewer for task 05 round 0 and re-issue
`round-0.reviewer/prompt.md` (ids verified). Nothing is charged.


---

# Appendix — kill #6, and the survival controls

`{run_dir_root}` is gitignored in the target repo, so this is preserved here. Host tracer
timestamps are **local (-0700)**; the work log is UTC. 20:54:01 local = 03:54:01Z.

## B.1 The kill, host-side — identical signature to kill #5

```
2026-09-03T20:54:01.637608 CALL kill(pid=-176989, sig=15) by 2584279/2584279(claude) ppid=1932148(bash) gp=1932147(sh) ggp=1932146(script)
2026-09-03T20:54:01.637622 GEN  sig=15 -> tgt=2968838(bash) code=0 group=1 result=0 from 2584279(claude) pidns=-268434142
2026-09-03T20:54:01.637624 CALL kill(pid=177066, sig=15) by 2584279/2584279(claude) ppid=1932148(bash) gp=1932147(sh) ggp=1932146(script)
2026-09-03T20:54:01.637628 GEN  sig=15 -> tgt=2968915(bash) code=0 group=1 result=0 from 2584279(claude) pidns=-268434142
2026-09-03T20:54:01.637629 CALL kill(pid=177082, sig=15) by 2584279/2584279(claude) ppid=1932148(bash) gp=1932147(sh) ggp=1932146(script)
2026-09-03T20:54:01.637658 GEN  sig=15 -> tgt=2968931(node) code=0 group=1 result=0 from 2584279(claude) pidns=-268434142
```

`turn.meta`: `turn_pid=177082  wrapper_pid=177066  wrapper_ppid=176989`. So
`kill(-176989)` is a `killpg` on the wrapper's parent group and `kill(177066)` is the
wrapper, both issued by **`claude`** (host pid 2584279) whose own ancestry is
`bash → sh → script`. Same shape as kill #5, different pids.

## B.2 `setsid` provably worked — the turn had its own session and process group

From the `Stop` hook's mid-turn process snapshot (in-sandbox pids):

```
    PID    PPID    PGID     SID ELAPSED STAT COMMAND         COMMAND
      1       0       0       0   11028 S+   bwrap           bwrap --die-with-parent --unshare-all --share-net --clearenv --tmpfs / --ro-bind /usr /us
      2       1       0       0   11028 S+   script          script /dev/null -q -c /bin/bash
  86236   86221   86221   86221    1584 Sl   opencode        opencode acp
 176989   81497  176989  176989      11 Ss   bash            /bin/bash -c source /home/xtof/.claude/shell-snapshots/snapshot-bash-1788491759163-75ma1c
 177066  176989  177066  176989      11 S    bash            bash .agents/skills/awo-acpx/scripts/acpx-prompt.sh --repo /home/xtof/git/ono-sendai-labs
 177082  177066  177082  177082      11 Ssl  node            node /home/xtof/.bun/bin/acpx --approve-all --format json --suppress-reads --ttl 0 --cwd 
 177100  177082  177100  177100      11 Ssl  bun             /home/xtof/.bun/bin/bun /home/xtof/.bun/install/global/node_modules/acpx/dist/cli.js __qu
 177119  177100  177100  177100      10 Sl   node            node /home/xtof/.bun/bin/codex-acp
 177131  177119  177100  177100      10 Sl   bun             /home/xtof/.bun/bin/bun /home/xtof/.bun/install/global/node_modules/@openai/codex/bin/cod
 177142  177131  177100  177100      10 Sl   codex           /home/xtof/.bun/install/global/node_modules/@openai/codex-linux-x64/vendor/x86_64-unknown
```

`177082` (the turn) holds `PGID=177082 SID=177082` — its own, distinct from the wrapper's
`176989`. The `killpg(-176989)` therefore genuinely could not reach it; only the explicit
`kill(177082)` could. **The detachment works against the attack it was designed for.**

Note also that on a *fresh* session the adapter chain (`177100` queue-owner → `codex-acp`
→ `codex app-server`) is a **child of the turn**, which is why `acpx-progress.sh` reported
`adapter: status=idle pid=-` after this kill. On a warm session the queue owner has already
reparented to pid 1 and survives — which is what was observed at kills #1–#5, and is why
"the adapter always survives" was true until it wasn't.

## B.3 The control series — two survivals and a kill in 37 minutes

This is the part that corrects part 1. All three are backgrounded `acpx-prompt.sh` launches
in the same session, same host, no restarts in between.

| | 03:17:10 | 03:27:24 | 03:53:37 |
|---|---|---|---|
| role | round-4 review | task-05 implementer | task-05 review |
| adapter | **warm** (6875 s) | **fresh spawn** | **fresh spawn** |
| `java` (Bazel) RSS | 742 MB | 742 MB | **1261 MB** |
| `MemAvailable` | 11.09 GB | 11.09 GB | **10.59 GB** |
| `Committed_AS` | 102.5 GB | 101.9 GB | 104.0 GB |
| `Stop` hook fired | +8 s | +12 s | +11 s |
| **outcome** | survived 136 s | survived 1531 s | **KILLED at 24 s** |

`Committed_AS` spans 101.9–104.0 GB across all three and is *lowest* at a survival —
it does not discriminate. `Stop` fires in all three. What moves with the outcome is
`MemAvailable`, and the reason it moved is that the Bazel server grew **+519 MB** during
the 03:27 turn's `just ci`.

## B.4 Memory at the kill

```
MemTotal:       32119384 kB
MemAvailable:   10643020 kB
SwapTotal:      32796668 kB
SwapFree:       27032920 kB
CommitLimit:    48856360 kB
Committed_AS:   104020120 kB

               total        used        free      shared  buff/cache   available
Mem:           31366       20973        3584         984        8300       10393

# largest processes at the kill
    PID ELAPSED   RSS COMMAND
  54412    7870 1261168 java
  86236    2130 584736 opencode
  81497    2886 440940 claude
  86221    2130 116140 bun
      4   11574  6888 bash
```

The Bazel server is the **largest process in the sandbox**, ahead of the opencode adapter
and `claude` itself. It is owned by no acpx session, is untouched by `acpx-close.sh --sweep`,
and survived both a session resume and (in part 1) a full sandbox restart of the agent
processes. That is F-61.

## B.5 Wrapper signal logs for both kills in this part

```
2026-09-04T03:54:01Z SIGTERM after 24s; turn pid 177082 alive; parent 176989 alive
 177082  177066      23     0 node
```
