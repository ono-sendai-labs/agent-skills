# awo-acpx orchestration report — 2026-08-04-compositional-component-analysis

> **Provenance.** Verbatim copy of the orchestrator's live work log from the run, checked
> in here because the original lives in a gitignored scratchpad
> (`.agents/scratchpad/awo-acpx-report.{slug}.md`) in another repository and would not
> survive. Written incrementally *during* the run, so it reads chronologically and
> contains in-flight reasoning, two self-corrections, and one orchestrator error — all
> left in deliberately. Findings are tagged `[F-nn]` and cited by the skill changes they
> produced.
>
> **Run:** `ono-sendai-labs/architectural-contracts` (public), plan
> `2026-08-04-compositional-component-analysis`, step 1 only — 3 tasks, 15 agent turns.
> **Skill under test:** `awo-acpx` at commit `rvnwyxxl a949b850`, i.e. the revision
> *before* the changes this report motivated (`sttoxozs cfbee2a4`).

**Skill under test:** `awo-acpx` (prototype), `/home/xtof/git/ono-sendai-labs/agent-skills/awo/awo-acpx/SKILL.md`
**Run scope:** Step 1 only, by user instruction. Do not continue to Step 2.
**Orchestrator:** Claude Opus 5 (this session)
**Repo:** `/home/xtof/git/ono-sendai-labs/architectural-contracts` (jj only)

This log doubles as the skill-evaluation deliverable. Findings are tagged `[F-nn]`
and cross-referenced to the skill section they come from.

---

## 0. Preflight

### 0.1 Skill availability (user-requested check)

`.agents/skills/awo-acpx -> ../../../agent-skills/awo/awo-acpx` — present, resolves,
`SKILL.md` readable. Verified and read in full before starting, including the
§Relationship to `awo-orchestrator` table.

Producer skills required by §Parameters are also linked:
`task-to-code`, `code-task-review`, `plan-to-tasks` — all present in `.agents/skills/`.

### 0.2 Environment

- `acpx` 0.12.0 at `/home/xtof/.bun/bin/acpx` — on PATH. ✓
- `acpx config show`: agents `opencode` (`opencode "acp"`) and `codex` (`codex-acp`)
  both configured. ✓  `nonInteractivePermissions: deny` — confirms §Sessions' claim
  that `--approve-all` is required.
- `jj st`: empty working copy, `@-` = `okkymzso 08b7e043` on bookmark
  `dev-exp-go-bazel-mvp`. ✓ (§1 satisfied at entry.)

### 0.3 Resolved parameters

| Parameter | Value | Source |
|---|---|---|
| `plan_file` | `.agents/planning/2026-08-04-compositional-component-analysis/implementation/plan.md` | user |
| `planning_slug` | `2026-08-04-compositional-component-analysis` | derived per §Parameters |
| `repo` | `/home/xtof/git/ono-sendai-labs/architectural-contracts` | default |
| `work_log` | this file | default |
| `run_dir_root` | `.agents/runs-acpx/` | default (created; did not exist) |
| `generate_tasks_cmd` | unset | → §2 self-run path |
| `max_rework_rounds` | 4 | default |

### 0.4 Next step number

Plan progress checklist has **all 13 steps unchecked**; no prior `work_log` for this
slug existed. Next step = **1**. Consistent with the §Parameters constraint to derive
it from both sources rather than assuming 1.

---

## Findings log

### F-01 — §Parameters: default models are not the ones this repo uses, and are unverifiable

`implementer_model` defaults to `opencode-go/glm-5.3-flash`, `reviewer_model` to
`gpt-5.6-sol`. The repo's own awo driver scripts (`.agents/scratchpad/awo-run-task.sh`,
`awo-run-task-gemini-codex.sh`) use `gpt-5.6-luna` / `gpt-5.6-terra` /
`google/gemini-3.6-flash`. The skill offers no way to enumerate valid model ids —
`acpx <agent> models` is not a subcommand; acpx parses `models` as prompt text and
fails with `⚠ No acpx session found`.

**Severity:** low here (see F-02: `gpt-5.6-sol` was accepted), but it is a
stop-the-run condition per §Troubleshooting "`set model` printed nothing, or the wrong
model", and the skill gives no procedure for discovering a valid substitute.

**Decision taken:** used the skill defaults verbatim.

### F-02 — §Sessions "Opening a session": `model set:` echo is not verification

The skill says "confirm the command printed `model set: {model}`". It did:

```
$ acpx --cwd "$REPO" codex -s awo-gen-…-step01 set model gpt-5.6-sol
model set: gpt-5.6-sol
```

But this is an echo of the value acpx forwarded, not a confirmation the adapter
resolved it to a real model. A typo'd model id would very plausibly produce the same
line and then fail (or silently fall back) at first prompt. The check the skill asks
for is weaker than the guarantee §Troubleshooting claims it gives.

The skill also does not say what a successful `set reasoning_effort` looks like.
Observed: `config set: reasoning_effort=medium (4 options)` — note it is NOT of the
form `model set: …`, so an orchestrator pattern-matching on the documented shape would
wrongly conclude failure.

### F-03 — §2: the task-generation prompt omits the non-interactive preamble

§4.3 and §4.4 both mandate a preamble ("This session runs in non-interactive mode…
Do not ask for clarification…"). §2's generation prompt has none, despite running in
exactly the same non-interactive, `--format quiet` conditions.

**Decision taken:** ran §2's prompt verbatim (no preamble), because §2 is the cheapest
place to actually observe whether the omission bites, and one retry is affordable.

### F-04 — §2 / §Artifacts: no home is specified for generation-round artifacts

§Artifacts enumerates `{run_dir_root}/{ts}-step{NN}-task-{MM}-{slug}/` only. The
generation turn has a prompt, stdout, and a stderr token line that §Sessions says
MUST be recorded, but nowhere defined to put them.

**Decision taken:** invented `.agents/runs-acpx/step01-taskgen/`.

### F-05 — step-number padding is inconsistent within §2

Session name: `awo-gen-{planning_slug}-step{NN}` (zero-padded, per §Sessions).
Bookmark:     `pr/awo-generate-task-{planning_slug}-step-{step_number}` (un-padded,
              and with an extra hyphen).
Task bookmark (§4.6): `pr/{slug}/step{NN}/…` (zero-padded again).

So for step 1 the same step is `step01` in two places and `step-1` in another. §4.6
stresses the task bookmark "must match exactly" because PR generation consumes it;
nothing says whether the generation bookmark is likewise consumed. This is exactly the
class of thing the `awo` binary decided deterministically.

**Decision taken:** followed each name literally as written — `…-step01` for sessions,
`pr/awo-generate-task-{slug}-step-1` for the generation bookmark. Confidence:
moderate. Candidate for `awo check`.

### F-06 — §Parameters: `work_log` default collides with nothing, but resumes nothing

Default is `.agents/scratchpad/awo-acpx-report.{slug}.md`. This repo's prior
orchestration logs are `.agents/scratchpad/orchestration-report.{slug}.md`. A plan
partly driven by `awo-orchestrator` and then picked up by `awo-acpx` will not find the
existing log, defeating the §Parameters constraint "derive the next step number from
`plan_file`'s progress checklist and `work_log` together". Not triggered in this run
(step 1, no prior log), but a real resumption hazard.

### F-07 — §Troubleshooting "A turn appears to hang": the liveness command is wrong

The skill (and the user's constraint restating it) gives:

```sh
acpx --cwd "$REPO" {agent} status
```

Run verbatim while the generation turn was demonstrably in flight, it reports on the
**cwd-default** session, not the named one:

```
$ acpx --cwd "$REPO" codex status
session: -      agent: codex-acp      pid: -      status: no-session
```

Taken at face value that reads as "the turn is dead" — the exact wrong conclusion, and
one that invites cancelling or restarting live work. The `-s` flag is required:

```
$ acpx --cwd "$REPO" codex status -s awo-gen-…-step01
session: 01a06560-…  pid: 52733  status: running  model: gpt-5.6-sol  uptime: 00:00:40
```

Same defect applies to the §Troubleshooting cancel line, which *does* carry `-s`, so
the omission in `status` is an inconsistency inside one paragraph.

**Bonus:** this command is the *real* model verification F-02 asks for — `status -s`
reports the model the adapter actually resolved. The skill should use it instead of
trusting the `model set:` echo.

**Decision taken:** use `status -s {session}` throughout.

### F-08 — §Validation Posture conflates "base moved" with "history rewritten"

Mid-run the user committed `chore: gitignore .agents/runs-acpx` (`otqsxlnq 0b0397a4`)
while the generation turn was in flight. `@` advanced from `otqsxlnq` to `knzzromy`;
the old `@` became `@-`.

§Validation Posture says: *"The task's base identity is still what you recorded at
§3.1. A base that moved under you means something rewrote history; stop."* That
inference is not sound. A base can move because someone appended a change below you —
benign, additive, and the *normal* thing in a shared jj working repo — or because
history was rewritten. Only the second warrants a stop. The check should compare
whether the recorded base change ID is still an **ancestor of `@`** (benign) versus
absent-or-divergent (rewrite).

As written, following the skill literally here would have stopped a healthy run.

**Decision taken:** treated the append as benign; verified `otqsxlnq` is `@-` and the
prior tip `okkymzso` is still its ancestor with an unchanged commit ID. Confidence:
high.

Also note §Validation Posture cites "§3.1", which does not exist — §3 has no
subsections; base recording is §4.1. Dangling cross-reference.

### F-09 — the skill does not say whether `run_dir_root` is tracked or ignored

`.agents/runs-acpx/` is now gitignored (user's commit). §Artifacts calls the per-task
records "the forensic record for the prototype evaluation" and §4.2 says "You MUST
keep every round's prompt file and captured output in this directory" — but never says
whether they are meant to be committed alongside the work or kept untracked. Left
untracked here. If they are meant to be durable/auditable, the skill needs to say so,
because §4.6/§1's "commit stray files if present" would otherwise sweep them into an
implementation change.

---

## §2 — Task generation for Step 1

**Session:** `awo-gen-2026-08-04-compositional-component-analysis-step01` (codex,
gpt-5.6-sol, reasoning_effort=medium).
**Prompt:** §2 template verbatim, no preamble (per F-03).
**Command:**
```sh
acpx --approve-all --format quiet --timeout 3600 --cwd "$REPO" \
     codex -s awo-gen-…-step01 --file .agents/runs-acpx/step01-taskgen/gen.prompt.md \
     >gen.out.txt 2>gen.err.txt
```
**Exit:** 0. **Wall clock:** 20:46:53 → 20:51:53 = **5m00s**.
**stderr token line:** `[acpx] tokens: input=516 output=326 cache_read=78464 total=79306`

**Result:** 3 task files, committed as `knzzromy 0c95decd`
`docs(tasks): define compositional analysis step 1`, no bookmark created by the agent,
`@` left empty. Exactly the §2 contract — no self-commit needed, no repair needed.

- `task-01-measure-current-analysis-phases.code-task.md`
- `task-02-propagate-empty-provider-for-non-go-targets.code-task.md`
- `task-03-harden-host-path-groundwork.code-task.md`

Bookmark created: `pr/awo-generate-task-2026-08-04-compositional-component-analysis-step-1`
(un-padded `step-1`, per F-05). Session closed.

F-03 (missing preamble) **did not bite** here: the agent asked no questions.

### F-10 — §Sessions: `--format quiet` does not do what the skill says

§Sessions: *"`--format quiet` puts only the final assistant text on stdout"*.

Observed: stdout carried **five** assistant messages — running narration ("I'll load
the plan-to-tasks workflow…", "Parameters are complete…", "Step 1 breaks cleanly into
three sequenced atomic tasks…", "The first CI attempt reached the test suite but…")
concatenated with no separator before the actual final message. There is no delimiter,
so "read the final assistant text" (§4.3, §Validation Posture "when the final
assistant text states the outcome unambiguously") has no mechanical definition — you
get a wall of run-on prose and must judge where the last message begins.

This directly undermines the §Validation Posture escape hatch of routing on prose when
an artifact is missing. Consequence for a future `awo check`: prose routing needs
`--format json` (message-delimited), not `quiet`.

### F-11 — §Sessions: the token line is not cumulative, so it cannot measure the hypothesis

Observed after a 5-minute turn that read a 495-line plan, the design doc, research
notes, wrote three task files and ran `just ci` twice:

```
[acpx] tokens: input=516 output=326 cache_read=78464 total=79306
```

`input=516` cannot be the whole turn. The line appears to report the **final
model call** (or the last increment), not the session total. §Sessions states this line
"is the primary instrumentation for this prototype: it shows whether long sessions
actually save context reacquisition, and whether the step-scoped reviewer's context
grows unsustainably."

If it is per-call rather than cumulative, it measures neither. `cache_read` is the only
field that tracks accumulated context, and it conflates the agent's own system prompt
and skill files with conversation history. I will keep recording it for every round and
report the trend, but flag that the skill's stated instrument is weaker than it claims.
Verified across the reviewer's rounds below.

---

## §3 — Step reviewer session

`awo-rev-2026-08-04-compositional-component-analysis-step01`
(`01a06565-b7e0-7483-a77f-51362e1e02cd`), codex / gpt-5.6-sol / medium.
Opened once, before the first task. Will not be reopened between tasks (§3 constraint).
Model confirmed by `status -s` (per F-07), not just the `set model` echo.

## §4 — Task 01: measure-current-analysis-phases

### §4.1 base

`@` empty ✓. Base `@-` = `knzzromy 0c95decd`, already bookmarked
`pr/awo-generate-task-…-step-1` from §2, so no `awo-loop-checkpoint-…` bookmark was
needed.

### F-12 — §4.1's checkpoint bookmark is dead code on the first task of a step

§4.1 says create `awo-loop-checkpoint-step{NN}-task{MM}-{task_slug}` if `@-` has no
bookmark. For task 01 the base is always the §2 generation change, which §2 *requires*
be bookmarked. For tasks 02+ the base is the previous task's tip, which §4.6 *requires*
be bookmarked. So the branch is unreachable in the normal flow — it can only fire after
an abnormal exit. Not wrong, but the skill presents it as a routine check.

### §4.2 run record

`.agents/runs-acpx/20260903T035253Z-step01-task-01-measure-current-analysis-phases/`

### F-13 — §4.2: `{timestamp}` format is unspecified

The run-dir name is `{run_dir_root}/{timestamp}-step{NN}-task-{MM}-{task_slug}/`, with
no format given. Chose `20260903T035253Z` (UTC, compact ISO-8601) so directories sort
lexically in run order. A different orchestrator would pick differently and lose the
sort property. Trivially deterministic in a CLI; unspecified here.

### Round 0 — implementer

Session `awo-impl-…-step01-task01` (`ses_f9a9a0ed2ffeJ0kZGbyc4GtQnV`), opencode /
`opencode-go/glm-5.3-flash`, no reasoning_effort (§Parameters default is unset).
Model confirmed via `status -s`.

Prompt: §4.3 template verbatim.

**Round 0 implementer — result**

- Exit 0. Wall clock 20:53:06 → 21:08:19 = **15m13s**.
- stderr: `[acpx] tokens: input=1000 output=54 cache_read=82624 total=83735`
- Produced `urmzqoqo b18bc3d8` *docs(research): measure five-phase cost attribution of
  arcc check* — one file, `research/current-analysis-pipeline.md`.
- §Validation Posture post-implementation checks: `@` empty ✓ and childless ✓
  (`descendants(@)` = itself only); `@-` non-empty ✓, described ✓, no bookmark ✓;
  `@-` change id `urmzqoqoqmzs` matches `result.change_id`
  `urmzqoqoqmzskvvvpqvkwvqlvywryxxz` ✓. `result.status: completed` → §4.4.
- No repair prompt needed.

Second data point for **F-11**: `input=1000 output=54` after a 15-minute turn that
built the binary, ran five profiled `arcc check` runs, edited and reverted
instrumentation, and ran `just ci`. Confirms the token line is a **per-call**, not
per-turn or per-session, figure. `cache_read` moved 78 464 → 82 624 across two
*different* sessions on the same repo, which suggests it mostly tracks the harness's
own preamble, not conversation growth. As an instrument for this prototype's two
hypotheses it is close to useless.

### F-14 — §Validation Posture: "change ID matches" is underspecified

`result.change_id` is the **full** 32-char change id
(`urmzqoqoqmzskvvvpqvkwvqlvywryxxz`); `jj log` shows the 12-char prefix
(`urmzqoqoqmzs`). The skill says the ids must "match". Prefix containment is obviously
intended, but a strict equality check would fail every round. Deterministic in a CLI;
here it is a judgement call I am confident about, but it is the kind of thing that
silently rots.

Related: `result.yaml` declares `schema_version: 2` while the emitted
```spec-workflow-meta``` block declares `schema_version: 1`. §Validation Posture's
tolerance for "schema imperfections" covers this, and the verdict was unambiguous, so
I proceeded. Recorded because a schema-enforcing `awo check` would have to decide
which one wins.

### Round 0 — reviewer (first turn of the step-scoped session)

Per §4.4, prefixed with the §4.3 non-interactive preamble because it is the reviewer's
first task in the step. Pre-review topology snapshotted to
`round-0.pre-review.topology` so the §Validation Posture "repository unchanged" check
can be done by diff rather than by memory.

### F-15 — §Validation Posture's post-review check needs a snapshot the skill never tells you to take

"After a reviewer turn: the repository is unchanged — same `@-` change ID, commit ID,
description, and bookmarks as before the review." Nothing in §4.4 or §4.2 instructs you
to *capture* that state beforehand, and the run record's schema (§4.2) has no field for
it. Doing the check properly requires inventing a pre-review snapshot artifact.

**Round 0 reviewer — result**

- Exit 0. Wall clock 21:08:55 → 21:11:11 = **2m16s**.
- stderr: `[acpx] tokens: input=459 output=65 cache_read=53376 total=53900`
- §Validation Posture post-review check: pre/post topology snapshots **identical**
  (`diff` clean), `@` still empty. Reviewer did not mutate the repository ✓.
- Verdict: **`changes_requested`** — 2 `important` findings, AC1 pass, AC2 partial,
  AC3 **fail**, AC4 pass.

**Review quality, round 0 (baseline for the step-scoped-reviewer hypothesis).** High.
It did not take the implementer's evidence at face value: it opened `work.log`, found
that the member-only measurements were *wall-only* (55.8/53.7/53.0 ms) while the note
presented a CPU bound as measured, and separately re-did the arithmetic
(11.97 s of 11.97 s phase sum = 100%, or 89.3% of 13.4 s whole-process) to show the
claimed 92-93% / 98-99% figures use mixed denominators. It also caught that categories
(a) and (b) are described as disjoint but are not. Both findings carry concrete
`suggested_action`s. This is the bar the later tasks in the step get measured against.

Notable honesty signal: it recorded that its own `just ci` rerun failed on an absent
external Go build cache and explicitly declined to hold that against the change.

### F-16 — token line makes the reviewer-growth hypothesis unmeasurable

Reviewer round 0: `cache_read=53376`. Implementer round 0: `cache_read=82624`.
The reviewer — which has just ingested a task file, a design doc, a research note and a
full diff — reports *less* accumulated context than the implementer's last call.
These numbers are not comparable across agents (codex vs opencode) and, per F-11, are
not turn totals. §Troubleshooting "The reviewer's answers are degrading across the
step" asks for "the token line at that point" as the evidence to record; that evidence
does not carry the signal. I will instead assess reviewer drift from **review content**
(finding count, depth, whether it re-derives numbers) across tasks 01-03.

### Round 1 — rework, same implementer session

Prompt: §4.5 template verbatim. **No restatement** of the task, the skill, the file
paths under work, or the prior implementation — this is the direct test of hypothesis 1.
The prompt names only the review path and the fresh-commit requirement.

**Round 1 implementer (rework) — result**

- Exit 0. Wall clock 21:11:34 → 21:14:30 = **2m56s** (vs 15m13s for round 0).
- stderr: `[acpx] tokens: input=1324 output=54 cache_read=94656 total=96034`
- Produced **fresh child** `qrootkqv e93b758d` *docs(research): correct member CPU
  attribution and redesign projection*.
- §4.5 no-rewrite check: previous produced change `urmzqoqo` is **still present** in
  `jj log` with an **unchanged commit id** `b18bc3d8`, and is `@-`'s ancestor ✓.
  Not a rewrite.
- `@` empty and childless ✓, `@-` described, unbookmarked ✓, change id matches
  `result.change_id qrootkqvruvtmkqxynvzzqkmkpnxvowy` ✓. `status: completed`.

## ★ Hypothesis 1 — did the implementer retain context across the rework round? **Yes, clearly.**

The §4.5 prompt named only a review path and "produce a fresh commit". It restated
nothing: not the task, not the skill, not the research note's path, not what "member
CPU" or "the attribution table" referred to, not the measurement harness it had built
and then deleted in round 0.

Evidence of retention:

1. **Its entire round-1 output was one sentence of work, no re-orientation:**
   "Member CPU measured (≈0.55s CPU / 0.17s wall per invocation incl. the
   `go list -export` subprocess). Updating the attribution table and conclusion per
   the findings." Contrast round 0, which opened with "Scratchpad setup, then explore
   the check path call sites."
2. **It re-derived a measurement that required rebuilding tooling it had removed.**
   The round-0 member-only harness was deleted before committing (AC4 forbids leaving
   instrumentation). To answer the reviewer's "record member-only user+sys" finding it
   had to reconstruct that harness — and did so without being told it had existed, what
   it measured, or that `go list -export` was inside the measured region.
3. **It tracked the reviewer's per-criterion verdicts.** The new `result.yaml` says of
   AC1: *"unchanged this round, review marked it pass."* It carried forward the
   distinction between criteria it needed to fix and criteria it merely needed to
   preserve.
4. **5.2× faster** (2m56s vs 15m13s) on a round whose substantive work — a new CPU
   measurement run — was not obviously cheaper than round 0's per-phase profiling.
   The saving is consistent with skipped exploration, not skipped work.

At no point did it behave as though it had forgotten the task. It did not ask what the
task was, did not re-read the task file before acting, and did not re-explore the
codebase. This is the prototype's central claim and on this task it holds.

**Caveat:** one rework round on one task. Whether retention survives 3-4 rounds, or a
round separated by a long reviewer turn, is not established by this run.

### Round 1 — re-review

Prompt: §4.4's re-review template verbatim, which deliberately does *not* restate the
prior findings — testing the reviewer session's own continuity.

**Round 1 reviewer (re-review) — result**

- Exit 0. Wall clock 21:14:54 → 21:16:24 = **1m30s** (round 0 review: 2m16s).
- stderr: `[acpx] tokens: input=2280 output=65 cache_read=86144 total=88489`
- Post-review topology **identical** ✓, `@` empty ✓.
- Verdict: **`changes_requested`** again. AC1 pass, AC2 partial, AC3 fail→**partial**,
  AC4 pass. Two new `important` findings, both distinct from round 0's.

**Reviewer continuity — positive evidence.** The re-review prompt (§4.4 template)
deliberately does not restate the prior findings, and the reviewer clearly still held
them. It scored the rework *against its own earlier findings by name*:

- "The rework usefully adds measured member-only user+sys CPU, **addressing the first
  half of the prior finding**."
- "The rework correctly uses whole-process CPU as the CPU denominator and identifies
  Capslock as the largest phase, **resolving those parts of the prior finding**."

That partial-credit accounting is exactly what a cold per-round reviewer cannot do
without being fed the prior review.

**Reviewer did not go soft.** It gave credit and then found *new* arithmetic defects at
the same level of rigour as round 0 — it caught that the note's prose says the member
harness wall is 53-59 ms while the retained samples say 165-171 ms, that the same
category therefore carries two contradictory measured wall values, that a claimed "<1%"
comparison is actually 4-5%, and that the eliminated categories sum to 3.31 s (91%) not
the claimed 3.57 s (98-99%). It re-added the four table values by hand to get there.
No sign of anchoring on round 0 or of waving the rework through.

### Round 2 — rework

**Round 2 implementer (rework) — result**

- Exit 0. Wall clock 21:16:48 → 21:18:55 = **2m07s**.
- stderr: `[acpx] tokens: input=1163 output=54 cache_read=102208 total=103425`
- Produced fresh child `rwkmsxzw f4b95237` *docs(research): reconcile harness wall
  readings and wall reduction projection*.
- No-rewrite check ✓: `urmzqoqo b18bc3d8` and `qrootkqv e93b758d` both still present
  with unchanged commit ids.
- `@` empty/childless ✓, `@-` described/unbookmarked ✓, change id matches ✓,
  `status: completed`.
- Output was the ```spec-workflow-meta``` block **and nothing else** — no narration at
  all. Third round in the session; still no re-orientation, still no re-reading of the
  task file.

### F-11 / F-16 — PARTIAL RETRACTION: `cache_read` *does* track within-session growth

Earlier I judged the token line useless for the prototype's hypotheses. With four
rounds of data that is too strong, and the correction matters:

| Round | Session | `cache_read` |
|---|---|---|
| impl r0 | implementer | 82 624 |
| impl r1 | implementer | 94 656 |
| impl r2 | implementer | 102 208 |
| rev r0 | reviewer | 53 376 |
| rev r1 | reviewer | 86 144 |

Within a single session `cache_read` grows monotonically, so it **is** a usable proxy
for session context accumulation — the implementer's session grew ~24% over two rework
rounds, the reviewer's ~61% over one re-review.

What remains true from F-11/F-16: `input`/`output` are per-call, not per-turn, so
"total" is not a turn cost; and the figures are **not comparable across agents**
(codex vs opencode preambles differ), so the reviewer's lower absolute number says
nothing about how much it had ingested. The skill should say to read `cache_read`
*within a session over rounds*, and should not imply the line gives per-turn cost.

### Round 2 — re-review

**Round 2 reviewer (re-review) — result**

- Exit 0. Wall 21:19:14 → 21:20:57 = **1m43s**.
- stderr: `[acpx] tokens: input=554 output=64 cache_read=123264 total=123882`
- Topology unchanged ✓.
- Verdict: **`approved`**. All four ACs `pass`. One `suggestion`-severity finding
  (the harness aggregates three `packages.Load` calls; a reader could mistake its
  total for one redesigned load).

Note the approval is *not* a soft one: it still filed a finding, it just graded it
`suggestion` rather than `important`, and its reasoning explicitly says why the issue
"does not invalidate the attribution or conclusion". Severity discrimination intact
after three rounds.

### §4.6 Finalize task 01

- `@` empty ✓.
- `jj describe urmzqoqo` with the approved review's `merge_request.title` + `body`.
- `jj bookmark create pr/2026-08-04-compositional-component-analysis/step01/task-01-measure-current-analysis-phases.code-task -r rwkmsxzw` ✓ (created, no collision).
- Implementer session closed ✓. `task-record.json` outcome written.
- Deferred: the one `suggestion` finding. §4.5 only compels "critical and important",
  so a suggestion on an `approved` verdict is not rework-triggering. Recorded here as
  the §4.7 audit trail requires.

### F-17 — §Operating Constraints forbids what §4.6 requires

§Operating Constraints: *"Never destroy completed work. No `jj abandon`, no `jj undo`,
no amending or squashing changes produced by a task loop."*

§4.6: *"You MUST describe the **oldest** produced change of this task … using
`jj describe`."*

`jj describe` on the oldest produced change **is** an amend of a change produced by the
task loop, and jj reported `Rebased 3 descendant commits`. Every produced commit id
changed:

| change | commit id before §4.6 | after |
|---|---|---|
| `urmzqoqo` | `b18bc3d8` | `5b2b3db4` |
| `qrootkqv` | `e93b758d` | `dc7bb77e` |
| `rwkmsxzw` | `f4b95237` | `5ef733b3` |

Content and change ids are preserved, so nothing was destroyed and I proceeded — §4.6
is plainly the more specific instruction and the rewrite is description-only. But the
skill states the prohibition without the exception, and it has a concrete consequence:
**§4.5's no-rewrite evidence ("the previous produced change ID must still be present …")
is commit-id-based in practice, and §4.6 invalidates commit ids for every earlier
task in the step.** An `awo check` verifying topology across tasks must compare change
ids, never commit ids, and must expect the oldest change's description to differ from
what the implementer wrote.

**Confidence: high** that describing was correct. This is a wording defect, not a
judgement call I am unsure of.

## Task 01 summary

| Round | Role | Wall | Verdict | `cache_read` |
|---|---|---|---|---|
| 0 | implementer | 15m13s | completed | 82 624 |
| 0 | reviewer | 2m16s | changes_requested (2 important) | 53 376 |
| 1 | implementer | 2m56s | completed | 94 656 |
| 1 | reviewer | 1m30s | changes_requested (2 important) | 86 144 |
| 2 | implementer | 2m07s | completed | 102 208 |
| 2 | reviewer | 1m43s | **approved** (1 suggestion) | 123 264 |

Total task wall clock ≈ **25m45s** across 6 turns. Produced series
`urmzqoqo → qrootkqv → rwkmsxzw`, bookmarked at the tip.

---

## Task 02 — round 0 turn KILLED mid-flight (BLOCKED, awaiting user)

### What happened

Launched task-02 round 0 at 21:22:20 exactly as the previous five turns. ~2 minutes in,
the **harness** reported the background task `killed`. I issued no cancel, no `TaskStop`,
and no `acpx cancel`. The task output file contains only `[killed]` — no exit code, so
§Sessions' exit-code routing table has nothing to route on.

Killing the acpx *client* tore down the adapter:

```
$ acpx --cwd "$REPO" opencode sessions show awo-impl-…-step01-task02
agentSessionId:    -                          <-- never persisted
pid:               -
closed:            no
historyEntries:    2
agentStartedAt:    2026-09-03T04:22:21.140Z
lastExitAt:        2026-09-03T04:24:20.991Z
lastExitCode:      -
lastExitSignal:    -
disconnectReason:  pipe_close
```

`status -s` now reports `status: idle`, which is indistinguishable from a healthy
session that has never been prompted.

### Repository state — partial work exists

```
twsxxsuvmusn d7c3b98e []  wip          <-- @, 45 insertions, uncommitted turn's work
kpvyvmltwxzl af7d06c0 []               <-- empty, no description
rwkmsxzwyvtq 5ef733b3 [pr/…/task-01-….code-task]  <-- task 01 tip (intact)
```

`wip` touches `bazel_rules/go/tests/aspect_tests.bzl` (+18),
`bazel_rules/go/tests/probe.bzl` (+16), `bazel_rules/go/tests/testdata/BUILD.bazel`
(+11), and adds an empty `testdata/nongo_data.txt`. That is plausibly the *test* half of
task 02 with the `aspect.bzl` production fix not yet written. Task 01's series is
untouched.

### Why this is a stop-and-ask, not a judgement call

The skill does not cover a killed acpx client anywhere. §Sessions' exit table covers
0/1/3/4/5/130; a harness-killed launcher yields none of them. §Troubleshooting covers a
turn that *appears* to hang, not one whose client died. And the three available
dispositions are not equivalent:

1. **Re-prompt the same session.** `closed: no`, so acpx will accept a prompt. But
   `agentSessionId: -` means the opencode-side conversation was never persisted, so it
   will almost certainly come back **cold** while still being the session named
   `awo-impl-…-task02`. That silently contaminates task 02's hypothesis-1 evidence:
   a cold agent in a "long-lived" session is exactly the failure mode I was told to
   watch for, and I must not confuse it with the real thing.
2. **Fresh session, let it absorb the `wip` change.** Clean context, but the new
   implementer inherits 45 lines of code it did not write and the §4.3 contract expects
   a clean base.
3. **Fresh session on a clean base.** Requires disposing of `wip` — and
   §Operating Constraints forbids `jj abandon`/`jj undo`, so "clean" is not freely
   available to me.

Option 1 risks a false positive on the prototype's central claim. Options 2 and 3 both
touch produced work in ways the skill forbids me to decide unilaterally.

Per §Operating Constraints ("When in doubt, stop and ask the user") and the run's own
instruction to stop rather than guess where a wrong choice is hard to undo:
**stopping here.** Repository left exactly as the killed turn left it; nothing
abandoned, nothing edited by me. Reviewer session for step 01 left **open** (it holds
task 01's history and is needed for tasks 02-03). Task-02 implementer session left
open and unprompted.

### F-18 — §Sessions has no exit route for a killed client, and `status` cannot detect it

Two defects compound:
- The exit-code table has no row for "client killed / pipe closed"; there is no exit
  code at all to route on.
- After the kill, `status -s` reports `idle` — the same word a fresh, healthy,
  never-prompted session reports. Distinguishing them requires `sessions show` and
  reading `disconnectReason`/`lastExitAt`/`agentSessionId`, which the skill never
  mentions. An orchestrator following the skill would re-prompt and silently get a cold
  agent.

Concrete fix: after any turn that does not exit 0, `sessions show` and treat
`disconnectReason: pipe_close` with an empty `agentSessionId` as **session lost** —
open a fresh session and record the context loss.

### Recovery decision (user-directed)

Asked the user rather than guessing. The user **abandoned the `wip` change themselves**
(`jj abandon d7c3b98e`, op `9bff42811465`) and directed me to investigate the crash
before restarting. Post-abandon state verified clean:

```
kpvyvmltwxzl af7d06c0 []                                    <-- @, empty
rwkmsxzwyvtq 5ef733b3 [pr/…/task-01-….code-task]            <-- @-, task 01 tip
```

So task 02 restarts at §4.1 with base `rwkmsxzwyvtq` — the same base it had before the
kill, with no residue. Note the disposal required `jj abandon`, which
§Operating Constraints forbids **me** to use; the user was able to do it precisely
because the constraint binds the orchestrator, not the human. That asymmetry is why
stopping was right, but it also means **the skill has no orchestrator-executable
recovery path from a killed turn at all** — every clean route out is forbidden to it.
This is the strongest argument in the run for an `awo check`/`awo recover` CLI, or at
minimum an explicit §Troubleshooting exception permitting abandonment of a change the
orchestrator can prove was produced by an interrupted turn.

Crash investigation delegated to a Sonnet subagent (read-only forensics on
`~/.acpx/`, opencode state dirs, and the bundled acpx source). Findings below when it
returns.

### Proposed skill patch — orchestrator-executable recovery from an interrupted turn

Discussed with the user, who proposed "only abandon jj commits above anything already
bookmarked". That is the right shape but too permissive as stated, because in this
skill's topology the in-flight task's produced series `I1…In` is **unbookmarked until
§4.6**. Mid-task, "above the newest bookmark" therefore includes completed, reviewed
rounds — exactly the work §Operating Constraints protects. A kill during round 2 would
license abandoning I1 and I2.

**Tightened predicate.** `task-record.json` is already the ledger of work that survived
a round (§4.2 requires appending to `produced_changes` as each change is created), so:

> You MAY `jj abandon` a change only when **all** of the following hold:
> 1. it is a strict descendant of the newest bookmark on the current stack;
> 2. it carries no bookmark itself; and
> 3. its change id does **not** appear in `produced_changes` of the active
>    `task-record.json`.
>
> Evaluate descendants-first and re-check after each abandon. Before abandoning,
> write `jj diff -r <C>` into the run dir so the discarded work is legible in the
> audit trail, not merely recoverable from `jj op log`.

Anything above the newest bookmark and absent from `produced_changes` is by
construction the output of a turn that never reported completion. Applied to this run,
the predicate selects exactly `twsxxsuv` ("wip") and nothing else — identical to the
disposal the user performed manually.

**Loop guard.** At most **one** automatic recovery attempt per round; a second kill on
the same round is stop-and-ask. A killed turn MUST NOT consume a `max_rework_rounds`
slot, since no review occurred — otherwise flaky infrastructure silently drains the
rework budget and the task fails for an unrelated reason. (§Sessions already worries
about this for exit 5: "a denied implementer produces nothing while still consuming a
round".)

**Note on the prohibition's premise.** `jj abandon` is not destructive in jj: the
operation log retains the change and `jj op restore` recovers it. §Operating
Constraints' blanket "no `jj abandon`, no `jj undo`" reads as if written against git
reset semantics. The hazard actually worth guarding is *losing reviewed work*, and
`produced_changes` names that set precisely — so the constraint can be narrowed
without loss of safety.

### Crash forensics — verdict: neither acpx nor opencode is unstable

Read-only investigation (delegated to a Sonnet subagent) across `~/.acpx/sessions/`,
opencode's log and SQLite store, and the bundled acpx source.

**Q1 — cause of death: external SIGTERM to the process group. High confidence.**

- `~/.local/share/opencode/log/opencode.log` for this run (`run=a043f2c5`): 222 lines,
  211 INFO / 11 WARN, **zero** ERROR/panic/OOM. The log simply stops mid-stream after
  an ordinary `message=loop … step=18` at 04:24:19.987 — the signature of a killed
  process, not a handled crash.
- opencode's SQLite (`~/.local/share/opencode/opencode.db`) shows the preceding tool
  call `completed` at 04:24:19.964, then a **new empty assistant message** (step 19,
  zero parts, zero tokens) created at 04:24:19.989 — a live loop severed instantly,
  not a hang.
- acpx's own wire log
  (`~/.acpx/sessions/ses_f9a7f3680ffe2t2UXr2z7Bq7Lg.stream.ndjson`, 772 lines) ends
  with an **outgoing `session/cancel`** — a message only the *client* sends. acpx ran
  its normal coded interrupt path (`withInterrupt` → `cancelActivePrompt(2500ms)` →
  `close()`), i.e. it *received* a termination signal; it did not detect an agent fault.
- `disconnectReason: pipe_close` is a race artifact: acpx attaches `exit`, `close` and
  `stdout.close` listeners and keeps whichever fires first. `stdout.close` won and read
  `child.exitCode`/`signalCode` as `null` — consistent with the whole process group
  going down together.
- Clean sessions show `closed: true` with all exit fields **null**; acpx doesn't
  populate them on graceful close. So `disconnectReason` non-null + `closed: false` is
  specifically the interrupted-disconnect signature.
- OOM could not be ruled in or out (no journald/dmesg in this sandbox), but nothing in
  the token/cost/timing data suggests memory pressure.

**Conclusion: the tooling is not implicated.** `opencode` was doing correct TDD work
(the tool call it had just finished was a RED-phase `bazel test` exiting 1 — the
*expected* failure) and was killed by the harness supervisor. No basis to call acpx or
opencode unsuitable for long-running orchestration on this evidence.

### F-18 — CORRECTED. My "session lost / cold resume" inference was WRONG.

I reported that `agentSessionId: -` meant the agent-side conversation was never
persisted and a re-prompt "will almost certainly come back **cold**". **That is false**,
and it materially skewed the recovery options I presented to the user.

What the code and stores actually show:

- `reconcileAgentSessionId()` only assigns when the adapter returns an id in the
  JSON-RPC response `_meta`. The **opencode adapter never sends `_meta` at all** —
  `grep -c '_meta'` over the 772-line wire log returns **0**. So `agentSessionId` is
  `-` for this adapter on **every** session, successful or killed. It is not a kill
  signature and carries no information about resumability.
- Resume does not key on it. acpx self-assigns `acp_session_id`
  (`ses_f9a7f3680ffe…`), always persists it, and replays it verbatim in
  `session/resume`.
- opencode's own SQLite row for that exact id is **fully populated and unarchived**:
  title "Empty provider propagation for non-Go targets", **20 messages / 73 parts**,
  `time_archived: NULL`. The full transcript survived the kill.

So re-prompting the killed session would very likely have resumed **warm**. My option 1
("almost certainly cold") was wrong on its central claim, and the strong warning
attached to it was unjustified. The user's own choice — abandon and restart clean —
remains sound for other reasons, but they were choosing against a hazard I had
overstated.

Retained from F-18, and still valid: **`status -s` alone cannot distinguish a killed
session from a healthy unprompted one** (both report `idle`), and §Sessions' exit table
has no row for a killed client (no exit code is produced at all). The correct detector
is `sessions show` → `closed: false` **with a non-null `disconnectReason`**, *not* the
`agentSessionId` field.

### F-19 — §Sessions' capture recipe discards diagnostics that already exist

The skill's invocation is `--format quiet` with stderr to a file, and no `--verbose`.
In this failure both files were empty, so the skill's prescribed forensics yielded
nothing. Yet acpx had silently recorded the entire ACP conversation to
`~/.acpx/sessions/{id}.stream.ndjson` the whole time — including the smoking-gun
`session/cancel`.

The skill should name that path as the black-box recorder. It is always on, costs
nothing, and is strictly better than `--verbose` for post-hoc analysis (which only
writes to stderr and would have been lost to the same kill).

**Decision for the remaining turns:** do **not** add `--verbose`. The wire log already
captures more, and changing the invocation mid-run would make the remaining turns
non-comparable with tasks 01's six. Recording the ndjson path per round instead.

**Instrumentation available for future runs** (verified):

| Tool | Lever | Value |
|---|---|---|
| acpx | flag | `--verbose` (stderr only; no log file) |
| acpx | per-session wire log | `~/.acpx/sessions/{id}.stream.ndjson` — always on |
| acpx | session record | `~/.acpx/sessions/{id}.json` |
| acpx | env | no general debug var; `--verbose` is the only toggle |
| opencode | flags | `opencode acp --log-level DEBUG --print-logs` (config currently runs bare `opencode "acp"`) |
| opencode | log | `~/.local/share/opencode/log/opencode.log` — always written |
| opencode | state | `~/.local/share/opencode/opencode.db` (SQLite: `session`/`message`/`part`) |
| opencode | env | `OPENCODE_LOG_LEVEL`, `OPENCODE_PRINT_LOGS`, `OPENCODE_AUTO_HEAP_SNAPSHOT` (for suspected OOM) |

---

## Task 02 — propagate-empty-provider-for-non-go-targets

Restarted after the kill. Fresh implementer session
`awo-impl-…-step01-task02b` (`ses_f9a669989ffedi04F2x7502Iru`), opencode /
`opencode-go/glm-5.3-flash`. Base `rwkmsxzwyvtq` (unchanged from the killed attempt).
Reviewer session is still the **original** step-01 session — the cross-task continuity
test survived the interruption intact.

**Round 0 implementer — result**

- Exit 0. Wall 21:49:15 → 21:55:10 = **5m55s**.
- stderr: `[acpx] tokens: input=7780 output=249 cache_read=51968 total=60035`
- Produced `kpvyvmlt 47c981fd` *fix(bazel): provide empty ArccPackageInfo for non-Go
  aspect targets*: `aspect.bzl` (the production fix), `aspect_tests.bzl`, `probe.bzl`,
  and a new `testdata/nongo/` fixture.
- Validation ✓: `@` empty and childless, `@-` described/unbookmarked, change id matches
  `result.change_id`.
- Genuine TDD: it reported RED (`does not provide advertised provider
  'ArccPackageInfo'` — the exact violation named in friction report §1), then GREEN with
  8/8 aspect tests, then a full green `just ci`.

Note it also reasoned unprompted about §5's checklist rule: *"Step 1 still has task-03
pending, so the plan checklist stays unchecked."* The producer skill is aware of the
step-completion contract the orchestrator is supposed to verify.

Comparison with the killed attempt: the first attempt was at `bazel test` RED phase
~2 minutes in; this one reached the same point and completed in 5m55s total. Consistent
work, no sign the earlier kill reflected anything about the task.

**Round 0 reviewer** — second task in the step, so per §4.4 the non-interactive preamble
was **not** repeated. This is the first real test of reviewer continuity *across tasks*
rather than across rounds.

**Round 0 reviewer — result**

- Exit 0. Wall 21:55:30 → 21:56:43 = **1m13s**.
- stderr: `[acpx] tokens: input=518 output=78 cache_read=159232 total=159828`
- Topology unchanged ✓.
- Verdict: **`approved`** first round, all four ACs pass, **zero findings**.

**Is this the reviewer going soft? No — assessed carefully, because a zero-finding
approval after four consecutive `changes_requested` verdicts is exactly the drift
signature §Troubleshooting warns about.**

Evidence it is a real approval:
- Every AC cites specific `file:line` ranges for **both** implementation and test
  (`aspect.bzl:25-31`, `probe.bzl:58-71`, `aspect_tests.bzl:150-165`,
  `testdata/nongo/BUILD.bazel:5-14`), not summaries.
- It independently verified the "Go traversal unchanged" criterion by reading the diff
  and observing that only the early non-Go return changed — it did not simply accept
  the implementer's claim.
- It cited the RED evidence (`work.log:51-66`, Bazel rejecting the missing advertised
  provider) and the GREEN evidence (`work.log:76-100`) separately.
- It again flagged its own environment limitation honestly (could not acquire the Bazel
  output base) and explicitly declined to hold it against the change — the same
  discipline it showed in task 01 round 0.
- The task is objectively small: a ~6-line `aspect.bzl` change plus a fixture and one
  analysis test. A finding-free approval is proportionate.

**Reviewer context growth across the step so far** (`cache_read`, one session):

| Point | `cache_read` |
|---|---|
| task 01 r0 | 53 376 |
| task 01 r1 | 86 144 |
| task 01 r2 | 123 264 |
| task 02 r0 | 159 232 |

Roughly linear, ~+35k per review turn, ~3× over four turns. No quality degradation
observed at 159k. Whether this stays sustainable across a 6-task step is untested here.

### §4.6 Finalize task 02

`jj describe kpvyvmlt` with the approved `merge_request` (`Rebased 1 descendant
commits` — see F-17), bookmark
`pr/…/step01/task-02-propagate-empty-provider-for-non-go-targets.code-task` created on
the sole produced change, implementer session closed, record written.

Note: with a single produced change, §4.6's "describe the **oldest**, bookmark the
**newest**" collapses to one change. The skill handles this correctly by construction,
but it is worth stating that the two instructions can target the same change.

---

## Task 03 — harden-host-path-groundwork

Base `kpvyvmltwxzl` (task 02's bookmarked tip). Fresh implementer session
`awo-impl-…-step01-task03` (`ses_f9a5ef898ffewwS4sW23AMFh2G`). Reviewer: still the
original step-01 session, now entering its **third** task.

**Round 0 implementer — result**

- Exit 0. Wall 21:57:34 → 22:06:54 = **9m20s**.
- stderr: `[acpx] tokens: input=1315 output=54 cache_read=65920 total=67289`
- Produced **two** changes:
  1. `sqnxwpnn bd16537e` *fix(manifestparity): canonicalize import paths before parity
     comparison [Compositional Analysis: Step 01/Task 03]* — `manifestparity.go`,
     its test, `BUILD.bazel`, and `packagelayout_test.go`.
  2. `nruknntk 9ba4a1a6` *docs(plan): mark compositional analysis step 1 complete* —
     flips `- [ ] **Step 1**` to `- [x]` in `plan.md`.
- `result.change_id` = `sqnxwpnnyowl…` (the **first** change). `@-` is `nruknntk`.

### ★ F-20 — §5 anticipates a commit that §Validation Posture and §4.3 reject

§Validation Posture, MUST-check every round: *"`@-`'s change ID matches the
`result.change_id` the implementer reported."* Here it does **not**: `@-` is the
checklist commit, `result.change_id` is its parent. Read literally, §4.3 now requires me
to send the repair prompt — telling the implementer its "repository shape is not valid
for review" and to re-emit with one produced change.

But that would be wrong, because **§5 explicitly anticipates this exact commit**:
*"You MUST confirm the step's checklist item in `plan_file` is marked complete.
`task-to-code` normally does this after the step's last task; if it did not, mark it
yourself."* The implementer did precisely what §5 says it normally does, disclosed it in
`result.yaml`'s `notes` ("a follow-up docs change (nruknntk…) marks plan Step 1 complete
now that all three step-01 tasks are committed"), and got the semantics right — it
waited until the step's last task.

So the skill contains a contradiction: **§5 expects the last task of a step to produce a
second, non-implementation change, and §4.3/§Validation Posture treat any such change as
a shape error.** Nothing in §4.3, §4.4 or §4.6 mentions the possibility.

**Decision taken:** accept it. Treat the task's produced series as
`[sqnxwpnn, nruknntk]` — review the whole `base..@-` range (which §4.4's prompt asks for
anyway), describe the **oldest** (`sqnxwpnn`) with the approved `merge_request` per §4.6,
and bookmark the **newest** (`nruknntk`). The checklist flip is legitimately part of
completing step 1 and belongs in the step's PR.

**Confidence: moderate.** I am confident that sending a repair prompt would have been
wrong — it would ask the implementer to undo correct, skill-mandated work, and §5 would
then oblige me to redo it by hand. I am less sure the checklist commit belongs *inside
task 03's* bookmark rather than as a separate orchestrator-authored change after §5's
verification. Both are defensible; the skill specifies neither.

**This is the clearest single candidate for `awo check` in the run.** A deterministic
validator would have to encode the rule "on the last task of a step, `@-` may be a
`plan.md`-only checklist commit whose parent is `result.change_id`" — and would
otherwise have hard-failed a correct run. It is also the one place where I most doubt an
orchestrator without a spec would make the same call twice.

Side observation: the implementer titled its implementation change
*"…[Compositional Analysis: Step 01/Task 03]"* — pre-emptively adopting the
merge-request title format that §4.6 has *me* apply from the review. Harmless
(§4.6 overwrites it), but it means the description §4.6 writes may be indistinguishable
from one the implementer invented, which weakens description-based auditing.

Deviation from the §4.4 template, recorded: I appended one clarifying paragraph to the
review prompt explaining the two-change series (implementation + checklist commit) and
that both are in scope. Without it the reviewer would have had to infer why
`current_change` is a `plan.md` edit. Not in the skill's template.

**Round 0 reviewer — result**

- Exit 0. Wall 22:07:59 → 22:10:29 = **2m30s**.
- stderr: `[acpx] tokens: input=501 output=65 cache_read=215552 total=216118`
- Topology unchanged ✓.
- Verdict: **`changes_requested`**. Six ACs this task: five pass, **AC4 partial**.
  One `important` finding.

**★ Strongest single evidence against reviewer drift.** On its *third* task, at 216k
accumulated context, after two consecutive approvals, the reviewer produced its most
technically demanding finding of the run:

> "The new test checks only that the error is non-nil and contains `accessing SDK root`
> plus the path. **It would remain green if either `%w` wrapper in
> `discoverStdlibWithContext` or `ValidateAndResolve` were changed to `%v`**, even
> though that would violate the criterion and prevent callers from recognizing
> `fs.ErrNotExist`."

That is a test-*integrity* argument — reasoning about what the test would fail to catch
under a hypothetical mutation, not about what it currently asserts. AC4 explicitly
requires the error to "wrap the stat failure"; the reviewer noticed the test verifies
the message but not the chain, and traced both `%w` layers
(`packagelayout.go:191-202` and `:510-517`) to show which mutation would slip through.
Its `suggested_action` names the precise fix (`errors.Is(err, fs.ErrNotExist)`, kept
routed through `ValidateAndResolve` to pin both layers).

No sign of softening, anchoring on tasks 01-02, or fatigue at 4× its starting context.

**Round 1 implementer (rework) — result**

- Exit 0. Wall 22:10:53 → 22:13:55 = **3m02s**.
- stderr: `[acpx] tokens: input=491 output=54 cache_read=72000 total=72545`
- Produced fresh child `sxqzlwnn 65d9000d` *test(packagelayout): assert absent-root
  error wraps the stat failure [Compositional Analysis: Step 01/Task 03 rework 1]*,
  touching only `packagelayout_test.go` — precisely the reviewer's `suggested_action`.
- No-rewrite check ✓: `sqnxwpnn bd16537e` and `nruknntk 9ba4a1a6` both unchanged.
- Output was the ```spec-workflow-meta``` block alone. Second implementer session in
  this run to show no re-orientation on rework (consistent with hypothesis 1).

### F-21 — `result.change_id` was corrupt, and §Validation Posture's tolerance rule does not cover it

`result.yaml` reported:

```yaml
change_id: sxqzlwnn65d9000d
```

That is the 8-char **change-id** prefix concatenated with the 8-char **commit-id**
prefix. It is not a valid revision:

```
$ jj log -r 'sxqzlwnn65d9000d'
Error: Revision `sxqzlwnn65d9000d` doesn't exist
```

The real change is `sxqzlwnntmmmyuuuusozqxowuyrsuwqt` / `65d9000d1fc75aec…`.

§Validation Posture's MUST-check is that `@-`'s change id "matches" `result.change_id` —
this fails. Its tolerance list covers "extra keys, missing optional fields, loose
formatting", and explicitly names the change ID as something you *need* from the
artifact, so a corrupt one is not obviously tolerable. Its MUST-NOT-tolerate clause
covers only the **verdict**.

**Decision taken:** accepted without a repair prompt. Both halves of the malformed
string independently and unambiguously identify `@-` (change prefix `sxqzlwnn`, commit
prefix `65d9000d`), no other change shares either prefix, and the produced change was
verified correct by direct `jj log` inspection. Sending a repair round to fix a string
in a YAML file would have burned a rework round for zero change in the code.

**Confidence: high** that accepting was right here. But this is squarely a case the
`awo` binary would have caught deterministically and repair-prompted, and where a
less careful orchestrator would either have failed the task or — worse — silently
recorded the bogus id into `produced_changes`, corrupting the series that §E.3
escalation handling depends on. **Candidate for `awo check`.**

### F-20 follow-up — user decision

The user, seeing F-20, decided to **move checklist ticking out of the implementer skills
into the orchestrator, as a separate commit**, motivated additionally by wanting task
tracking to move to an external system (e.g. beads) later.

This resolves F-20 completely and cleanly:

- §Validation Posture's `@- == result.change_id` invariant becomes **unconditionally
  true**. The contradiction between §5 and §4.3 disappears rather than needing a
  special case, so `awo check` needs no last-task exception.
- The checklist commit gets its own identity and bookmark (e.g.
  `pr/{slug}-step{NN}-complete`) instead of being smuggled into the last task's PR —
  which also settles the point I was only moderately confident about above.
- Ordering is unambiguous: it lands after the last task's approval, above that task's
  bookmark.
- For an external tracker it collapses N implementer-skill integration points into one
  orchestrator-owned one.

One consequence worth designing for: today the implementer's tick is what makes a
partially-run plan self-describing if the orchestrator dies. Once the orchestrator owns
it, a crash between the last task's approval and the checklist commit leaves `plan.md`
understating progress. §Parameters already requires deriving the next step from the
checklist **and** `work_log` together, and `work_log` is the more reliable of the two,
so the existing contract already covers this — but it becomes load-bearing rather than
belt-and-braces.

**Round 1 reviewer (re-review) — result**

- Exit 0. Wall 22:14:36 → 22:16:31 = **1m55s**.
- stderr: `[acpx] tokens: input=364 output=112 cache_read=36224 total=36700`
- Topology unchanged ✓.
- Verdict: **`approved`**, all six ACs pass, `findings: []`.

It verified the fix rather than accepting it, and did so through the strongest available
evidence — the implementer had run an actual **mutation test**, and the reviewer cited
it: *"The `%w`-to-`%v` mutation run at work.log:313-320 fails this assertion, followed by
a green restored test at work.log:321-325, directly resolving the prior review finding
and former partial criterion."* It also still referred to "the prior review finding and
former partial criterion" without being reminded of them.

### F-22 — unexplained: the reviewer's reported context dropped ~6× between rounds

| Reviewer turn | `input` | `cache_read` | sum |
|---|---|---|---|
| task 01 r0 | 459 | 53 376 | ~53.8k |
| task 01 r1 | 2 280 | 86 144 | ~88.4k |
| task 01 r2 | 554 | 123 264 | ~123.8k |
| task 02 r0 | 518 | 159 232 | ~159.8k |
| task 03 r0 | 501 | 215 552 | ~216.1k |
| task 03 r1 | 364 | **36 224** | **~36.6k** |

The final turn reports ~36.6k where the trend predicted ~250k. `input` stayed tiny, so
this is not "cache expired and the context was re-sent uncached" — on that reading
`input` would be enormous. Two candidate explanations, and **I cannot distinguish them
from the data I have**:

1. The codex session compacted/truncated its history between the two task-03 turns,
   genuinely discarding ~180k of context.
2. The token line's accounting changes in some way I do not understand (consistent with
   F-11's finding that these fields are per-call and not straightforwardly additive).

What is *not* in doubt is the **behaviour**: on that same turn the reviewer correctly
recalled its own prior finding, referenced the former partial criterion, and validated
the mutation evidence. So if compaction did occur, it preserved the salient content.

I am flagging this rather than resolving it because it bears directly on the
step-scoped-reviewer hypothesis: if long reviewer sessions silently compact, the claimed
benefit (continuity across tasks) has a horizon nobody is currently measuring, and the
skill's prescribed instrument cannot see it. **Determining which explanation is correct
requires the acpx wire log** (`~/.acpx/sessions/01a06565-….stream.ndjson`) — recommended
follow-up, not attempted here.

### §4.6 Finalize task 03

`jj describe sqnxwpnn` with the approved `merge_request` (`Rebased 3 descendant
commits`), bookmark
`pr/…/step01/task-03-harden-host-path-groundwork.code-task` created on the newest
produced change `sxqzlwnn`. Implementer session closed.

Note the checklist commit `nruknntk` now sits **between** the two implementation changes
of task 03 (`sqnxwpnn` → `nruknntk` → `sxqzlwnn`), because §4.5 required the rework to
land on top of the then-current tip. That is an odd-looking series for a PR, and is a
further argument for the user's decision to move checklist ticking to the orchestrator.

---

## §5 — Step 1 close-out

- All three tasks **approved**. ✓
- Reviewer session `awo-rev-…-step01` closed. ✓
- Plan checklist item verified marked complete:
  `- [x] **Step 1** — Baseline measurement and low-risk groundwork` ✓
  (done by the task-03 implementer in `nruknntk`, per §5's expectation; see F-20.)
- `@` empty, on top of the stack. ✓

### Final step-1 topology

```
tsrqnsrz  (empty)  @
sxqzlwnn  test(packagelayout): assert absent-root error wraps the stat failure
          └─ pr/{slug}/step01/task-03-harden-host-path-groundwork.code-task
nruknntk  docs(plan): mark compositional analysis step 1 complete
sqnxwpnn  fix(host): canonicalize parity paths and guard SDK roots
kpvyvmlt  fix(bazel): provide empty aspect provider for non-Go targets
          └─ pr/{slug}/step01/task-02-propagate-empty-provider-for-non-go-targets.code-task
rwkmsxzw  docs(research): reconcile harness wall readings and wall reduction projection
          └─ pr/{slug}/step01/task-01-measure-current-analysis-phases.code-task
qrootkqv  docs(research): correct member CPU attribution and redesign projection
urmzqoqo  docs(research): measure and reconcile analysis phase costs
knzzromy  docs(tasks): define compositional analysis step 1
          └─ pr/awo-generate-task-{slug}-step-1
```

**Stopped here as instructed. Step 2 not started.**

### Independent verification

Orchestrator ran `just ci` on the final combined stack: **exit 0**, 81/81 Bazel tests
pass, both shell validation tests OK, `@` clean. The step's "Integration: `just ci`
stays green" claim holds on the assembled series, not just per-task.

---

# Consolidated evaluation

## Timing and token data (all 15 agent turns)

| # | Turn | Wall | Verdict/status | `cache_read` |
|---|---|---|---|---|
| 1 | gen (codex) | 5m00s | 3 task files | 78 464 |
| 2 | t01 impl r0 | **15m13s** | completed | 82 624 |
| 3 | t01 rev r0 | 2m16s | changes_requested (2 imp) | 53 376 |
| 4 | t01 impl r1 | 2m56s | completed | 94 656 |
| 5 | t01 rev r1 | 1m30s | changes_requested (2 imp) | 86 144 |
| 6 | t01 impl r2 | 2m07s | completed | 102 208 |
| 7 | t01 rev r2 | 1m43s | **approved** (1 sugg) | 123 264 |
| 8 | t02 impl r0 (a1) | ~2m | **KILLED** | — |
| 9 | t02 impl r0 (a2) | 5m55s | completed | 51 968 |
| 10 | t02 rev r0 | 1m13s | **approved** (0) | 159 232 |
| 11 | t03 impl r0 | 9m20s | completed (2 changes) | 65 920 |
| 12 | t03 rev r0 | 2m30s | changes_requested (1 imp) | 215 552 |
| 13 | t03 impl r1 | 3m02s | completed | 72 000 |
| 14 | t03 rev r1 | 1m55s | **approved** (0) | 36 224 |

Implementer turns: 38m33s over 6 completed turns. Reviewer turns: 11m07s over 6 turns.
Total agent wall clock ≈ **55m** (excluding the killed attempt and orchestration).

## Hypothesis 1 — task-scoped implementer: **SUPPORTED**

Two independent tasks, three rework rounds total, and the implementer never once
behaved as though it had forgotten the task. Evidence, strongest first:

1. **Task 01 r1 reconstructed deleted tooling.** The §4.5 prompt named only a review
   path. To answer the finding, the implementer had to rebuild the member-only
   measurement harness it had built *and deliberately removed* in r0 (AC4 forbids
   leaving instrumentation). It did so without being told the harness existed, what it
   measured, or that `go list -export` was inside the measured region.
2. **It tracked reviewer state across rounds** — r1's `result.yaml` says of AC1
   "unchanged this round, review marked it pass", distinguishing criteria to fix from
   criteria to preserve.
3. **Narration collapsed to nothing.** r0 opened with "Scratchpad setup, then explore
   the check path call sites"; r1 was one sentence of work; r2 and task-03 r1 emitted
   only the ```spec-workflow-meta``` block. No re-orientation, no re-reading the task.
4. **Rework rounds were 5.2× and 3.1× faster than their round 0** (2m56s / 2m07s vs
   15m13s; 3m02s vs 9m20s) on work that was not obviously cheaper — task 01 r1 ran a
   fresh CPU measurement campaign, task 03 r1 ran a mutation test.

**Limits.** Max 2 rework rounds observed on one task. Nothing here says whether
retention survives 4 rounds, a long gap, or a compaction event (cf. F-22 on the
reviewer side). And the killed turn showed that a session can be lost entirely, with
no orchestrator-executable recovery path in the skill as written.

## Hypothesis 2 — step-scoped reviewer: **SUPPORTED, with one unresolved caveat**

Six review turns in one session across three tasks. No degradation observed.

**Continuity actually paid off** — the property a per-task reviewer cannot have:
- Task 01 r1 scored the rework against its own findings *by name*: "addressing the
  first half of the prior finding", "resolving those parts of the prior finding".
  Partial credit requires holding the prior review.
- Task 03 r1 referenced "the prior review finding and former partial criterion"
  unprompted; the §4.4 re-review template deliberately does not restate them.

**It did not go soft.** The two zero-finding approvals were checked specifically for
this:
- Task 02's approval cites `file:line` for every AC, verifies "Go traversal unchanged"
  by reading the diff rather than trusting the implementer, and separates RED from
  GREEN evidence. The task is a genuine ~6-line change.
- Its hardest finding of the whole run came on its **third** task at 216k context,
  after two consecutive approvals: a mutation-style argument that the new test "would
  remain green if either `%w` wrapper … were changed to `%v`". That is reasoning about
  what a test fails to catch — the opposite of fatigue.
- Even the task-01 approval was not clean: it still filed a `suggestion` and argued why
  it did not invalidate the conclusion. Severity discrimination held throughout.
- Twice it reported that its **own** `just ci` / Bazel rerun failed on a sandbox cache
  permission and explicitly declined to hold that against the change.

**No anchoring on earlier tasks** was observed: task 02's review is about Starlark
providers, task 03's about Go error wrapping, with no bleed from task 01's measurement
arithmetic.

**Caveat (F-22).** Reported context grew ~linearly to 216k and then dropped to ~36.6k
on the final turn. Either the session compacted (discarding ~180k) or the accounting is
not what it appears. Behaviour was unimpaired on that turn, but **if long reviewer
sessions silently compact, the continuity benefit has an unmeasured horizon** — and the
skill's prescribed instrument cannot detect it. Unresolved; needs the wire log.

## Verdict on the prototype

Both hypotheses held on this step. The mechanism that broke was **neither** —
it was infrastructure (an external kill), and what made that expensive was that the
skill has no orchestrator-executable recovery path. Fix that and the prototype looks
worth adopting on this evidence.


---

# Post-run investigation: codex context window and auto-compaction

Read-only forensics on the codex rollout for the reviewer session.
Rollout: `~/.codex/sessions/2026/09/02/rollout-2026-09-02T21-08-56-01a06574-9f3a-7dd0-a211-3c8808620ba2.jsonl`
(codex nests by **local** date; acpx's `01a06565-…` is a wrapper id whose
`acp_session_id` is the codex id `01a06574-…`.)

## F-22 — RESOLVED. Auto-compaction, verified. Not an accounting artifact.

I flagged two candidate explanations and said I could not distinguish them.
**Explanation 1 was correct**; the accounting was never in doubt.

Verified in the rollout — exactly one compaction event in the whole session:

```
line 309  2026-09-03T05:15:24.419Z  "type":"compacted"   payload.replacement_history[11 items]
line 313  2026-09-03T05:15:24.424Z  "type":"event_msg"   payload.type = "context_compacted"
```

And codex's own per-call accounting matches the acpx `cache_read` line **exactly, to
the token, on all six turns** (53,376 / 86,144 / 123,264 / 159,232 / 215,552 / 36,224).
So acpx's token line was accurate throughout — my F-11 scepticism about *that* field
was misplaced, though the per-call-vs-per-turn point stands.

**Correction to my earlier framing:** I described the collapse as happening *between*
t03 r0 and t03 r1. It did not. It fired **mid-turn during t03 r1**, at 05:15:24Z,
after that turn's own model calls had pushed usage to **225,696 / 258,400 tokens
(87.3%)**. The turn then completed on the compacted history — which is why it still
produced a correct, well-evidenced approval that recalled the prior finding: the
compaction summary preserved the salient content.

## Context window: 258,400, not 200k and not 1M

From `~/.codex/models_cache.json`, entry `gpt-5.6-sol`:

```
"context_window": 272000,  "max_context_window": 872000,
"effective_context_window_percent": 95
```

272,000 × 0.95 = **258,400** — matching `"model_context_window":258400` on all 60
`token_count` events in the rollout. `~/.codex/config.toml` sets **no**
`model_context_window` or `model_auto_compact_token_limit`, so this comes from codex's
server-fetched catalog. Note codex also knows a `max_context_window` of 872,000 that it
is not using.

The compaction trigger fired at 87.3% of 258,400. No literal threshold constant was
found locally; the percentage is observed, not verified as a configured rule.

## Raising it (verified mechanisms; NOT applied)

- **`~/.codex/config.toml`** — `model_context_window`, `model_auto_compact_token_limit`
  and `model_auto_compact_token_limit_scope` are real config keys (confirmed by
  `strings` on the exact codex binary that ran this session, `codex-cli 0.144.0`). Read
  by `codex app-server` on startup regardless of launcher, so it works through acpx.
- **`CODEX_CONFIG` env var** — documented in codex-acp's README and traced through
  `dist/index.js`: parsed and passed verbatim as the `config` field of the
  `threadStart` RPC.
- **Does NOT work: `~/.acpx/config.json` `agents.codex`** — acpx's agent schema accepts
  only `command` and `args`, with no `env` field; and `codex-acp` ignores unrecognised
  argv and spawns the inner codex binary with a hardcoded `app-server` invocation, so
  there is no `-c` passthrough. Plain `codex` supports `-c key=value`; `codex-acp`
  does not expose it.

## ★ F-23 — session config silently reverts on adapter respawn (NEW, and it invalidates a claim in my report)

The rollout's `turn_context` entries show the reviewer's reasoning effort over time:

| line | timestamp | effort | turn |
|---|---|---|---|
| 8 | 04:08:57Z | **medium** | t01 r0 |
| 82 | 04:14:55Z | **medium** | t01 r1 |
| 124 | 04:19:14Z | **medium** | t01 r2 |
| 176 | 04:55:32Z | **high** | t02 r0 |
| 225 | 05:08:00Z | **high** | t03 r0 |
| 297 | 05:14:36Z | **high** | t03 r1 |

I set `reasoning_effort medium` once at session creation and acpx confirmed
`config set: reasoning_effort=medium (4 options)`. It held for task 01 and then
**silently reverted to `high`** — the value in `~/.codex/config.toml`
(`model_reasoning_effort = "high"`).

Mechanism (inferred, but the evidence fits tightly): acpx's `ttl` is 300s. Between
t01 r2 (ended 04:20:57Z) and t02 r0 (started 04:55:30Z) the reviewer sat idle ~34
minutes, far past the TTL, so its adapter process was reaped and respawned on the next
prompt — re-reading `config.toml` and losing the session-scoped override. The acpx
record corroborates repeated respawns: `agent_started_at: 2026-09-03T05:07:59Z`
(i.e. task 03 r0) on a session `created_at: 03:52:40Z`, with `last_request_id: 3`.

**The conversation survived** — continuity was demonstrably intact across the gap
(task 02's review, and task 03 r1 recalling its prior finding). Only the *config*
was lost.

### Consequences

1. **§Sessions' model/effort contract is not durable.** The skill says to set the model
   before the first prompt and confirm the echo, treating that as settled for the
   session's life. It is not: any session that idles past the TTL silently reverts to
   the harness's global defaults on its next turn. For a *step-scoped* session, which
   by design sits idle while the implementer works, this is close to guaranteed.
   The skill's own warning — "A silently defaulted model invalidates the experiment" —
   describes exactly what happened, and its prescribed check cannot catch it.
   **Fix: re-assert and re-verify model and effort with `status -s` before every turn,
   not once per session.** This is the second `awo check` candidate of real substance.
2. **My no-drift conclusion is confounded, and I am correcting it.** I reported the
   reviewer as "codex / gpt-5.6-sol / medium" throughout, and argued its quality held
   up — citing as strongest evidence that its hardest finding came on task 03. But
   task 01 ran at **medium** and tasks 02-03 at **high**. Effort rose at exactly the
   point context grew large. So "quality held despite context growth" is not something
   this run establishes: the two variables moved together, in the direction that
   flatters the hypothesis.

   What survives the correction: the reviewer did not *degrade*, and the intra-task
   continuity evidence (partial credit against its own prior findings) is unaffected by
   effort level. What does not survive: any claim that context growth alone was
   harmless.

## Bearing on reviewer session scope

The user's suggestion — scope the reviewer per task, like the implementer — is
**supported by this evidence**, on three independent grounds:

1. **The step-scoped reviewer hit the ceiling on a 3-task step.** 258,400 is not
   generous, and this step was small: three tasks, six review turns, one of them
   already compacting. A 5- or 6-task step would compact repeatedly and mid-turn.
2. **The compaction is invisible to the orchestrator.** Nothing in acpx's stdout,
   stderr token line, or exit code reports it. Only the codex rollout does. So the
   skill's degradation-watch instruction ("record the token line at that point") cannot
   see the event it most needs to see.
3. **Every continuity benefit observed in this run was intra-task.** Both concrete
   payoffs — "addressing the first half of the prior finding" (t01 r1) and "the prior
   review finding and former partial criterion" (t03 r1) — were partial credit across
   *rework rounds of the same task*. No finding in tasks 02 or 03 depended on having
   reviewed task 01. Task-scoping preserves 100% of the demonstrated value and
   surrenders only a hypothesised one.

A task-scoped reviewer in this run would have peaked near 123k (task 01's three turns)
instead of 225k, well clear of the trigger, with no compaction anywhere.

**Caveats worth keeping:** three tasks is a thin sample, and Step 1's tasks were
unusually independent (a research note, a Bazel aspect fix, a path-canonicalisation
fix), so this step could not have exhibited cross-task drift even if the mechanism
works. If cross-cutting review is the goal, `implementation-review` already targets it
with clean context after the last task, which is a better-shaped tool than relying on a
reviewer session that happens to still remember.

Raising `model_context_window` to 1,000,000 / `model_auto_compact_token_limit` to
900,000 would defer the cliff and make it predictable, but does not remove it;
task-scoping removes it structurally. The two are complementary — raising the window is
worth doing regardless, since it also protects long *implementer* sessions.


---

# Proposed redesign (user, post-run): task-scoped reviewer + per-step implementation-review

**User's design:** narrow the reviewer session to a task (spanning its rework rounds,
like the implementer); compensate for lost cross-task reasoning by running
`implementation-review` in a fresh session at the end of each step; move the task
reviewer to a lighter model (terra, or luna at max), keeping Sol (high/medium) for the
step-level review.

## Verified: model choice does not move the compaction cliff

All codex models in `~/.codex/models_cache.json` report the **same** window:

| slug | context_window | max_context_window | effective (95%) |
|---|---|---|---|
| gpt-5.6-sol | 272,000 | 872,000 | **258,400** |
| gpt-5.6-terra | 272,000 | 872,000 | **258,400** |
| gpt-5.6-luna | 272,000 | 872,000 | **258,400** |
| gpt-5.4 | 272,000 | 1,000,000 | 258,400 |

So switching the task reviewer to terra or luna changes cost and capability but leaves
the 258,400 ceiling and the ~87% auto-compact trigger exactly where they are. The
compaction fix is **session scoping** (and/or raising `model_context_window`), not model
selection. The two decisions are orthogonal and should be argued separately.

## ★ F-23 has a sharper edge under a mixed-model design

`~/.codex/config.toml` currently pins:

```toml
model = "gpt-5.6-sol"
model_reasoning_effort = "high"
```

F-23 established that a session's per-session config is lost when the adapter is reaped
at the 300s idle TTL and respawned. In this run that cost us *effort* (medium → high).
Under a design that deliberately runs the task reviewer on a **cheaper** model, the same
mechanism silently reverts the **model** to `gpt-5.6-sol` at `high` — i.e. the run
quietly becomes the expensive configuration, while the work log, cost model and any
model comparison all still say "terra".

This is strictly worse than what we observed, because it is unobservable from acpx
(the `model set:` echo happened correctly at session creation; nothing re-reports it)
and it inverts the very economics the change is meant to achieve.

**Is the task reviewer actually exposed?** Yes. Observed reviewer idle gaps *within* a
task, i.e. the implementer's rework time:

| gap | duration | vs 300s TTL |
|---|---|---|
| t01 rev r0 → r1 | 2m50s | under |
| t01 rev r1 → r2 | 2m50s | under |
| t03 rev r0 → r1 | 4m07s (247s) | **under, but only just** |

Every observed gap was under the TTL, but t03's was within 53 seconds of it, and
implementer rounds in this run ranged 2m07s–15m13s. A task with a slower rework round
crosses the TTL routinely.

**Mitigations, in order of robustness:**
1. **Re-assert and re-verify `set model` + `set reasoning_effort` before every turn,
   confirming with `status -s` (which reports the *resolved* model), not the
   `set` echo.** Robust regardless of TTL, respawn, or config drift. This should
   replace §Sessions' once-per-session contract outright.
2. Raise acpx `ttl` so adapters outlive normal implementer rounds. Reduces the window
   but does not close it, and conflicts with §Sessions' own concern about leaking
   adapter processes across a long run.
3. Set the intended task-reviewer model as the `config.toml` default so a revert is a
   no-op. Fragile: it just moves which configuration is silently assumed.

## Open question the redesign must answer: what happens to implementation-review's output

`implementation-review` is specified as a **plan-level** pass — its own description says
it reviews "the full implementation of a plan once all its steps are complete" and is
"designed to run with clean context after the last task in the plan is committed".
Running it per step is a repurposing, and a reasonable one, but it emits
"a set of follow-on remediation `.code-task.md` files that re-enter the existing
pipeline". At plan level those are terminal deliverables. At **step** level the
orchestrator must decide something the current skill has no rule for:

- Are remediation tasks implemented before advancing to the next step (extending the
  step, and possibly re-triggering the step review)?
- Or queued and folded into a later step?
- Does the step's checklist item get ticked before or after they are resolved?
- If they are implemented, do they get their own bookmarks under the step's namespace,
  and does the step review run again on the result (and if so, what stops it looping)?

Whichever answer, it needs a loop guard — this is the same class of hazard as
`max_rework_rounds`, one level up.

Also worth deciding: whether a plan-level `implementation-review` still runs at the end.
Probably yes, but it will re-derive findings the per-step passes already raised, so the
per-step residue should be an input to it.

## What must not be lost

The demonstrated value of reviewer continuity in this run was **entirely intra-task** —
partial credit against its own prior findings across rework rounds. So "task-scoped"
must mean *spans the task and all its rework rounds*, exactly as the implementer does.
If it were narrowed further, to per-round, the run would lose the only reviewer-side
benefit it actually evidenced.

## On the lighter model — what this run does and does not support

Supports it, weakly but genuinely: the reviewer's two hardest findings landed one at
each effort level — the mixed-denominator arithmetic critique (task 01 r0) came at
**medium**, the `%w`→`%v` mutation-integrity finding (task 03 r0) at **high**. Medium
was already producing top-tier work.

Does **not** support any claim about terra or luna: neither was run here. This run
provides no evidence on their review quality, and the F-23 revert risk means a naive
A/B would be silently contaminated. Any comparison must verify the resolved model per
turn (mitigation 1 above) before its results mean anything.


---

# Changes made as a result of this run

All committed. Skills in `ono-sendai-labs/agent-skills` as `sttoxozs cfbee2a4`;
role config in this repo as `tsrqnsrz 697b9431`.

## 1. codex context window raised — `~/.codex/config.toml`

```toml
model_context_window = 500000
model_auto_compact_token_limit = 450000
```

Backup: `~/.codex/config.toml.bak-20260902-225758`.

Chosen as 500k rather than the circulating 1M suggestion because
`max_context_window` for `gpt-5.6-{sol,terra,luna}` is **872,000**, not 1,000,000 —
a 1M setting would exceed the models' declared ceiling. 500k sits comfortably inside it
while nearly doubling the 258,400 default. `model_auto_compact_token_limit` is pinned at
90% so the trigger point is explicit rather than inherited.

Caveat recorded: this is global and changes interactive codex behaviour too, and longer
contexts cost more per turn. It defers the compaction cliff; it does not remove it.

## 2. Reviewer session scope: step → task (`awo-acpx`)

Session naming is now `awo-rev-{slug}-step{NN}-task{MM}`, opened and closed per task,
reused across that task's rework rounds. §3 no longer opens a step reviewer; it records
the task inventory and resolved roles instead. §4.4 always carries the non-interactive
preamble (every task's reviewer is new). §4.6 closes both sessions.

## 3. Model/effort re-asserted before every prompt (`awo-acpx` §Sessions)

New "Asserting the model and effort" subsection replacing the once-per-session contract,
requiring `status -s` verification of the *resolved* model and stop-and-ask on mismatch,
with F-23's evidence inline. Rejected alternative, recorded in §Troubleshooting: pinning
the intended model as the harness's global default — it changes interactive behaviour and
merely moves which silent default is being relied on.

## 4. Role configuration file (`awo-acpx` §Role Configuration)

Four roles — `task_generator`, `implementer`, `reviewer`, `step_reviewer` — read from
`.agents/awo/acpx-config.yaml`, precedence *explicit parameter > file > defaults*, with
the resolved values required in `work_log` before the first turn.

Defaults: generator and step reviewer on `gpt-5.6-sol`/high; task reviewer on the
lighter `gpt-5.6-terra`/high; implementer on opencode with no effort set.

This also fixed a latent bug: §2 previously said to generate tasks with "the reviewer
agent and model (task generation benefits from the more capable model)" — which stops
being true the moment the task reviewer becomes the *lighter* model. The generator now
has its own role.

Note verified during this design: **model choice does not move the compaction cliff.**
sol, terra and luna all report `context_window: 272000` / `effective 258400`. Model
selection and session scoping are independent decisions.

## 5. Step-scoped implementation review (`awo-acpx` §5.2, `implementation-review` `scope`)

`implementation-review` gained a `scope` parameter (`step` | `plan`) rather than a new
skill — the analysis is identical, only the input set and output location differ, and a
sibling skill would have duplicated ~240 lines and drifted.

At `step` scope it: reviews one step, writes `review-step{NN}.yaml`, appends remediation
tasks to **that step's own** directory (continuing its `task-{MM}-` numbering, capped at
3), does **not** touch `plan.md`, and does **not** require the step's checklist item to
be ticked — under the new contract the orchestrator ticks it afterwards, so unticked is
the expected state. It must not flag work the plan defers to a later step.

At `plan` scope it now consumes prior step reports: a finding already raised and
remediated must not be re-reported; one raised and still unaddressed is re-reported at
one severity higher, citing the earlier report.

The orchestrator side (§5.2) runs it in a fresh session with the `step_reviewer` role,
routes on verdict, runs any remediation tasks through §4 as ordinary tasks of the step,
and stops after `max_step_remediation_rounds` (default 1) — repeated remediation on one
step means the step was mis-planned, which is the user's call.

## 6. Orchestrator owns plan progress (`task-to-code`, `awo-acpx` §5.3, `awo-orchestrator`)

`task-to-code` no longer ticks checklist items; both orchestrators do it themselves in a
commit containing only the checklist edit, bookmarked
`pr/awo-step-complete-{slug}-step-{N}`. Resolves F-20 structurally: `@- == result.change_id`
now holds unconditionally, so `awo check` needs no last-task exception.

## 7. Killed-turn recovery (`awo-acpx` §Recovering from a killed turn)

The predicate agreed with the user, plus evidence capture, a one-recovery-per-round loop
guard, and the rule that a killed turn does not consume a `max_rework_rounds` slot.
§Operating Constraints' blanket `jj abandon` ban now carries this explicit exception, and
notes that abandon is recoverable in jj via the operation log.

## 8. Correctness fixes carried into the skill

F-07 (`status` needs `-s`), F-08 (base ancestry not identity; dangling §3.1 reference
removed), F-10 (`--format quiet` does not isolate the final message; use `--format json`
for prose routing), F-11/F-16 (how to read the token line: `input`/`output` per call,
`cache_read` per session, never compare across agents), F-14 (change-id prefix
containment; never compare commit ids), F-15 (pre-review topology snapshot), F-17
(§4.6's `jj describe` is the sanctioned amend exception), F-19 (the always-on
`.stream.ndjson` wire log is the black box), F-21 (tolerate a malformed but unambiguous
`result.change_id`, but write the real one into `produced_changes`), plus the
compaction-detection and degradation-detection guidance in §Troubleshooting.

## Orchestrator error during this session, recorded

While committing the skill changes I passed a commit message containing backticks inside
a double-quoted shell string. Bash command-substituted them, the message was mangled, jj
opened an editor with no terminal, and a stray `jj abandon` from the mangled fragment
discarded the working copy holding all four edited files. Recovered in full with
`jj op restore 50ebf27809e9` and re-committed with the message supplied via
`--stdin` from a file.

Two things this validates: jj's operation log makes abandonment genuinely recoverable
(the premise behind narrowing the `jj abandon` prohibition in §7 above), and commit
messages containing backticks — which any message describing shell commands or code
identifiers will — must never be passed through a double-quoted shell argument.
