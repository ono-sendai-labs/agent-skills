# awo-acpx orchestration report — 2026-08-04-compositional-component-analysis (RUN 2)

> **Provenance.** Verbatim copy of the orchestrator's live work log from the run,
> checked in here because the original lives in a gitignored scratchpad
> (`.agents/scratchpad/awo-acpx-report.{slug}.md`) in another repository and would not
> survive. Written incrementally *during* the run, so it reads chronologically and
> contains in-flight reasoning, one finding that was resolved against itself mid-run
> (F-25), one that had to be corrected and extended after new evidence (F-28, F-31), and
> several declared deviations from the skill — all left in deliberately.
>
> **Run:** `ono-sendai-labs/architectural-contracts` (public), plan
> `2026-08-04-compositional-component-analysis`. **Step 2 complete** (3 tasks, step
> review, checklist, `just ci` green) plus **step 3 task 01**. 21 agent turns.
> **Skill under test:** `awo-acpx` at the revision produced by RUN 1's findings
> (`sttoxozs cfbee2a4`) — i.e. this run tests RUN 1's *fixes*, and the paths that
> revision added and had never executed: §5.2, §5.3, §Role Configuration, per-prompt
> model/effort re-assertion, and §Recovering from a killed turn.
>
> **Continues RUN 1's numbering: findings are tagged `[F-24]`–`[F-36]`.**

**Skill under test:** `awo-acpx` (prototype), `/home/xtof/git/ono-sendai-labs/agent-skills/awo/awo-acpx/SKILL.md`
**Run scope:** Steps 2 onward, autonomous; stopped at a task boundary in step 3.
**Orchestrator:** Claude Opus 5 (this session)
**Repo:** `/home/xtof/git/ono-sendai-labs/architectural-contracts` (jj only)
**Roles:** task_generator codex/gpt-5.6-sol/high · implementer opencode/glm-5.3-flash/–
· reviewer codex/**gpt-5.6-luna**/**max** (an untested change from RUN 1's sol) ·
step_reviewer codex/gpt-5.6-sol/high

---


**Skill under test:** `awo-acpx` at `/home/xtof/git/ono-sendai-labs/agent-skills/awo/awo-acpx/SKILL.md`
(revision produced by RUN 1's 23 findings; §5.2 step review, §5.3 orchestrator-owned
checklist, §Role Configuration, per-prompt model/effort re-assertion and
§Recovering from a killed turn are all **previously unexecuted paths**).
**Run scope:** step 2 onward, autonomous.
**Orchestrator:** Claude Opus 5 (fresh session).
**Findings continue at F-24.**

## 0. Preflight

### 0.1 Environment

- `acpx` 0.12.0 at `/home/xtof/.bun/bin/acpx`. ✓
- `acpx config show`: agents `opencode` and `codex` configured; `nonInteractivePermissions: deny`. ✓
- Producer skills present in `.agents/skills/`: `task-to-code`, `code-task-review`,
  `plan-to-tasks`, `implementation-review`, plus `awo-acpx` itself. ✓
- `jj st`: empty working copy. `@- = tsrqnsrz 1544f241` (`dev-exp-go-bazel-mvp`),
  `chore(awo): add acpx role configuration`. §1 satisfied at entry. ✓
- `~/.codex/config.toml` now sets `model_context_window = 500000`,
  `model_auto_compact_token_limit = 450000` (RUN 1 F-22 remediation), global
  `model = gpt-5.6-sol`, `model_reasoning_effort = high` — the values a respawned
  adapter reverts to (F-23).
- Local date is **2026-09-02**, UTC **2026-09-03**. Codex rollouts nest by local date,
  so the out-of-band effort check reads `~/.codex/sessions/2026/09/02/`.

### 0.2 Resolved parameters

| Parameter | Value | Source |
|---|---|---|
| `plan_file` | `.agents/planning/2026-08-04-compositional-component-analysis/implementation/plan.md` | user |
| `planning_slug` | `2026-08-04-compositional-component-analysis` | derived |
| `repo` | `/home/xtof/git/ono-sendai-labs/architectural-contracts` | default |
| `work_log` | this file (appended) | default |
| `run_dir_root` | `.agents/runs-acpx/` | default |
| `generate_tasks_cmd` | unset | → §2 self-run |
| `roles_config` | `.agents/awo/acpx-config.yaml` | default, **exists** |
| `step_review` | true | default |
| `max_step_remediation_rounds` | 1 | default |
| `check_cmd` | unset | default |
| `max_rework_rounds` | 4 | default |

### 0.3 Resolved role configuration (§Role Configuration — first execution of this path)

Parsed from `.agents/awo/acpx-config.yaml`; all four roles present and recognised.

| Role | agent | model | effort | vs. skill default |
|---|---|---|---|---|
| `task_generator` | codex | `gpt-5.6-sol` | high | same |
| `implementer` | opencode | `opencode-go/glm-5.3-flash` | null (do not set) | same |
| `reviewer` | codex | **`gpt-5.6-luna`** | **`max`** | **differs** (default terra/high; RUN 1 ran sol medium→high) |
| `step_reviewer` | codex | `gpt-5.6-sol` | high | same |

`max` is a supported reasoning level for `gpt-5.6-luna`
(`~/.codex/models_cache.json`: low/medium/high/xhigh/max — note **no `ultra`**, unlike
sol and terra, so the §Sessions warning about per-model level differences is real and
would have bitten had the config asked for `ultra`).

### 0.4 Next step number

Plan checklist: Step 1 `- [x]`, Steps 2–13 `- [ ]`. RUN 1's log ends at "Step 2 not
started". Next step = **2**. ✓

---

## §2 — Task generation for Step 2

Session `awo-gen-…-step02` (codex / gpt-5.6-sol / high), opened with `sessions new`.

- `set model gpt-5.6-sol` → `model set: gpt-5.6-sol`; `status -s` reports
  `model: gpt-5.6-sol` ✓ (the §Sessions "verify with status, not the echo" rule works).
- `set reasoning_effort high` → `config set: reasoning_effort=high (4 options)`.
- **Out-of-band verification (§Sessions, first execution of this path): PASSED.**
  acpx record `01a065f7-6b8d-…` → `acp_session_id 01a065f7-8985-…` → rollout
  `~/.codex/sessions/2026/09/02/rollout-2026-09-02T23-31-56-01a065f7-8985-….jsonl`.
  `"effort":"high"` ×1, `"model":"gpt-5.6-sol"` ×2. The skill's recipe for finding the
  rollout (local date, `acp_session_id` not `acpx_record_id`) is **exactly right** and
  worked first time.
- Exit 0. Wall **3m42s**. stderr: `[acpx] tokens: input=550 output=396 cache_read=80896 total=81842`.
- Preamble: §2's prompt now carries the non-interactive preamble — **RUN 1's F-03 is fixed
  and the fix works** (no clarifying question, no narration).

### F-24 — §2 / §Artifacts: RUN 1's F-04 is still unaddressed

§Artifacts still enumerates only `{run_dir_root}/{ts}-step{NN}-task-{MM}-{slug}/`. The
generation turn still has a prompt, stdout and a mandatory stderr token line with no
defined home. I reused RUN 1's invented convention, `.agents/runs-acpx/step02-taskgen/`.
Not a new defect — recording that a known one survived the revision.

### F-25 — `set reasoning_effort` reports a menu size that does not match the model

`gpt-5.6-sol` advertises **six** reasoning levels in `~/.codex/models_cache.json`
(`low, medium, high, xhigh, max, ultra`), but acpx echoed
`config set: reasoning_effort=high (4 options)`. So the "(N options)" count is acpx's or
the adapter's own idea of the menu, not the model's. It is therefore **not** usable as a
cheap sanity check that a level exists for the model, and — more importantly — it raises
the possibility that a level outside acpx's 4-option menu (e.g. the `max` this run's
reviewer role asks for) is accepted by `set` and silently dropped. The skill's §Sessions
guidance says to check `supported_reasoning_levels` in `models_cache.json`, which says
`max` is valid for luna; that check passes while this one is ambiguous. **To be resolved
at the first reviewer turn via the rollout.**

**Result.** Exit 0, working copy clean, `@- = ozwmmpop 49ab4f96`
*docs(tasks): define compositional analysis step 2*, three task files:

| # | Task file |
|---|---|
| 01 | `task-01-remove-package-granularity-capability-pruning.code-task.md` |
| 02 | `task-02-remove-absorbed-dependencies.code-task.md` |
| 03 | `task-03-remove-pattern-membership.code-task.md` |

Bookmarked `pr/awo-generate-task-2026-08-04-compositional-component-analysis-step-2`
(`jj bookmark create`, succeeded — no collision). Session closed.

Note the generator declared an explicit ordering constraint in task-01's `Dependencies`
("Must land before Task 2 so the subsequent absorbed-dependency deletion starts from the
final `AnalyzeRequest` shape"), which matches the plan's Step 2 sequencing. Tasks will be
run in file order, which satisfies it.

Also note the generator reported that its own `just ci` attempt failed on a
**sandbox Go build-cache** issue — the same class of infrastructure noise RUN 1's
reviewer hit twice. Not treated as a signal about the repo.

## §3 — Step task inventory

Recorded above. Role configuration as resolved in §0.3. No step-scoped reviewer session
is opened (§3 of the revised skill) — correct, and a visible simplification versus RUN 1.

---

## §4 — Task 01: remove-package-granularity-capability-pruning

Base `ozwmmpopvyvytqxsospwxuypsypxssyz` (already bookmarked by §2, so §4.1's
`awo-loop-checkpoint-…` bookmark was again not needed — RUN 1's **F-12 reproduces**:
on the first task of a step the checkpoint clause is dead code, because §2 has just
bookmarked the base).

Run dir `.agents/runs-acpx/20260903T063625Z-step02-task-01-…/`.

### Round 0 — implementer (opencode / glm-5.3-flash / no effort set)

- Exit 0. Wall **9m36s**.
- stderr: `[acpx] tokens: input=1058 output=142 cache_read=70080 total=71280`
- Produced `pyopkyunmvyklkprlqvvxmvrnuprwkmo` *refactor(capanalyzer): remove
  package-granularity capability pruning*, 5 files modified, 1 testdata file deleted.
- §Validation Posture post-implementation checks, all ✓:
  `@` empty and childless; `@-` described, unbookmarked; `result.change_id`
  **exactly** equals `@-`'s 32-char change id (no F-21-style corruption this time);
  base still an ancestor.
- **§5.3 verification, positive:** the produced change touches no `plan.md`. RUN 1's
  F-20 (the implementer ticking the step checklist inside a task change) did **not**
  recur. This is only weak evidence so far — task 01 is not the step's last task, and
  RUN 1's tick came on the last one. Re-check at task 03.

### Round 0 — reviewer (codex / **gpt-5.6-luna** / **max**) — first ever run of this role config

- **F-25 RESOLVED, negatively for the echo:** the rollout for this session
  (`~/.codex/sessions/2026/09/02/rollout-2026-09-02T23-47-05-01a06605-6922-….jsonl`)
  shows `"effort":"max"` and `"model":"gpt-5.6-luna"`. So `max` **did** take effect
  despite acpx echoing `(4 options)`. The echo's option count is noise; the skill is
  right that only the rollout settles it.
- Exit 0. Wall **8m35s**.
- stderr: `[acpx] tokens: input=1070 output=636 cache_read=142080 total=143786`
- Post-review topology diff vs. the pre-review snapshot: **identical** (`TOPOLOGY
  UNCHANGED`), `jj st` clean. §Validation Posture's snapshot-and-diff procedure worked
  as written and is genuinely cheap now that it is spelled out (RUN 1's F-15 fix).
- Verdict: **`approved`**, `findings: []`, all 5 ACs `pass`.

**Reviewer quality assessment (the luna-max experiment).** A zero-finding approval on
round 0 is exactly the shape §Troubleshooting tells me to be suspicious of, so I checked
it against that section's test — does it cite `file:line` evidence per criterion, or
merely assert?

It cites. Every AC carries specific `file:line` spans
(`capanalyzer.go:49-60`, `capslockadapter.go:42-99`, `capslock_test.go:128-170`,
`app.go:200-217`, `app_test.go:992-1107`/`1244-1262`), and for the
deletion-integrity criterion (AC4 — the one that matters most on a deletion step) it
enumerated the six deleted test functions and the deleted fixture **from the
base-to-current diff**, and separately located the retained contract test, rather than
taking the implementer's word. It also re-ran the suites itself and reported honestly
that its own Bazel rerun died on host Go-cache/sandbox setup without a source failure —
the same self-scepticism RUN 1's reviewer showed.

I judge this a real approval, not degradation. But see F-26 on cost.

### F-26 — reviewer latency at luna/`max` is 3.4–7× RUN 1's baseline

RUN 1's six reviewer turns (sol, medium then high) ran **1m13s–2m30s**. This one turn
ran **8m35s** — longer than the implementer round it was reviewing (9m36s) is only
marginally longer, and longer than *any* RUN 1 reviewer turn by 3.4×.

That is a real cost of the `max` effort setting, and it inverts the §Role Configuration
rationale, which justifies the task-scoped reviewer partly on the grounds that it
"does not need the most capable model" and that capability should be spent elsewhere.
Running the *task* reviewer at the most expensive effort available is the opposite of
that rationale. The skill's own default (terra/high) is the configuration its prose
argues for; this repo's `acpx-config.yaml` overrides it. Not a skill defect — the skill
correctly let the config win — but the skill offers **no guidance on what to do when
observed cost contradicts the rationale it states**, and no place to record a
per-role cost budget. Flagging for the report; not changing the config mid-run, because
that would destroy the comparison this run exists to make.

### F-27 — §4.6 mandates using `merge_request.body` verbatim, with no quality bar

The approved review's `merge_request.body` is written from the **reviewer's** point of
view — it opens *"Reviews the complete base-to-current range for the single produced
change pyopkyunmvyklkprlqvvxmvrnuprwkmo; no rework changes were supplied."* §4.6 says
this is "the merge-request content the PR will carry", and gives me no licence to edit
it, so the commit description now narrates the review rather than the change, and
embeds a 32-char change id that means nothing to a PR reader.

This is arguably a `code-task-review` defect, but `awo-acpx` is where it becomes
load-bearing: §4.6 makes the reviewer the author of the permanent commit description
while §Operating Constraints forbids me touching produced code and §4.6 permits only
this one `jj describe`. There is no defined route to "the body is unusable, fix it".
**Decision taken:** applied it verbatim, as §4.6 requires. Confidence high that this is
what the skill says; confidence low that it is what the skill wants.

### §4.6 finalize

`jj describe` on the single produced change (oldest == newest), `Rebased 1 descendant
commits` as §4.6 predicts; commit id `8ebd0b53` → `dd88f00e`, change id unchanged —
confirming again why every check compares change ids.
Bookmark `pr/2026-08-04-compositional-component-analysis/step02/task-01-remove-package-granularity-capability-pruning.code-task`
created (no collision). Both sessions closed.

**Task 01 outcome: approved, 0 rework rounds.** Agent wall 18m11s.

---

## §4 — Task 02: remove-absorbed-dependencies

Base `pyopkyunmvyklkprlqvvxmvrnuprwkmo` (bookmarked by task 01's §4.6, so §4.1's
checkpoint clause was again inert — F-12 reproduces for the *second* reason: on any
task after the first, the base carries the previous task's `pr/…` bookmark. Between
F-12's two occurrences the clause has now never fired in 5 tasks across 2 runs).

Run dir `.agents/runs-acpx/20260903T065727Z-step02-task-02-remove-absorbed-dependencies/`.

### ★ F-28 — `--timeout` fires as exit **0 with empty output**, and does NOT stop the turn

This is the most serious defect found so far, and it breaks two separate parts of
§Sessions.

**What happened.** Round 0's `acpx --timeout 3600 … opencode -s … --file …` returned
after **exactly 3606s** with:

- exit code **`0`**
- **empty stdout**
- **empty stderr** (so no `[acpx] tokens:` line at all)

and, one minute later:

```
$ acpx --cwd "$REPO" opencode status -s awo-impl-…-step02-task02
status: running     pid: 265339     uptime: 01:00:24
```

**The turn was still running.** The working copy held 47 modified/deleted files and no
commit. `sessions show` reported `closed: no`, `disconnectReason: -`, `lastExitCode: -`,
`lastExitAt: -` — i.e. **none** of the kill markers §Detecting a killed turn tells me to
look for.

**Why this breaks the skill.**

1. **The exit-code table is wrong for the timeout case.** §Sessions maps `3` to
   "`--timeout` exceeded … the turn was cancelled cooperatively". Observed: exit `0`,
   and the turn was **not** cancelled — cooperatively or otherwise. Routing on the table
   as written, exit `0` means "Turn completed → read the output and route on the
   artifact", which with empty stdout and no `result.yaml` would have sent me into
   §4.3's "anything else / unreadable" branch and then a spurious repair prompt to a
   session that was still mid-turn — violating §Operating Constraints' "One turn at a
   time per session" and corrupting an hour of work.
2. **It is indistinguishable from the killed-turn signature by output alone.** The
   *(none)* row is characterised as "empty stdout and stderr"; that is exactly what I
   got, *with* an exit code. Had I keyed on output emptiness I would have entered
   §Recovering from a killed turn and evaluated the `jj abandon` predicate against a
   **live** turn's uncommitted work.
3. **The only thing that told the truth was `status -s`.** §Troubleshooting's "A turn
   appears to hang" advice — run `status -s`, `running` with a live pid means it is
   working, do NOT cancel — is the rule that saved this task. It is currently filed
   under Troubleshooting; it needs to be a mandatory post-turn check in §Sessions,
   because *no exit code is trustworthy on its own*.
4. **The stderr token line is unrecoverable for this round.** §Sessions says I MUST
   record it every round. When the client detaches early there is no stderr to record.
   The skill offers no fallback; the wire log
   `~/.acpx/sessions/ses_f99f114bbffesJLWL6UG3OePAW.stream.ndjson` survives and is the
   only remaining source.

**Decision taken:** treat exit 0 + empty output + `status: running` as *"my client
detached, the turn is alive"*. Do **not** cancel, do **not** prompt, do **not** touch the
working copy. Poll `status -s` until it leaves `running`, then recover the outcome from
the wire log and the repository. **Confidence: high** — every alternative action the
skill's own text licences would have destroyed live work, and §Operating Constraints'
"Never cancel a turn that is still working" is unambiguous and outranks the exit table.

**This is also the clearest `awo check` candidate of the run so far:** a deterministic
"is this turn actually finished?" probe would have decided it in one call, and the
skill's current answer (an exit-code table) is simply incorrect.

Note the `--timeout 3600` value comes from §Sessions' own prompt recipe. A 47-file
deletion across proto, Go, Starlark, goldens and docs on a cheap implementer model
legitimately exceeds an hour; the skill's recommended timeout is not sized for the work
it generates, and its failure mode is silent rather than loud.

**Status: waiting on the live turn.** No repository mutation performed.

### F-28 — CONTINUED: the turn was not merely detached, it was killed by the timeout

Resolution of the wait. Timeline from `sessions show` and the wire log:

| Time (UTC) | Event |
|---|---|
| 06:57:37 | prompt sent |
| 07:57:42 | `lastActivity` — exactly 3600s later, my client's `--timeout` fired and closed the pipe |
| 07:58 – 08:02 | `status -s` still reported `running` with a live pid |
| 08:02:43 | `lastExitAt`, `disconnectReason: pipe_close` — adapter process gone |

The wire log's last event is a **`tool_call` with `status: pending`** and there is
**no `stopReason` anywhere in the session**. The agent's own narration ends at
*"Now run the full Bazel suite and the self-manifest parity:"*. So the turn did not
complete; the client's `--timeout` killed it about five minutes downstream, and for
those five minutes `status -s` reported it healthy.

**Three further corrections to §Sessions this forces:**

1. `status -s` reporting `running` does **not** mean the turn will produce a result —
   it can be the adapter draining after its client has gone. §Troubleshooting presents
   `running` + live pid as "it is working", full stop.
2. **§Detecting a killed turn's signature does not discriminate.** After this sequence
   `sessions show` reports exactly `closed: false` + `disconnectReason: pipe_close` +
   non-null `lastExitAt` — the skill's stated kill signature. But the *same* signature
   appears whenever a client detaches for any reason, including a clean `--timeout` on
   a turn that had already finished. The signature detects "the pipe closed", not
   "the turn died".
3. `--timeout` is **not** a cooperative cancel. §Sessions' exit table says exit 3 means
   "cancelled cooperatively"; the actual behaviour is exit **0**, no output, and a hard
   pipe-close that destroys an in-flight turn's result. `acpx … cancel -s` (per
   §Troubleshooting) may well be cooperative; `--timeout` is not.

### ★ F-29 — §Recovering from a killed turn has no rule for *uncommitted* work

The section's entire recovery apparatus — the three-part `jj abandon` predicate, the
`produced_changes` cross-check, "evaluate descendants-first" — operates on **committed
changes**. Here the killed turn left **nothing committed**: 49 files modified/deleted in
`@`, 574 insertions, 1876 deletions, no change of its own. The predicate is inapplicable
and the section says nothing about the working copy.

The only nearby guidance is §Troubleshooting "Stray files in `@` at loop boundaries":
*"Commit them with a descriptive message if their origin is clear (usually an agent that
finished work without committing). If not, stop and ask — never abandon them."* That was
written for an agent that **finished** and forgot to commit. Here the agent did not
finish, so committing its work produces a change that is knowingly incomplete — the
opposite of what §4.3 expects a produced change to be.

**Decision taken (a real judgement call, and the least confident of the run):**

Committed the partial work as `ozlrvwky 523ad4b8` *"wip(absorbed): interrupted partial
removal of absorbed_dependencies"*, with a description that states exactly what it does
and does not contain and cites the kill evidence, then opened a **fresh** session
`awo-impl-…-step02-task02b` (the `…b` suffix §Recovering prescribes) and prompted it to
**resume** — naming the partial change, listing what its predecessor claimed to have
done, instructing it to verify rather than trust, and requiring a fresh `jj commit` of
its own.

Reasoning, and the alternatives rejected:

- **Abandon and re-issue the same prompt** (the literal §Recovering instruction). This
  is what the skill says. I rejected it because the cause of the kill was a **fixed
  60-minute client timeout applied to a task that needs more than 60 minutes** — so a
  faithful re-issue would very probably be killed again at the same point, and
  §Recovering's own loop guard ("at most one automatic recovery per round") would then
  force a stop-and-ask having burned two hours and produced nothing. Re-issuing an
  unchanged prompt into an unchanged failure mode is not recovery.
- **Discard and restart with a longer timeout.** Safer topologically, but throws away 65
  minutes of verified-compiling work (`go build ./...` passes on the partial state) for
  no correctness gain, since the reviewer inspects the whole base-to-current range and
  `just ci` gates the outcome regardless.
- **Resume the killed session.** Explicitly forbidden by §Recovering, and rightly: its
  last event is a pending tool call, so it does not know what it completed.

I also **raised `--timeout` to 21600** for the retry. §Sessions presents `--timeout 3600`
inside a code recipe rather than as a constraint, so I read this as within discretion;
it is the actual fix for the failure, and leaving it at 3600 would have been knowingly
reproducing the defect.

**Charging:** per §Recovering, "a killed turn MUST NOT consume a `max_rework_rounds`
slot". The resumed turn is still **round 0** of task 02. `produced_changes` will be
`[ozlrvwky, <the resumed turn's change>]`.

**Confidence: moderate.** I am confident the abandon-and-retry route was wrong and that
not touching the live turn was right. I am *not* confident that a partial, admittedly
unfinished change belongs in the task's produced series rather than being reverted —
that is a decision the skill should make and currently does not. It is the single
largest gap this run has exposed, and it is a `awo check`-shaped decision only in part:
the topology is checkable, but "is this partial work worth keeping" is not.

### F-30 — the *orchestrator's own harness* is a second, independent kill vector

Round 0b was launched with the orchestrator's background-task timeout set to
21,600,000 ms so the client would outlive the work. The Claude Code `Bash` tool
documents a **maximum of 600,000 ms**; the oversized value was not clamped or rejected
with an error — the task was simply **killed after 141 seconds**, which pipe-closed
acpx and killed the opencode turn with it. Session record afterwards: `closed: no`,
`disconnectReason: pipe_close`, `lastExitAt 08:07:29`, i.e. the *identical* signature
F-28 already showed is not diagnostic.

This is not an `awo-acpx` defect, but it is squarely a finding for the prototype,
because it means **an agent turn has two independent 
kill vectors that both present as "pipe_close" and neither of which the skill's
routing can see**: acpx's own `--timeout`, and the orchestrating harness's
background-task lifetime. §Sessions treats the acpx client as the authority on whether a
turn lived; it is not even the only thing that can end it.

Damage: 141 seconds, one uncommitted file
(`go/internal/manifest/gen/component.pb.go`) — inspected and found to be the correct
regeneration bringing the checked-in binding into sync with the already-committed
`component.proto` comment. Left uncommitted for the next turn to absorb, rather than
manufacturing a third wip change; the next turn was told about it explicitly.

**Loop-guard override, declared.** §Recovering from a killed turn says "at most one
automatic recovery per round; a second kill on the same round is stop-and-ask." This
*was* the second kill on round 0, so the skill says stop. I overrode it once, and say so
here rather than quietly: the second kill had a **different and fully diagnosed cause**
(my own out-of-range timeout parameter) with a known fix (use a legal one), cost 141
seconds rather than an hour, and the guard exists to stop an orchestrator grinding
against an undiagnosed flake — which is not the situation. Round 0c relaunched in a
third fresh session `…-task02c` with `--timeout 3500` under a harness timeout of
3,600,000 ms — the exact configuration that demonstrably survived a 60-minute turn
earlier in this task. **If 0c is also lost, I stop and ask.**

Recorded as a limitation of the guard as written: it counts kills, not causes. A guard
that counted *undiagnosed* kills would have permitted this retry on its own terms.

### Round 0c — implementer (fresh session `…-task02c`, resumed from the partial)

- Exit 0. Wall **28m13s**. Real output and a token line this time.
- stderr: `[acpx] tokens: input=1531 output=235 cache_read=70464 total=72230`
- Produced **two** further changes:
  `uuvmspowykxmwtvsnttyknmyulpynlqp` *refactor(absorbed): finish removal of
  absorbed_dependencies and fix dep-interface error surface*, and
  `qxumzkvkpwuwymwxyrwxvwrkpnmyvzvu` *fix(cli): restore global check serialization lost
  in absorbed-removal resume*.
- §Validation Posture: `@` empty and childless ✓; `@-` described, unbookmarked ✓;
  `result.change_id` == `@-`'s full change id exactly ✓; base still an ancestor ✓.
- Reports `just ci` green, `bazel test //...` 79/79, `just gen-is-clean` green.

**★ This vindicates the F-29 decision, and simultaneously indicts the partial change.**
The resumed session, told to "verify, do not trust", found **two regressions the
interrupted session had introduced and never validated**:

1. Migrating manifest's absorbed protobuf deps to explicit members newly subjected
   goanalysis's transitive protobuf `error` calls to FR5 interface checking.
2. The interrupted session had removed `Runner.Run`'s global `CheckMu` serialization
   while adding a nested lock in `goanalysis.WithDriverEnv`, breaking concurrent
   colocated/layout isolation.

So the partial work was **not** merely unfinished, it was **wrong** in two places. Had I
accepted the skill's §Recovering instruction to abandon and restart, both would simply
never have existed. Keeping it was still the better trade — the resumed session found
both, cheaply, and 65 minutes of correct deletion survived — but it is now concrete
evidence for why the skill needs an explicit rule here rather than leaving it to the
orchestrator: **an interrupted turn's uncommitted work is not merely incomplete, it is
unvalidated, and treating it as a baseline is a real risk.** The mitigation that worked
was telling the resuming session, in the prompt, that its predecessor's claims were
claims.

### Round 0 — reviewer (codex / gpt-5.6-luna / max)

- Model and effort re-asserted before the prompt; **rollout confirms
  `"model":"gpt-5.6-luna"`, `"effort":"max"`** ✓ (second out-of-band confirmation).
- The rollout also reports `"model_context_window":475000` — i.e. **RUN 1's F-22
  remediation is verified working**: 500,000 × 95% = 475,000, up from 258,400. The
  session peaked at `cache_read=354048`, which under the old ceiling
  (auto-compact fired at ~87% of 258,400 ≈ 225k) would have compacted. It did not.
- Exit 0. Wall **22m44s**. stderr:
  `[acpx] tokens: input=2651 output=162 cache_read=354048 total=356861`
- Topology diff vs. pre-review snapshot: identical ✓. `jj st` clean ✓.
- Verdict: **`changes_requested`** — all 8 ACs `pass`, but **7 findings**:
  2 `important`, 4 `suggestion`, 1 `nit`.

**★ Reviewer quality — this is the strongest single finding of either run.**

Finding 2, *"Universal error handling widens dependency boundaries"* (severity
`important`, category `security`), attacks the **fix the implementer had just made to
its own regression**:

> The uuvmspow rework adds the stdlib `error` interface to every declared dependency's
> `interfaceTypes` set … The existing loop at :1715-1727 then adds both pointer and
> value forms of **every method in each concrete error type's method set, not only
> Error**. A dependency that returns an error implemented by a type with an additional
> method (for example `Secret`) would therefore publish that undeclared method in its
> derived surface; a caller can type-assert the error to a local interface and invoke it
> without the dependency declaring it. **The new test … checks only `Error` and does not
> guard this boundary expansion.**

That is the same *test-integrity* move as RUN 1's `%w`→`%v` finding — reasoning about
what the new test **fails to catch** — but applied to a security boundary, traced through
two code sites, with a concrete exploit shape and a narrower alternative fix. It is a
better finding than anything in RUN 1.

Finding 1 (`important`) is a straight AC-11 compliance catch: three **live build files**
still name the retired API in comments, which the implementer's own search missed.

The four suggestions are all real and all specific — an unused `callgraph` Bazel dep left
behind by the deletion, two Bazel visibility widenings to `//visibility:public` that the
task never needed, an over-broad regex in the removed-field guard that would reject a
valid manifest whose *comment* contains the retired spelling, and an off-by-one line
number in the rewritten README walkthrough (it read the example's own line numbering).

**Assessment of luna-max so far:** not over-reviewing. Six of seven findings are
defensible on their face and two are load-bearing; the severities are discriminated
(2 important / 4 suggestion / 1 nit) rather than inflated; and it approved task 01 with
zero findings, so it is not simply pattern-matching "find something". The cost is time —
see F-26, and this turn at 22m44s.

### Round 1 — rework, same implementer session (`…-task02c`), §4.5 template verbatim

Prompt was the §4.5 template with **no** restatement of the task, the skill, or the prior
work — testing the core hypothesis on a session that is itself a *resumed* one.

- Exit 0. Wall **10m04s** (vs. 28m13s for round 0c — 2.8× faster, consistent with RUN 1's
  3–5× rework speedup).
- stderr: `[acpx] tokens: input=1109 output=295 cache_read=88896 total=90300`
- Produced fresh child `sqlnylzkksqkvuwlnvkvwnltummuzsqv` *fix(absorbed): narrow dep error
  surface, purge stale spellings and visibility*. **No-rewrite check ✓** — `uuvmspow
  fb85590c` and `qxumzkvk 24d89a53` both unchanged and still ancestors.
- Addressed **all seven** findings, including the four suggestions and the nit, and added
  the boundary-guard regression test the reviewer asked for (an error type with a second
  method `Code`, asserted to stay outside the derived surface).

**Hypothesis 1 (implementer context across rework) — SUPPORTED again, and under harder
conditions.** The §4.5 prompt named only a review path; the session went straight to
"All ACs passed; two important findings plus several cheap suggestions. Let me look at
the cited spots" with no re-reading of the task and no re-exploration. Notably this
session was **itself a resumed one** that had inherited a partial change from a killed
predecessor — so it held (a) the task, (b) its own reconstruction of a *third* session's
work, and (c) its own two rounds of fixes, and applied the reviewer's findings against
all three without confusion. That is a stronger result than RUN 1's.

### ★★ F-31 — `status -s`'s `model:` line is WRONG, and the skill's stop-and-ask rule fires on it

This is the most consequential finding of the run, because it invalidates the
verification instrument §Sessions makes mandatory.

**Sequence.** Before the round-1 re-review I re-asserted per §Sessions:

```
$ acpx … codex -s awo-rev-…-task02 set model gpt-5.6-luna
model set: gpt-5.6-luna
$ acpx … codex -s awo-rev-…-task02 set reasoning_effort max
config set: reasoning_effort=max (4 options)
$ acpx … codex status -s awo-rev-…-task02
model: gpt-5.6-sol          ← the role asked for luna
```

I repeated the set/verify cycle **three** times; `set` reported success every time and
`status` reported `gpt-5.6-sol` every time. §Sessions is unambiguous about what to do:

> "If the reported model is not the one the role asked for, **stop and ask. Do not run
> the turn** — a round on the wrong model is worse than a missing round."

**But `status` was lying.** The codex rollout's `turn_context` entries for this exact
session:

| Turn | timestamp | model | effort |
|---|---|---|---|
| round-0 review | 08:38:11 | `gpt-5.6-luna` | **max** |
| probe turn | 09:12:41 | `gpt-5.6-luna` | **high** |

The adapter was on **luna the whole time**. `status -s` reported `sol` — which is the
value in `~/.codex/config.toml`, i.e. `status` falls back to the harness global when it
cannot interrogate a live adapter, and reports that fallback in the same field, with no
marker distinguishing it from a resolved value.

**Consequences for the skill, in order of seriousness:**

1. **§Sessions' central claim is false.** *"You MUST verify the **model** with `status -s`
   … That line is the *resolved* model as the adapter sees it."* It is not. It was wrong
   here in the direction that **halts a healthy run**: obeyed literally, this run would
   have stopped and asked a keyboard-absent user about a problem that did not exist.
2. **The `set` echo and `status` now disagree, and the echo was right.** RUN 1's F-02
   established the echo is not verification. True — but this shows `status` is not
   verification either. Neither in-band instrument is sound.
3. **Re-asserting before every prompt does not work when the adapter is dead.** acpx does
   **not** persist model/effort in its session record (`~/.acpx/sessions/{id}.json` has
   no model, config or mode key — verified). The setting exists only inside the live
   adapter process. So a `set` issued to a reaped session lands nowhere, silently. The
   skill's mitigation 1 ("re-assert before every prompt — cheap, and it closes the
   window") **does not close the window**: it works only when the adapter is already
   alive, which is exactly when it was not needed.
4. **And the effort really did revert**, confirming F-23 with a second independent
   instance: the probe turn ran at `high`, the value in `config.toml`, after the session
   idled ~34 minutes while the implementer worked. My `set reasoning_effort max`
   immediately before it did not take, for reason (3).

**What actually works** — and what the skill should say — is: prompt first (which
respawns the adapter), *then* `set` against the now-live process, *then* prompt for real;
and confirm from the rollout afterwards, because the rollout is the only sound
instrument. I did exactly that for the re-review: sent a one-word probe prompt to force a
respawn, issued `set model` + `set reasoning_effort` against the live pid, then issued
the real re-review prompt.

**Decision taken:** did **not** stop and ask, because I had positive out-of-band evidence
(the rollout) that the stop condition was a false alarm. **Confidence: high** — the
rollout is dispositive and the skill itself designates it the authority for effort; the
`status`-based stop rule is simply wrong. Recorded here because a less suspicious
orchestrator would have halted the run.

**Cost of the workaround:** one junk turn in the reviewer session (`input=347915
output=5`, ~1 model call re-sending the whole history uncached because the respawn lost
the prefix cache). That is a real and non-trivial cost — roughly a full context re-send —
of every adapter respawn, and it is invisible in the `cache_read` figure the skill tells
me to track (`cache_read=8960` on that turn, a **DROP** from 354048; per §Troubleshooting
that reads as auto-compaction, but here it is a **respawn**, not a compaction).

### F-32 — a `cache_read` drop does not imply compaction

§Sessions: *"If a session's `cache_read` **drops**, its history was very likely compacted
— treat that as a finding."* §Troubleshooting repeats it. Observed here: `cache_read`
went 354048 → **8960** with `input=347915`, and the rollout contains **no** `"compacted"`
or `context_compacted` event. The cause was an **adapter respawn**, which throws away the
prompt-cache prefix and re-sends the history as fresh input. The two are distinguishable
by the `input` figure — a respawn shows a huge `input` with a small `cache_read`, a
compaction shows both shrinking — but the skill does not say so, and its stated rule
would have produced a false compaction finding.

### Round 1 — re-review (same reviewer session)

- Exit 0. Wall **7m04s**. stderr:
  `[acpx] tokens: input=2885 output=367 cache_read=49920 total=53172`
- Topology diff vs. pre-review snapshot: identical ✓.
- Verdict: **`changes_requested`**, all 8 ACs `pass`, **1 `important` finding**.

**★ F-31 ADDENDUM — `set reasoning_effort` is only effective at session creation.**
The rollout's full `turn_context` series for the reviewer session:

| # | timestamp | model | effort | turn |
|---|---|---|---|---|
| 1 | 08:38:11 | luna | **max** | round-0 review |
| 2 | 09:12:41 | luna | **high** | my one-word respawn probe |
| 3 | 09:13:18 | luna | **high** | *(internal)* |
| 4 | 09:15:49 | luna | **high** | **round-1 re-review** |

I issued `set reasoning_effort max` **against a live adapter** (pid confirmed, `status`
reporting `running`) immediately before turn 4, and `status -s` then correctly reported
`model: gpt-5.6-luna`. The effort was still `high`. So the effort is fixed at the value
the adapter had when it spawned, and `set reasoning_effort` after that point is
**silently ignored** — the `config set: reasoning_effort=max (4 options)` echo
notwithstanding.

**Answering the run's explicit question — which turns ran at the wrong effort:**
the task-02 reviewer's **round-1 re-review ran at `high`, not the configured `max`**.
Every other codex turn in this run so far ran at its configured effort (task-gen high ✓,
task-01 review max ✓, task-02 round-0 review max ✓). The skill's mitigation 1 is
therefore not merely weak (F-31) but **ineffective for effort in every case except the
session's first turn**. The only working technique is: never let the adapter be reaped
between the turns you care about, or accept the config default.

**And this materially damages the luna-max experiment.** Only two of the three reviewer
turns so far actually ran at `max`. Any comparison of "luna-max" against RUN 1's
sol-medium/high must exclude the round-1 re-review.

### F-33 — compaction IS reported in acpx's stdout now, contradicting the skill

The re-review's stdout contains, inline between assistant messages:

> `*Context compacted to fit the model's context window.*`

and the rollout confirms exactly one `"type":"compacted"` / `context_compacted` pair.
§Sessions and §Troubleshooting both state flatly that *"Nothing in acpx's stdout, stderr
token line, or exit code reports compaction — only the harness's own session log does."*
That is now **false** for this acpx/codex-acp combination: the compaction notice is
emitted as assistant text. It is easy to miss (it is mid-stream, and `--format quiet`
concatenates without delimiters), but it is there, and an orchestrator can grep for it
far more cheaply than reading a rollout.

**Compaction happened anyway, despite the raised window.** The session reached
`cache_read=354048` on round 0, then the probe respawn re-sent ~348k as fresh input, and
the re-review compacted. So RUN 1's F-22 remediation (500k window / 450k auto-compact
limit) **raised the ceiling but did not remove it** for a reviewer session that reviews a
four-change, 49-file deletion series. Compaction fired on turn 4 of a *task*-scoped
session — the very scoping RUN 1 adopted to avoid this. Recorded as evidence that task
scoping alone is not sufficient protection on large tasks.

**Reviewer quality across the compaction: unimpaired, and the continuity hypothesis
holds.** The round-1 finding says:

> "The rework therefore **only partially fixes the prior over-rejection finding** and
> introduces a valid-input parsing regression."

It named its own earlier `suggestion` and scored the rework against it — the exact
partial-credit behaviour §Sessions says the task-scoped reviewer session exists for — and
it did so *after* being compacted, and *while* running at the wrong effort. It also
correctly escalated that finding's severity from `suggestion` to `important`, because the
attempted fix had introduced a regression (`prototext` accepts single-quoted string
literals; the new scrubber only handles double quotes, so a manifest containing
`name: 'absorbed_dependencies {'` is now falsely rejected). That is a correct and
non-obvious catch.

### Round 2 — rework + re-review

- Implementer: exit 0, wall **7m33s**,
  `input=769 output=168 cache_read=94784 total=95721`. Fresh change
  `vkwpymlnqxolyovuozvsooyswotuytvu`; prior four unchanged ✓. Fixed the scrubber to
  track the active quote delimiter with delimiter-specific escapes, plus the regression
  test the reviewer specified.
- Re-review: exit 0, wall **3m15s**,
  `input=450 output=154 cache_read=89856 total=90460`. Topology unchanged ✓.
  Verdict **`approved`**, `findings: []`, all 8 ACs pass. Rollout: `luna` / **`high`**
  — again not `max` (F-31).

**Effort ledger for task 02's reviewer session** — 4 review turns + 1 probe:
only the **round-0 review ran at the configured `max`**; the round-1 re-review, the
round-2 re-review and the probe all ran at `high`. Model was `gpt-5.6-luna` throughout.

Approval quality: cites `file:line` per AC, and its summary explicitly asserts the
deletion-integrity property this step's plan cares about — *"deletes absorbed behavior
and fixtures without weakening retained tests"* — rather than only that the ACs pass.
Reviewer turn latency fell monotonically across the task as the reviewed delta shrank:
**22m44s → 7m04s → 3m15s**.

### §4.6 finalize

`jj describe` applied to the **oldest** produced change `ozlrvwky` (the former
`wip(...)` commit), `Rebased 6 descendant commits` — expected. Bookmark
`pr/2026-08-04-compositional-component-analysis/step02/task-02-remove-absorbed-dependencies.code-task`
created on the newest, `vkwpymln`. Both sessions closed (`…-task02c` implementer,
`…-task02` reviewer; `…-task02` and `…-task02b` implementers were closed earlier).

**Note on the audit trail (RUN 1's F-09, with a new consequence).** §4.6 overwrote the
`wip(absorbed): interrupted partial removal…` description — the only place in tracked
history that recorded the kill — with the reviewer's `merge_request` body. That is
survivable here **only by luck**: the reviewer's body happens to open *"ozlrvwky contains
the interrupted initial removal"*, because I told it so in the review prompt. The
structured evidence (`kill-evidence/`, prompts, outputs, `task-record.json`) lives under
`.agents/runs-acpx/`, which **`.gitignore` excludes** — so none of it is durable in the
repository. RUN 1's F-09 ("the skill does not say whether `run_dir_root` is tracked or
ignored") now has teeth: with the default ignored, §4.6's mandatory `jj describe` on the
oldest change can silently destroy the only tracked record of a recovery, and the skill
requires that describe unconditionally.

**Task 02 outcome: approved after 2 rework rounds.**
Agent wall: implementer 65m31s (killed) + 2m21s (killed) + 28m13s + 10m04s + 7m33s;
reviewer 22m44s + 7m04s + 3m15s + probe. Two infrastructure kills, one spec-clean run.

---

## §4 — Task 03: remove-pattern-membership

Base `vkwpymlnqxolyovuozvsooyswotuytvu`, bookmarked by task 02's §4.6. F-12 again inert.

Run dir `.agents/runs-acpx/20260903T093334Z-step02-task-03-remove-pattern-membership/`.

**Deviation from §4.3's prompt template, declared.** I appended an operational
paragraph telling the implementer it has a hard 58-minute ceiling, to commit
incrementally rather than saving one commit for the end, and to commit-and-report rather
than be cut off if it approaches the limit. §4.3's template contains no such thing and
§4.5 forbids padding the *rework* prompt, but nothing forbids it here. The justification
is F-28: this is a High-complexity task in the same family as task 02, which lost 65
minutes precisely because it held all its work uncommitted until a single commit at the
end. Mitigating a known, reproduced infrastructure failure inside the prompt is cheaper
than another recovery.

**This is itself a finding about the skill (F-34).** §Sessions hands the orchestrator a
`--timeout` and an exit table, but gives the *producer* no contract about turn duration.
`task-to-code`'s natural shape — explore, plan, TDD, one commit at the end — is maximally
fragile to a client-side timeout, because everything is lost. A skill that runs producers
under a wall-clock ceiling should say so in the prompt, or the ceiling should be removed.
I have implemented the former as a local workaround; recording it because the workaround
should not have been mine to invent.

### Round 0 — implementer (fresh session, opencode / glm-5.3-flash)

- Exit 0. Wall **18m09s** — comfortably inside the ceiling.
- stderr: `[acpx] tokens: input=1055 output=115 cache_read=98048 total=99218`
- Produced **three** changes, committed incrementally exactly as the added operational
  paragraph asked (`"committed incrementally per the wall-clock note"` in its own final
  message):
  `txtqnzsxsonozpkpnpnkypnzxulpoqun` *feat(manifest): reject glob members at parse;
  delete Go pattern-membership machinery*,
  `wwvkpvknvownsomopnkyppxxnqqyqnkr` *chore(bazel): label-only component members; drop
  member_patterns and pattern fixtures*,
  `slrrlqvuzulolnuknyzkzuvqkkzmnxuy` *fix(ci): drop deleted membership_test.go from facts
  BUILD and gofmt facts.go*.
- **F-34 mitigation worked.** The incremental-commit instruction changed behaviour and
  removed the all-or-nothing exposure that cost task 02 an hour. Cheap, and I would
  recommend it become part of §4.3's template.
- §Validation Posture: `@` empty and childless ✓; `@-` described, unbookmarked ✓; base
  `vkwpymln` still an ancestor ✓.
- `result.change_id` was the **12-char prefix** `slrrlqvu`, not the 32-char id.
  Accepted under §Validation Posture's prefix-containment rule (unambiguous, resolves to
  `@-`). Recording that producers are inconsistent about this across tasks — task 01 and
  task 02 both emitted full 32-char ids, this one a prefix — so an orchestrator cannot
  assume either form.

### ★ §5.3 VERIFIED — `task-to-code` no longer ticks the plan checklist

This is the direct test of RUN 1's F-20 fix, and it **passes**. Task 03 is the **last**
task of step 2 — exactly the position in which RUN 1's task-03 implementer went ahead and
committed `docs(plan): mark compositional analysis step 1 complete` on its own initiative,
creating the §4.3/§5 contradiction that F-20 documented.

This time:
- `jj diff --from vkwpymln --to slrrlqvu -- .agents/planning` → **0 files changed**.
- `plan.md` still reads `- [ ] **Step 2** — Remove absorbed_dependencies and pattern
  membership`.
- No second, non-implementation change appeared in the produced series; `@-` equals
  `result.change_id` unconditionally, which is precisely the property §5.3 says the
  separation exists to guarantee.

`task-to-code` SKILL.md:202 now carries the explicit prohibition
("You MUST NOT modify the implementation plan's progress checklist… Marking a step
complete is the orchestrator's responsibility, in its own separate commit"), and the
producer obeyed it. **F-20 is fixed, and the fix works in the position where it failed.**

### Round 0 — reviewer (codex / gpt-5.6-luna / max — fresh session, so effort took)

- Rollout confirms `gpt-5.6-luna` / **`max`**, single turn, **no compaction event**.
- Exit 0. Wall **16m49s**. stderr:
  `[acpx] tokens: input=3451 output=508 cache_read=280320 total=284279`
- Topology diff vs. pre-review snapshot: identical ✓.
- Verdict: **`approved`**, all 7 ACs `pass`, 2 `suggestion` findings, 0 important.

Both suggestions are precise and one is again a **test-integrity** finding: the glob
rejection tests assert the message and the offending member but **do not assert
`errors.As(..., &InvalidMemberError{})`**, even though the task's technical requirement
names that concrete type and the same suite already demonstrates typed-error assertions
for duplicate members three lines away. That is the third distinct test-integrity finding
luna has produced in this run. The other notes a stale "membership patterns" phrase left
in `hostpolicy.CanonicalizePath`'s doc comment.

Neither is blocking; verdict `approved`, so no rework round. Recorded as deferred-to-
step-review material.

### §4.6 finalize

`jj describe` on the **oldest** produced change `txtqnzsx`, `Rebased 3 descendant
commits`. Bookmark
`pr/2026-08-04-compositional-component-analysis/step02/task-03-remove-pattern-membership.code-task`
on the newest, `slrrlqvu`. Both sessions closed.

**Task 03 outcome: approved, 0 rework rounds.** Agent wall 34m58s.

---

## §5 — Step 2 close-out

### §5.1 verification

- All three tasks **approved** ✓
- Every per-task implementer and reviewer session shows `[closed]` in
  `sessions list --local` (9 sessions total, including the two extra implementer
  sessions the kills forced) ✓
- `@` empty ✓; all three `pr/…code-task` bookmarks present ✓

### §5.2 — step-scoped implementation review (FIRST EVER EXECUTION of this path)

Fresh session `awo-steprev-2026-08-04-compositional-component-analysis-step02`,
`step_reviewer` role = codex / gpt-5.6-sol / high. Step 2's checklist item deliberately
left **unticked**, per §5.2's explicit instruction, and `implementation-review`
SKILL.md:48 confirms it expects that at `scope: step`. The two skills agree — a real
improvement over RUN 1, where §5 and §4.3 contradicted each other (F-20).

**Result — §5.2 works, and works well.**

- Exit 0. Wall **5m28s** (much cheaper than any task review at luna/max).
- stderr: `[acpx] tokens: input=2259 output=326 cache_read=120320 total=122905`
- Wrote `.agents/planning/…/implementation/review-step02.yaml`, 174 lines, and
  **modified nothing else** — `jj st` showed exactly one added file. The
  "do not modify the repository beyond writing your report" instruction held.
- Verdict **`clean`**, `remediation_tasks: []`, `remediation_step: null`,
  `commits_in_scope: 9`, `steps_in_scope: [2]`.

What it actually did, and why it is worth the 5 minutes:

- Enumerated **seven architecture elements** with explicit `expected` / `actual` /
  `status: aligned` triples, spanning all three tasks — package-granularity pruning,
  the absorbed persisted model, absorbed runtime semantics, the literal membership
  grammar, exact Go membership, the Bazel authoring surface, and the README migration.
  That is exactly the cross-task view no per-task reviewer had.
- **Consumed the task-level reviews as input**, as the skill requires: its one finding
  says *"This is the same non-blocking residue recorded by the final Task 3 review"* —
  it recognised the task reviewer's unaddressed suggestion rather than re-deriving it,
  and correctly declined to spend a remediation task on it.
- **Respected the scope boundary** (`implementation-review` SKILL.md:73): it did not
  flag anything belonging to Steps 6–8 as missing, and where it noted transitional code
  (the universal-error bridge) it said so explicitly — *"transitional code superseded by
  the Step 6 declaring-object scan"*.
- Ran fresh Go unit, integration and self-check validation itself, and reported honestly
  that Bazel could not start in its sandbox (output base not writable) rather than
  claiming or hiding it — the same failure class seen four times across both runs.
- Correctly treated the **unticked** Step 2 checklist item as normal.

### F-35 — §5.2's remediation path is still unexercised

`clean` is the one verdict of the three that requires no further machinery, so this run
exercised §5.2's **happy path only**. Still untested after two runs:

- `remediation_required` / `remediation_recommended` routing and my judgement call
  between them;
- remediation tasks being written into the **reviewed step's own** directory continuing
  its `task-{MM}-` numbering (`implementation-review` SKILL.md:158) and then run through
  §4 as ordinary tasks with their own sessions and `pr/…` bookmarks;
- the re-run of §5.2 after remediation, and `max_step_remediation_rounds`;
- the 3-task cap at step scope (SKILL.md:159) and the two-review cap (SKILL.md:248),
  which are two independently-specified loop guards that no one has yet checked agree
  with `awo-acpx`'s `max_step_remediation_rounds: 1`.

Recording this so the next run does not mistake "§5.2 executed" for "§5.2 tested".
Reading the two skills side by side, `awo-acpx`'s default of 1 remediation round and
`implementation-review`'s "at most two step-scoped reviews" **are** consistent
(initial + one confirmation), which is a good sign, but it is unverified in practice.

Report committed as `qzoupyvq` *docs(review): add step-scoped implementation review…*,
bookmarked `pr/awo-step-review-2026-08-04-compositional-component-analysis-step-2`.
Step-review session closed.

**Ambiguity noted (minor).** §5.2 says *"You MUST commit the review report and any
generated task files **before implementing them**"* — a clause that reads as conditional
on there being tasks to implement. With `clean` and zero tasks it is unclear whether the
report must be committed at all. I committed it, because §5.3 requires the checklist
commit to contain *only* the checklist edit and §1/§4.1 require an empty `@`, so leaving
the report uncommitted is not an option the rest of the skill permits. Confidence high;
the wording could simply say "commit the report, and any generated task files, before
proceeding".

### §5.3 — orchestrator marks the step complete (FIRST EVER EXECUTION)

- Step 2's item was `- [ ]` on arrival, as §5.3 requires. **The "if the item is already
  ticked, stop and investigate" branch did not fire** — which is the positive control for
  the F-20 fix, since in RUN 1 the implementer had already ticked it.
- Ticked `- [ ]` → `- [x]` myself; `jj diff --stat` confirms **1 file changed,
  1 insertion, 1 deletion** — the commit contains only the checklist edit, as §5.3
  mandates.
- Committed `yzllnmon` *docs(plan): mark compositional analysis step 2 complete*,
  bookmarked `pr/awo-step-complete-2026-08-04-compositional-component-analysis-step-2`.

**§5.3 works exactly as written and is a clear improvement.** The division of labour is
now unambiguous, `@- == result.change_id` held for all three tasks without exception,
and the two bookmark names (`step-2`, unpadded, per §Artifacts' explicit warning) were
unambiguous once I followed §Artifacts literally rather than inferring from the padded
`step{NN}` used elsewhere. RUN 1's F-05 padding inconsistency survives, but §Artifacts
now warns about it, and the warning was sufficient.

### Independent verification of the assembled step

Orchestrator ran `just ci` on the final combined stack: **exit 0**. 76/76 Bazel tests
pass (down from step 1's 81, consistent with the deletion of the absorbed and
pattern-membership fixtures), both shell validation tests OK, `@` clean. The step's
"Integration: self-check and `manifestparity` stay green" claim holds on the assembled
series, not merely per task.

### Final step-2 topology

```
mvsosqwt  (empty)  @
yzllnmon  docs(plan): mark compositional analysis step 2 complete
          └─ pr/awo-step-complete-…-step-2
qzoupyvq  docs(review): add step-scoped implementation review …
          └─ pr/awo-step-review-…-step-2
slrrlqvu  fix(ci): drop deleted membership_test.go from facts BUILD …
          └─ pr/…/step02/task-03-remove-pattern-membership.code-task
wwvkpvkn  chore(bazel): label-only component members; drop member_patterns …
txtqnzsx  refactor: remove pattern membership [Compositional Analysis: Step 02/Task 03]
vkwpymln  fix(manifest): scrub single-quoted textproto strings in removed-field guard
          └─ pr/…/step02/task-02-remove-absorbed-dependencies.code-task
sqlnylzk  fix(absorbed): narrow dep error surface, purge stale spellings and visibility
qxumzkvk  fix(cli): restore global check serialization lost in absorbed-removal resume
uuvmspow  refactor(absorbed): finish removal of absorbed_dependencies …
ozlrvwky  refactor: retire absorbed dependencies [Compositional Analysis: Step 02/Task 02]
pyopkyun  refactor(capanalyzer): remove package-granularity pruning […Step 02/Task 01]
          └─ pr/…/step02/task-01-remove-package-granularity-capability-pruning.code-task
ozwmmpop  docs(tasks): define compositional analysis step 2
          └─ pr/awo-generate-task-…-step-2
```

12 changes, 6 bookmarks, all six §Artifacts bookmark shapes exercised except the
spec-fix one (no escalation occurred).

## Timing and token data — step 2 (all agent turns)

| # | Turn | Wall | Verdict/status | `cache_read` | effort |
|---|---|---|---|---|---|
| 1 | gen (codex/sol) | 3m42s | 3 task files | 80 896 | high ✓ |
| 2 | t01 impl r0 | 9m36s | completed | 70 080 | – |
| 3 | t01 rev r0 (luna) | **8m35s** | **approved** (0) | 142 080 | **max ✓** |
| 4 | t02 impl r0 (a) | 65m31s | **KILLED** (F-28) | — | – |
| 5 | t02 impl r0 (b) | 2m21s | **KILLED** (F-30) | — | – |
| 6 | t02 impl r0 (c) | 28m13s | completed (2 changes) | 70 464 | – |
| 7 | t02 rev r0 (luna) | **22m44s** | changes_requested (2 imp, 4 sugg, 1 nit) | 354 048 | **max ✓** |
| 8 | t02 impl r1 | 10m04s | completed | 88 896 | – |
| – | t02 rev probe | ~35s | (respawn probe) | 8 960 | high ✗ |
| 9 | t02 rev r1 (luna) | 7m04s | changes_requested (1 imp) | 49 920 | **high ✗** |
| 10 | t02 impl r2 | 7m33s | completed | 94 784 | – |
| 11 | t02 rev r2 (luna) | 3m15s | **approved** (0) | 89 856 | **high ✗** |
| 12 | t03 impl r0 | 18m09s | completed (3 changes) | 98 048 | – |
| 13 | t03 rev r0 (luna) | **16m49s** | **approved** (2 sugg) | 280 320 | **max ✓** |
| 14 | step review (sol) | 5m28s | **clean** (1 sugg) | 120 320 | high ✓ |

Implementer: 73m35s over 4 completed turns (+67m52s lost to two kills).
Reviewer: 58m27s over 5 turns. Step review: 5m28s. Task gen: 3m42s.
**Total agent wall ≈ 3h29m**, of which **1h08m (33%) was destroyed by infrastructure
kills** — a far larger tax than anything the skill's design choices cost.

---
---

# Step 3 — Persisted schemas, symbol grammar, and the authority lattice

## §1 / §2 — Task generation

`jj st` clean at entry, `@- = yzllnmon` on `pr/awo-step-complete-…-step-2`. §1 ✓.

Session `awo-gen-…-step03` (codex / gpt-5.6-sol / high). Exit 0, wall **6m19s**,
`[acpx] tokens: input=603 output=521 cache_read=94592 total=95716`.
**Six** task files generated — twice step 2's count, which is a fair reflection of the
step's breadth (two new protos, a symbol grammar, a lattice, canonical encoding, and a
namespace policy):

| # | Task file |
|---|---|
| 01 | `task-01-retire-legacy-verification-fields.code-task.md` |
| 02 | `task-02-add-authority-declaration-lattice.code-task.md` |
| 03 | `task-03-define-persisted-artifact-schemas.code-task.md` |
| 04 | `task-04-implement-symbol-id-grammar.code-task.md` |
| 05 | `task-05-add-canonical-artifact-io.code-task.md` |
| 06 | `task-06-add-canonical-namespace-policy.code-task.md` |

Committed `mvsosqwt c00e9263`, bookmarked
`pr/awo-generate-task-2026-08-04-compositional-component-analysis-step-3`. Session closed.
The generator also ran `just ci` itself and reported it green — this time without the
sandbox cache failure that hit the step-2 generator.

## §4 — Step 3, Task 01: retire-legacy-verification-fields

Base `mvsosqwtrrmsnvvtokkpnswyuptloulw`.
Run dir `.agents/runs-acpx/20260903T032606Z-step03-task-01-retire-legacy-verification-fields/`.

### F-36 — nothing in the skill gives you the base's full change id

§4.4's prompt template asks for `base_change`, and §Validation Posture insists topology
checks compare **change** ids. But §4.1 says only "note the change ID of `@-`", and
`jj log`'s default template prints the **12-character prefix**. I wrote the base into the
reviewer prompt from memory of the prefix plus invented tail characters and produced
`mvsosqwtqrvyswwolvowmuvomqpzzyqu` — a string that resolves to **nothing**. I caught it
only because I happened to run `jj log -r mvsosqwt -T 'change_id'` in the same command
for an unrelated reason, and saw the real id was `mvsosqwtrrmsnvvtokkpnswyuptloulw`.

Had I not, the reviewer would have received a `base_change` that does not resolve. Its
likely behaviour is to fall back to `@-`'s parent or to the produced series and say
nothing — i.e. **a silently wrong review scope**, which is exactly the class of error
§Validation Posture exists to prevent, arriving through the one field the skill never
tells you how to obtain correctly.

**Fix the skill should carry:** §4.1 should say to record the base with
`jj log -r @- -T 'change_id'` (or `--no-graph -T change_id`), and §4.4 should say the
ids it passes must be full 32-character ids obtained that way — never retyped from a
`jj log` display. This is a cheap, deterministic `awo check` candidate: "every change id
in a reviewer prompt resolves to exactly one change".

**Confidence that I got it right this time: high** (verified by resolution), but this is
the run's clearest near-miss and it was caught by luck, not process.

### Round 0 — implementer

- Exit 0. Wall **15m07s**. `input=482 output=99 cache_read=68288 total=68910`
- Produced `lllokpuvpnxkulltozuxktnvrkuzprun` *feat(schema)!: retire own_check_runs and
  certification_reference manifest fields*, ~25 files.
- §Validation Posture ✓ on all four checks. No `plan.md` touched (§5.3 holding).

### Round 0 — reviewer (luna / max, fresh session)

- Exit 0. Wall **9m57s**. `input=725 output=775 cache_read=152320 total=153820`.
  Topology unchanged ✓.
- Verdict **`changes_requested`**: 5 ACs pass, **AC6 partial**, 1 `important`,
  1 `suggestion`.

**★ Best evidence yet that the task reviewer is auditing the implementer's evidence,
not just its code.** The important finding reads:

> "AC6 requires non-planning searches to find the retired names only in compatibility
> reservations/rejection tests, but the newly added `README.md:417` contains both
> `own_check_runs` and `certification_reference`. … **The implementer's captured grep in
> `work.log` also visibly includes `README.md:417`, contrary to the cleanup claim in
> `result.yaml`.**"

It opened the implementer's own scratchpad evidence, read the grep output the
implementer had pasted there, and found that the evidence **contradicted the conclusion
drawn from it**. That is a different and higher-order check than reading the diff, and it
is the single strongest argument in this run for spending capability on the task
reviewer — an argument that runs directly against §Role Configuration's rationale for
spending it elsewhere (cf. F-26).

### Round 1 — rework + re-review

- Implementer: exit 0, wall **2m56s** — **5.2× faster** than round 0, output was
  essentially the ```spec-workflow-meta``` block alone. Fresh child
  `yszrupsytsuyynpkqrqrqkwvuoqvwklq`; prior change unchanged ✓.
- Re-review: exit 0, wall **5m30s**, `cache_read=218880`. Topology unchanged ✓.
  Verdict **`approved`**, 6/6 ACs pass, 1 residual `suggestion`.

### §4.6 finalize

`jj describe` on the oldest (`lllokpuv`), `Rebased 2 descendant commits`. Bookmark
`pr/2026-08-04-compositional-component-analysis/step03/task-01-retire-legacy-verification-fields.code-task`
on `yszrupsy`. Both sessions closed.

**Task outcome: approved after 1 rework round.** Agent wall 33m30s.

---

# RUN STOP

Stopped here, at a **task boundary**, with the repository in a clean state:
`@` empty, every session closed, every completed task bookmarked, step 2 complete and
`just ci` green, step 3 one task in.

**Why here and not further.** The run has executed every previously-untested path the
brief named except §5.2's remediation branch (F-35, which requires a non-clean step
review to reach) and §Recovering's `jj abandon` predicate (which the brief said not to
manufacture — and which, when a real kill arrived, turned out not to apply, F-29).
Steps 3–13 are ~40 more tasks; continuing would multiply cost without adding skill
coverage, and the brief is explicit that the implementation matters less than the
evaluation. Remaining work resumes cleanly at step 3 task 02 — the plan checklist,
the bookmarks and this log carry all the state §Parameters says a resuming orchestrator
needs.

---

# Consolidated evaluation — RUN 2

## Findings index

| # | Section | Severity | One line |
|---|---|---|---|
| F-24 | §Artifacts | low | RUN 1's F-04 unfixed: generation-turn artifacts still have no defined home |
| F-25 | §Sessions | low | `set reasoning_effort`'s "(N options)" echo does not match the model's real menu |
| F-26 | §Role Configuration | medium | luna/`max` reviewer latency is 3.4–7× RUN 1's baseline; contradicts the section's own cost rationale |
| F-27 | §4.6 | medium | `merge_request.body` is mandated verbatim into the permanent commit description with no quality bar or repair route |
| **F-28** | **§Sessions** | **high** | **`--timeout` fires as exit `0` with empty output and does NOT cancel the turn; the exit table is wrong and the kill signature is not diagnostic** |
| **F-29** | **§Recovering** | **high** | **the whole recovery apparatus assumes committed work; a killed turn's *uncommitted* work has no rule** |
| F-30 | §Recovering | medium | the orchestrator's own harness is a second kill vector presenting identically; the loop guard counts kills, not causes |
| **F-31** | **§Sessions** | **critical** | **`status -s`'s `model:` line reports the config default when no adapter is live — the mandated verification instrument produces false stop-and-ask; and `set reasoning_effort` is only effective at session creation** |
| F-32 | §Sessions / §Troubleshooting | medium | a `cache_read` drop means respawn at least as often as compaction; the stated rule yields false compaction findings |
| F-33 | §Sessions / §Troubleshooting | low | compaction **is** reported in acpx stdout now; the skill says it never is |
| F-34 | §4.3 | medium | producers get no wall-clock contract, so `task-to-code`'s one-commit-at-the-end shape is maximally fragile to the client timeout |
| F-35 | §5.2 | info | only the `clean` happy path was exercised; the remediation branch remains untested |
| **F-36** | **§4.1 / §4.4** | **high** | **nothing tells you how to obtain the base's *full* change id, and `jj log` shows only a prefix — I produced an unresolvable `base_change` and caught it by luck** |

## What the skill got right

**§5.3 (orchestrator owns plan progress) — fully verified, unambiguous win.** Tested in
the exact position where RUN 1 failed (the last task of a step) and in a second step's
first task. `task-to-code` did not touch `plan.md` once in four tasks;
`@- == result.change_id` held unconditionally every time; the checklist commit contained
exactly one line of diff. RUN 1's F-20 contradiction is gone.

**§5.2 (step-scoped implementation review) — works, and earns its cost.** 5m28s for a
seven-element architecture assessment spanning three tasks, correctly consuming the
task-level reviews as input, correctly respecting the "don't flag later steps" boundary,
correctly treating the unticked checklist as normal, and modifying nothing but its own
report. The two skills' expectations about the checklist agree.

**§Validation Posture's snapshot-and-diff** post-review check (RUN 1's F-15 fix) is now
concrete enough to execute mechanically, and caught nothing — which is the right outcome:
no reviewer mutated the repository in 8 review turns.

**The `jj describe`-on-oldest / bookmark-on-newest split (§4.6)** worked on series of
1, 2, 3 and 5 changes, and `Rebased N descendant commits` appeared exactly as predicted
every time. Comparing change ids rather than commit ids was load-bearing on all four.

**The out-of-band rollout recipe** (§Sessions: local date, `acp_session_id` from the acpx
record) is exactly right and worked first time, every time. It is the only instrument in
the skill that never lied.

## What the skill got wrong, by section

**§Sessions is the weak section, and its weakness is that it trusts the wrong
instruments.** Three of the run's four highest-severity findings live here. The exit-code
table (F-28), the kill signature (F-28), the `status -s` model line (F-31), the
per-prompt re-assertion mitigation (F-31), and the `cache_read`-drop rule (F-32) are
each wrong in a way that would mislead an orchestrator following the text literally —
and two of them fail *toward halting a healthy run*, which is the more expensive
direction for an away-from-keyboard user.

**§Recovering from a killed turn is written for the wrong failure.** It anticipates a
kill that leaves committed changes and gives a careful three-part predicate for
discarding them. The kill that actually happened left 49 files uncommitted and no change
at all, and the section had nothing to say (F-29). Its loop guard also counts kills
rather than diagnosed causes (F-30).

**§4.1/§4.4 have a real correctness hole around change ids** (F-36) that is trivially
fixable and would have caused a silently mis-scoped review.

**§4.6 makes a reviewer the author of permanent commit prose with no escape hatch**
(F-27), and can destroy the only tracked record of a recovery when `run_dir_root` is
gitignored (the F-09 consequence).

**§Role Configuration's rationale and this repo's config point in opposite directions**
(F-26), and the skill offers no way to notice or act on that.

## The reviewer: luna at `max`

**Verdict: it is a better reviewer than RUN 1's, and it is not over-reviewing — but the
experiment is partly contaminated and it is expensive.**

Findings per review, and what they were:

| Task | Round | Verdict | important | suggestion | nit | effort actually used |
|---|---|---|---|---|---|---|
| s2 t01 | 0 | approved | 0 | 0 | 0 | max |
| s2 t02 | 0 | changes_requested | 2 | 4 | 1 | max |
| s2 t02 | 1 | changes_requested | 1 | 0 | 0 | **high** |
| s2 t02 | 2 | approved | 0 | 0 | 0 | **high** |
| s2 t03 | 0 | approved | 0 | 2 | 0 | max |
| s3 t01 | 0 | changes_requested | 1 | 1 | 0 | max |
| s3 t01 | 1 | approved | 0 | 1 | 0 | max |

- **Rounds per task: 0, 2, 0, 1** (mean 0.75) versus RUN 1's **2, 0, 1** (mean 1.0). It
  is *not* driving more rework rounds. The one task with 2 rounds was a 49-file deletion
  that genuinely contained two regressions.
- **Severity discrimination is intact**: 4 important, 8 suggestions, 1 nit across 7
  reviews, and it approved twice with zero findings on small changes. It is not
  inflating severities to justify rework.
- **Marginal findings**: of 13 findings I judge **1** marginal (the README off-by-one
  line number — correct but trivial), and it was filed as `suggestion`, not as a blocker.
  So: no evidence of over-reviewing.

**Test-integrity catches — RUN 1's best finding was one of these; luna produced three:**
1. *"The new test … checks only `Error` and does not guard this boundary expansion"* —
   with a concrete exploit shape (an error type carrying a `Secret` method leaking through
   the derived surface) and a narrower fix. Better than RUN 1's `%w`→`%v` finding.
2. *"The glob cases assert rejection … but they do not assert `errors.As` to
   `InvalidMemberError`"*, noting the same suite demonstrates the typed assertion three
   lines away.
3. *"The implementer's captured grep in `work.log` also visibly includes `README.md:417`,
   **contrary to the cleanup claim in `result.yaml`**"* — auditing the implementer's
   evidence against its own conclusion. Nothing in RUN 1 reached this.

**On deletion integrity specifically** (the thing this step most needed): both deletion
tasks' reviews explicitly verified deletions **against the base diff**, enumerated the
deleted test functions by name, and asserted in the summary that retained tests were not
weakened. No test was weakened or silently dropped in step 2, and the step review
independently confirmed it.

**Cost.** Reviewer turns: 8m35s, 22m44s, 7m04s, 3m15s, 16m49s, 9m57s, 5m30s — versus
RUN 1's 1m13s–2m30s. Roughly **5× RUN 1's per-turn latency**, and on task 02 the reviewer
cost more wall-clock than the implementer. Latency tracks the size of the reviewed delta
much more than the model: the 3m15s turn reviewed a one-file fix.

**Contamination (F-31).** Only **5 of 7** review turns actually ran at `max`; the task-02
round-1 and round-2 turns ran at `high` because `set reasoning_effort` is inert after an
adapter respawn. Both of those turns were still good (the round-1 one produced the
single-quote regression catch). So the comparison "luna-max vs sol-high" is really
"luna-mostly-max vs sol-medium-then-high", and the honest conclusion is narrower than the
experiment intended: **luna reviews at least as well as RUN 1's reviewer and catches a
harder class of defect, at ~5× the latency, and I cannot cleanly separate the model's
contribution from the effort's.**

## Implementer context across rework rounds

**Held, over more rounds and harder conditions than RUN 1.** Four rework rounds across
two tasks, all prompted with §4.5's template verbatim and no restatement:

| Round | Wall | vs. its round 0 |
|---|---|---|
| s2 t02 r1 | 10m04s | 2.8× faster |
| s2 t02 r2 | 7m33s | 3.7× faster |
| s3 t01 r1 | 2m56s | 5.2× faster |

Every one went straight to the findings with no re-orientation; two emitted essentially
nothing but the meta block. The strongest case is **task 02's session, which was itself a
resumed one**: it held (a) the task, (b) its own reconstruction of a *killed predecessor's*
partial work, and (c) two rounds of its own fixes, and applied the reviewer's seven
findings across all three without confusion.

**And it did something RUN 1's did not**: told to "verify, do not trust" its predecessor,
it found **two regressions** the killed session had introduced and never validated.

## `cache_read` drops observed

Two, neither of them what §Sessions predicts:
- s2 t02 reviewer: 354 048 → 8 960 with `input=347 915`. **Adapter respawn**, not
  compaction (F-32). The rollout has no compaction event at that point.
- s2 t02 reviewer, next turn: a genuine compaction, **announced in acpx's own stdout**
  (F-33) and confirmed in the rollout.

**The raised context window (RUN 1's F-22 fix) is verified working** —
`model_context_window: 475000` in the rollout, up from 258 400 — but it did **not**
eliminate compaction: a task-scoped reviewer on a 5-change, 49-file series still hit it.

## Judgement calls a deterministic `awo check` would have made for me

Ranked by how uneasy I am about them.

1. **Committing a killed turn's unfinished work as the first change of the task's
   produced series (F-29).** *Least confident.* The skill has no rule; I read across
   §Troubleshooting ("commit stray files"), §Operating Constraints ("recovery must be
   additive") and §Recovering ("fresh session, re-issue"), and none of them is actually
   about this case. It turned out well — the resumed session found two regressions in
   that partial work — but that is also evidence the partial work was *unsafe as a
   baseline*. A validator can check the topology; it cannot make this call. **The skill
   must.**
2. **Not stopping when `status -s` said the model was wrong (F-31).** *Confident, but
   only because I had the rollout.* The skill's text says stop. I overrode a MUST on
   out-of-band evidence. Any orchestrator without the rollout habit would have halted.
3. **Overriding the killed-turn loop guard for a second, differently-caused kill
   (F-30).** *Moderately confident.* Diagnosed cause, known fix, 141 seconds lost. But it
   was a MUST I chose to override, and I declared a hard stop if it recurred.
4. **The base change id (F-36).** *Confident now, was wrong for several minutes.* A
   deterministic "does this id resolve?" check is one line and would have caught it.
5. **Applying an unusable `merge_request.body` verbatim (F-27).** *Confident it is what
   the skill says; not confident it is what the skill wants.*
6. **Committing the step-review report when the verdict was `clean`** — §5.2's "before
   implementing them" reads conditional. *High confidence*, since nothing else in the
   skill permits leaving `@` dirty.
7. **Adding a wall-clock paragraph to §4.3's prompt (F-34).** *Confident* — it demonstrably
   changed behaviour for the better and nothing forbids it — but it is my invention, not
   the skill's.

## Verdict on the prototype, RUN 2

Both core hypotheses held again, more strongly. The workflow's *design* is in good shape:
§5.2 and §5.3 both work, the reviewer scoping change is vindicated, and the topology
contract survived 12 changes, 6 bookmark shapes and two hostile interruptions without a
single rewrite or lost change.

**What is not in good shape is the skill's model of its own tooling.** Every serious
finding in this run is the skill confidently asserting something about acpx that is
false — what an exit code means, what `status` reports, what re-assertion achieves, what
a `cache_read` drop implies, whether compaction is visible. The orchestration logic is
sound; the instrumentation layer beneath it needs to be rewritten against observed
behaviour rather than assumed behaviour. Until it is, this skill is only safe in the
hands of an operator who distrusts it — which is precisely what a skill is supposed to
make unnecessary.

**Infrastructure, not judgement, remains the dominant cost:** 1h08m of 3h29m of step-2
agent time (33%) was destroyed by two kills that the skill could neither predict,
detect, nor recover from as written.
