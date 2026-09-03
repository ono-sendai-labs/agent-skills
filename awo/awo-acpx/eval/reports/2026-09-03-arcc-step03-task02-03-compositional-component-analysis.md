# awo-acpx RUN 3 — arcc, step 03 tasks 02–03

Verbatim copy of the orchestrator's `work_log` for RUN 3, written incrementally
during the run. Skill revision under test: `suwsoytq 31c4b438`.
Findings F-37 – F-51, continuing RUN 2's numbering.

---

# RUN 3 — resuming mid-step at step 3, task 02

**Skill revision under test:** `suwsoytq 31c4b438`
("feat(awo-acpx): move the acpx surface into scripts, fix it against observed behaviour")
in `/home/xtof/git/ono-sendai-labs/agent-skills`, symlinked into this repo at
`.agents/skills/awo-acpx`. Findings continue from RUN 2's F-36, so the first here is
**F-37**.

**Brief.** Resume at step 3 task 02; §2 is already done for this step and must be skipped.
Weight attention on the paths this revision has never executed: the `scripts/` wrappers,
turn supervision + the 15-minute check-in loop, `stopReason` routing, `--ttl 0` + the
session sweep, §4.7's bookkeeping commit, compaction tracking + the 50% headroom rule, and
§5.2's remediation branch.

## 0. Preflight

### 0.1 Environment

- `acpx` at `/home/xtof/.bun/bin/acpx`, **0.13.2** — meets §Parameters' `>= 0.13.2` MUST. ✓
- `acpx config show`: agents `codex` (`codex-acp`) and `opencode` (`opencode acp`) both
  configured. ✓ Global `ttl: 300`, `timeout: null`, `format: text` — all three overridden
  per-call by the wrappers (`--ttl 0`, no `--timeout`, `--format json`).
- Producer skills reachable: `.agents/skills/` carries symlinks for `task-to-code`,
  `code-task-review`, `plan-to-tasks`, `implementation-review`. ✓
- All five `scripts/` wrappers present and executable (`acpx-open.sh`, `acpx-prompt.sh`,
  `acpx-progress.sh`, `acpx-close.sh`, `jj-change-id.sh`, plus `_common.sh`). ✓
- `~/.codex/config.toml`: `model_context_window = 850000`,
  `model_auto_compact_token_limit = 790000`. This is the number the 50% headroom rule in
  §Prompting a session is measured against for the codex roles: **425 000 tokens**.
  There is no equivalent figure available for the opencode implementer — see F-37.

### 0.2 Resolved parameters

| Parameter | Value | Source |
|---|---|---|
| `plan_file` | `.agents/planning/2026-08-04-compositional-component-analysis/implementation/plan.md` | given |
| `planning_slug` | `2026-08-04-compositional-component-analysis` | derived |
| `repo` | `/home/xtof/git/ono-sendai-labs/architectural-contracts` | given |
| `work_log` | this file | default |
| `run_dir_root` | `.agents/runs-acpx/` | default (gitignored ✓) |
| `record_dir_root` | `.agents/awo/runs/` | default — **probed, not ignored** (below) |
| `generate_tasks_cmd` | unset | — |
| `roles_config` | `.agents/awo/acpx-config.yaml` | default, exists |
| `step_review` | `true` | default |
| `max_step_remediation_rounds` | 1 | default |
| `check_cmd` | unset | — validation by inspection |
| `max_rework_rounds` | 4 | default |
| `turn_check_interval` | 900 s | default |
| `turn_idle_warn` | 900 s | default |

`record_dir_root` probe (§4.7 MUST): created `.agents/awo/runs/.probe`, `jj st` showed
`A .agents/awo/runs/.probe`, removed it, `jj st` clean again. The path is tracked, not
ignored. ✓ (`.gitignore` ignores `.agents/runs/`, which is anchored and does **not** match
`.agents/awo/runs/`.)

### 0.3 Resolved role configuration

From `.agents/awo/acpx-config.yaml`, unchanged from RUN 2:

| Role | agent | model | effort |
|---|---|---|---|
| `task_generator` | codex | `gpt-5.6-sol` | high |
| `implementer` | opencode | `opencode-go/glm-5.3-flash` | *(null — no `set` issued)* |
| `reviewer` | codex | `gpt-5.6-luna` | max |
| `step_reviewer` | codex | `gpt-5.6-sol` | high |

Note the file's own header comment still says the orchestrator "re-asserts model/effort
before EVERY prompt". That instruction was removed from the skill in this revision
(§Sessions: "Pin the model **once**, at open"). The comment is stale — see F-38.

### 0.4 Where I am resuming — verified against the repo, not the brief

The brief says steps 1–2 are complete and step 3 is partway through with §2 already done.
The skill's §Parameters requires me to derive the next step number from the plan checklist
and `work_log`, and this revision has no text at all about resuming *mid-step*. What I
actually checked:

- `plan_file` checklist: Steps 1 and 2 `- [x]`; **Step 3 `- [ ]`**; Steps 4–13 unticked.
  On its own this says "start step 3 at §1", which would re-run §2 and duplicate the task
  files. The checklist alone is not sufficient to resume. (F-39.)
- `jj log` shows, newest-first above the step-2 completion commit:
  - `mvsosqwt c00e9263` `docs(tasks): define compositional analysis step 3`, bookmarked
    `pr/awo-generate-task-…-step-3` — §2's output and §2's bookmark, both present.
  - `lllokpuv ff12e899` + `yszrupsy ae2e5fa2`, the latter bookmarked
    `pr/…/step03/task-01-retire-legacy-verification-fields.code-task` — task 01's two
    produced changes and §4.6's bookmark on the newest.
- `.agents/tasks/2026-08-04-compositional-component-analysis/step03/` holds six task
  files, `task-01` … `task-06`.
- No bookmark exists for `task-02`…`task-06`.
- `@` is empty and childless; `@- = yszrupsy`.

So: §2 done and bookmarked; §4 done for task 01 through §4.6; nothing done for task 02.
**Resume point: §4.1 for `task-02-add-authority-declaration-lattice.code-task.md`.**
The three bookmark shapes are what actually carry the resume state — see F-39.

One thing is *not* done: §4.7's bookkeeping commit for step 3 task 01. That section is new
in this revision, so RUN 2 never executed it and there is no
`.agents/awo/runs/…/step03/task-01-…/` record. See F-40 for what I decided to do about it.

### F-37 — the 50% headroom rule has no denominator for the opencode implementer

§Prompting a session: *"After each turn, compare `totalTokens` against the harness's
configured context window. If a session exceeds **50%** of the window, say so."* That is
actionable for the two codex roles: `~/.codex/config.toml` states
`model_context_window = 850000`, so the threshold is 425 000.

For the **implementer** — `opencode` / `opencode-go/glm-5.3-flash`, which is the session
this skill most cares about keeping uncompacted, because it is the one that spans a whole
task — there is no such figure. `~/.config/opencode/opencode.jsonc` is three lines
(`$schema` + `"permission": "allow"`); it declares no context window. The skill names
`~/.codex/models_cache.json` and `~/.codex/config.toml` as where to look, both
codex-specific, and §Troubleshooting's mitigation (3) is likewise codex-only. So the rule
as written is unenforceable for half the roles it applies to.

**Severity: medium.** Not dangerous — the fallback signals still work: `acpx-prompt.sh`
warns on an announced compaction, and the compaction warning is the thing you actually act
on. But "flag a session above 50%" is a MUST-shaped instruction with no way to evaluate it,
and an orchestrator that silently skips it looks the same as one that evaluated it and
found nothing.
**What I will do:** report implementer `totalTokens` per round without a percentage, and
say explicitly that no threshold was evaluable. For the codex roles I will evaluate against
850 000.
**Confidence: high** that the denominator is unavailable from config; **medium** that
opencode has no other discoverable source I did not think to check.

### F-38 — `acpx-config.yaml`'s header contradicts this revision of §Sessions

`.agents/awo/acpx-config.yaml` opens with:

> *"The orchestrator records the resolved values in its work_log before the first turn, and
> re-asserts model/effort before EVERY prompt (a session's config is lost when its adapter
> is reaped at the idle TTL and respawned)."*

This revision of §Sessions says the opposite, twice, and explains why: *"Pin the model
**once**, at open. Do not re-assert it before every prompt"* — because 0.13.2 persists the
pinned values and `--ttl 0` prevents the reap that motivated re-assertion in the first
place. The config file is a RUN 1 artifact that the RUN 2 fixes did not reach.

**Severity: low**, but it is a live tripwire: the config file is the *first* thing §Role
Configuration tells you to read, and it instructs you to violate a MUST NOT you have not
read yet. An orchestrator that reads config-then-skill in that order and does not
re-reconcile will re-assert.
**What I did:** followed the skill, not the config comment. Declared here rather than
silently. I have **not** edited the config file — it is outside this run's scope and the
comment is documentation, not behaviour.
**Confidence: high.**

### F-39 — §Parameters' resume rule cannot resume mid-step; the bookmarks are the real state

§Parameters: *"derive the **next step number** from `plan_file`'s progress checklist and
`work_log` together. The plan may be partially complete — never assume you start at step 1."*
That yields a *step* number and nothing finer. Applied literally here it yields "step 3",
and §Steps then says "loop over plan steps from the resolved next step number", entering at
§1 → §2. §2 has no idempotence guard of any kind: it would open `awo-gen-…-step03`, run
`plan-to-tasks` on a step whose six task files already exist, and then try
`jj bookmark create pr/awo-generate-task-…-step-3`, which would fail because the name is
taken. The `create`-never-`set` rule (§Operating Constraints) is what would eventually stop
the damage — but only *after* a full generator turn had run and possibly rewritten the task
files that task 01 was already implemented and approved against.

The `work_log` half of the rule is what saves you, and only because RUN 2 happened to write
a good "RUN STOP" section naming the exact resume point. That is a convention, not a
contract: §4.8 requires per-task summaries and §Prompting requires token lines, but nothing
in the skill requires a resumable statement of *where the loop is*, and nothing tells a
resuming orchestrator to look for one.

What is actually authoritative is the repository, and specifically the **bookmarks**, which
this skill creates at exactly the points where the loop can be re-entered:

| Bookmark present | Means |
|---|---|
| `pr/awo-generate-task-{slug}-step-{N}` | §2 done for step N — skip it |
| `pr/{slug}/step{NN}/task-{MM}-….code-task` | task MM done through §4.6 |
| `pr/awo-step-review-{slug}-step-{N}` | §5.2 done |
| `pr/awo-step-complete-{slug}-step-{N}` | §5.3 done — step N finished |

That is a complete, self-describing resume protocol that already exists as a side effect of
the naming scheme in §Artifacts, and the skill never says to use it.

**Severity: high.** The failure mode is not "the orchestrator gets confused"; it is "the
orchestrator re-runs §2 over a step that is half implemented". A resume is not an exotic
path — the previous two runs both ended mid-plan by design, and this skill's own brief
treats stopping at a task boundary as the normal way to end a run.
**Fix the skill should carry:** a §0-style "Resuming" subsection under §Steps that (a) reads
the bookmarks above to locate the loop position to *task* granularity, and (b) makes §2
conditional on `pr/awo-generate-task-…-step-{N}` being absent.
**Confidence: high** on the analysis; the destructive-re-run consequence is reasoned, not
observed — I did not run §2 to find out.

### F-40 — §4.7 has no story for a task completed before §4.7 existed (DEVIATION)

§4.7 is new in `suwsoytq`. Step 3 task 01 ran under the previous revision and so has no
`.agents/awo/runs/…` record, even though its gitignored run dir
(`.agents/runs-acpx/20260903T102538Z-step03-task-01-…/`) still holds every artifact §4.7
asks for: `task-record.json`, `round-0/1.result.yaml`, `round-0/1.review.yaml`, no
`kill-evidence/`.

**Deviation, declared:** §4.7 says "After §4.6" — i.e. it is scoped to the task you just
finished. I ran it for a task I did not run, before starting task 02. Reasoning:

1. It is a pure copy of artifacts that already exist. Nothing was synthesised, which is
   the one thing §4.7 forbids ("If a produced YAML is missing … Do not synthesise").
2. §4.7's stated purpose is that the distilled record "will still be worth reading in six
   months". A step whose task 01 record is permanently absent because of when the section
   landed defeats that for no reason.
3. It exercises the never-executed §4.7 path once more, on real data, at zero risk — which
   is what this run is for.
4. Doing it *before* task 02 rather than bundling it later keeps §4.1's "`@` is empty"
   precondition satisfiable and keeps the commit containing nothing else, as §4.7 requires.

Committed as `orxzvxlk f3c004d5` *chore(awo): record bookkeeping for step03 task 01*, not
bookmarked (§4.7). The message follows §4.7's template exactly. `@` empty afterwards. ✓

**§4.7 mechanics verdict on first execution: works, with one contradiction (F-41).** The
copy-don't-track rule is right and its rationale is right — I confirmed the ignore
behaviour independently in §0.2's probe. The `{record_dir_root}/{slug}/step{NN}/task-{MM}-{slug}/`
layout is unambiguous. The only thing the section does not survive contact with is the
next section that runs after it.
**Confidence: high.**

### ★ F-41 — §4.7 and §4.1 contradict each other: the bookkeeping commit is the next task's base, and it must not be bookmarked (DEVIATION)

§4.7: *"Commit it on its own … **Do not bookmark it.**"*
§4.1: *"The base already carries a bookmark **in every case this loop produces**: §2
bookmarks the task-generation change, and §4.6 bookmarks the previous task's tip. **If it
somehow does not, create one** with `jj bookmark create` before proceeding."*

Both cannot hold. §4.7 runs after §4.6 and before the next task's §4.1, so from task 02
onward the base of every task is the previous task's **bookkeeping commit** — which §4.7
has just forbidden bookmarking, and which §4.1 then requires me to bookmark. §4.1's
enumeration of "every case this loop produces" is simply out of date: it lists §2 and §4.6
and does not know §4.7 exists. Directly observed here — task 02's `@-` is `orxzvxlk`, the
bookkeeping commit, carrying no bookmark.

**Deviation, declared: I did not create a bookmark on the base.** Reasoning:

- §4.7's prohibition is specific and deliberate; §4.1's clause is a fallback written for a
  topology that no longer occurs, and it is the one that is stale.
- §Artifacts enumerates five bookmark shapes and has **no name** for a bookkeeping commit.
  Any bookmark I invented would enter the `pr/…` namespace that PR generation consumes,
  which is a worse outcome than a missing one.
- Nothing downstream in this run needs it. §4.4's `base_change` takes a change id, not a
  bookmark. `task-record.json`'s `base.bookmark` becomes `null`, which is honest.

**What it costs.** §Recovering from a lost turn's `jj abandon` predicate is defined against
"the newest bookmark on the current stack". With the base unbookmarked, that anchor is now
`pr/…/step03/task-01-….code-task`, one change lower, so the abandon-eligible set widens to
include the bookkeeping commit. Bounded and reconstructable, but it is a real, if small,
loss of the safety margin that predicate was written to provide — and it is *silent*: the
predicate still evaluates, just against a lower anchor.

**Fix the skill should carry:** either (a) §4.7 bookmarks its commit under a sixth name
(`pr/awo-record-{slug}-step{NN}-task-{MM}`), which also restores the abandon anchor and
makes bookkeeping resumable in F-39's sense; or (b) §4.1 drops the "create one" fallback and
says the base may legitimately be unbookmarked, and §Recovering's predicate is re-anchored
on something that is not a bookmark. I prefer (a) — it is one line, it is consistent with
every other artefact this skill produces, and it makes the abandon predicate true again.

**Severity: medium-high.** It cannot destroy work by itself, but it is a MUST that is
unsatisfiable as written on every task after the first, so *every* future run must either
deviate here or pollute the PR bookmark namespace.
**Confidence: high** that the contradiction is real (observed, not reasoned); **medium** on
which fix is better.

## §4 — Step 3, Task 02: add-authority-declaration-lattice

Task file: `.agents/tasks/2026-08-04-compositional-component-analysis/step03/task-02-add-authority-declaration-lattice.code-task.md`
Run dir: `.agents/runs-acpx/20260903T193344Z-step03-task-02-add-authority-declaration-lattice/`

### §4.1 / §4.2

- `@` empty and childless ✓ (`vroypskv 3e06f8a1`).
- Base recorded via `scripts/jj-change-id.sh --repo "$PWD" @-` →
  `orxzvxlkoqpnuuqwputlzrwtmoulvxyl` (full 32 chars, read not retyped — RUN 2's F-36).
  The script does exactly what F-36 asked the skill to provide, and it is now the only
  way I obtained a change id in this run. **F-36 fixed, verified.**
- Base bookmark: **none** — see F-41. `task-record.json` records `"bookmark": null`.
- `task-record.json` created at the §4.2 schema.

### Round 0 — implementer (opencode / opencode-go/glm-5.3-flash / no effort)

`acpx-open.sh` — **first ever execution of this wrapper.** 2.4 s, exit 0:

```
[acpx] created session awo-impl-…-step03-task02 (ses_f973ca5a3ffeBTmfsMsbr9ua0z)
session record: /home/xtof/.acpx/sessions/ses_f973ca5a3ffeBTmfsMsbr9ua0z.json
model=opencode-go/glm-5.3-flash reasoning_effort=None
opened awo-impl-…-step03-task02 (opencode) in /home/xtof/…/architectural-contracts
```

It verified the model against the session record on disk and passed. Behaved exactly as
§Sessions and `scripts/README.md` describe. One cosmetic wart — F-42.

### F-42 — `acpx-open.sh` prints Python's `None` for an unset effort

With `effort: null` (the implementer role) the script prints
`model=… reasoning_effort=None`. That is `repr(None)` leaking out of the verification
heredoc. It is **correct** — no `set reasoning_effort` was issued, which is what §Role
Configuration's `effort: null` means — but `None` is not a value any acpx surface uses,
and an operator scanning the line could reasonably read it as "the adapter reports an
effort literally named None" and go looking for a bug. `(unset)` would say what happened.
**Severity: cosmetic.** No action taken.
**Confidence: high** (read the script; `effort` is `opts.get(...) or …` which yields
`None`, and the f-string renders it).

Prompt: §4.3 template **verbatim**, including the required incremental-commit paragraph.
Launched as a background task, no `--timeout`, `--format json` (wrapper defaults).
15-minute supervision timer armed at launch.

**Round 0 implementer result.** `acpx-prompt.sh` exit **0**, `stopReason=end_turn`.

- Wall **759 s (12m39s)**. Tool calls 394, assistant text 1020 chars.
- Tokens: `inputTokens=1574 outputTokens=164 totalTokens=74122 cachedReadTokens=72384`
- **No compaction.** The wrapper's `"ontext compacted"` detector did not fire and no
  compaction string appears in `assistant.txt`. Recorded as a result, per §Prompting.
- Headroom: `totalTokens=74122`. Percentage **not evaluable** — see F-37; no context-window
  figure exists for the opencode harness. On any plausible window this is not close.
- The turn finished inside the first supervision interval, so **no `acpx-progress.sh`
  check-in was reached on this round**. The 15-minute timer was armed at launch and
  cancelled unused. First-execution coverage of the supervision loop is therefore still
  outstanding after this round.

**§Validation Posture, post-implementation — all four checks:**

| Check | Result |
|---|---|
| `@` empty and childless | ✓ `tkykompn`, empty, `jj log -r '@+'` returns nothing |
| `@-` non-empty, described, unbookmarked | ✓ `srwvxuvy` *build(manifest): add authority sources to Bazel BUILD files* |
| `@-` change id matches `result.change_id` | ✓ **exact**, `srwvxuvyrotqlrpuprpvlvqmuqtqsntz` — not a prefix match |
| base still an ancestor of `@`, id unchanged | ✓ `orxzvxlk…` present in `ancestors(@,8)` |

All six change ids (base + five produced) run through
`jj-change-id.sh --check` → six `ok`, rc 0.

**The incremental-commit paragraph worked, and produced five changes, not four:**

```
srwvxuvy build(manifest): add authority sources to Bazel BUILD files      <- @-
wqonwuqw feat(manifestparity): compare the authority declaration between manifests
pzwznmux feat(manifest): parse the persisted authority axis into the native model
xsurzmsp feat(manifest): add AuthorityDeclaration lattice with total join
vroypskv feat(schema): add authority enum to component manifest proto
orxzvxlk chore(awo): record bookkeeping for step03 task 01                <- base
```

### F-43 — the implementer's own count of its changes was wrong, and nothing checks it

`assistant.txt` and `result.yaml`'s `notes` both say *"Four coherent jj changes were
produced"*. There are **five**. The extra one is `vroypskv`, which was the empty working
copy `@` at the moment I launched the turn: the implementer described it and committed on
top, so its first "new" commit is actually the working copy it inherited. From the
implementer's point of view it created four commits; from the repository's point of view
the produced series is five changes long.

This matters because **`produced_changes` is derived by me, not by the producer**, and
§4.4 requires it to be complete. Had I taken the implementer's word for the count and
listed four, `vroypskv` — the change that adds the proto enum, i.e. the schema change the
whole task rests on — would have been outside the reviewed range while `base_change` still
pointed below it. The review would not have errored; it would have silently reviewed a
range whose first commit it had not been told about.

I derived the series from `jj log -r 'orxzvxlk::@- ~ orxzvxlk'` instead, which is
authoritative. But the skill never says to do that: §4.2 says "append each produced change
ID … **as it is created**", which is not something an orchestrator can do while a
background turn is running and forbidden from touching the repo (§Supervising: "You MUST
NOT touch the repository while a turn is in flight"). So the *only* time you can populate
`produced_changes` is after the turn, from the log, and §4.2's wording actively misdirects.

**Severity: medium-high**, and it is the same failure class as RUN 2's F-36 — a silently
mis-scoped review through an id list nobody validated.
**Fix the skill should carry:** §4.3/§4.4 should say `produced_changes` is
`{base}::{@-} ~ {base}`, read from `jj log` after the turn, and must never be taken from
the producer's prose or count. §4.2's "as it is created" should be dropped; it describes an
access pattern §Supervising forbids.
**Confidence: high** — the discrepancy is directly observed, and the consequence follows
from §4.4's own warning that an unresolvable/incomplete range is silent.

### Round 0 — reviewer (codex / gpt-5.6-luna / max)

`acpx-open.sh` verified `model=gpt-5.6-luna reasoning_effort=max` against the session
record before the turn. **This is the fix for RUN 2's F-31** — where two review turns ran
at `high` while `status -s` claimed otherwise — moved from prose into an executable check
at the one moment it can be made. Verified working on first execution.

Prompt: §4.4's initial-review template verbatim, with all six ids as full 32-character
forms taken from `jj-change-id.sh`, all `--check`ed before use.

**Round 0 reviewer result.** `acpx-prompt.sh` exit **0**, `stopReason=end_turn`.

- Wall **670 s (11m10s)**. Tool calls 237, assistant text 438 chars.
- Tokens: `totalTokens=194812 inputTokens=1181 cachedReadTokens=193280 outputTokens=351
  thoughtTokens=227`
- **No compaction.**
- Headroom: 194 812 / 850 000 = **22.9 %** of the codex window. Below the 50 % flag. First
  evaluation of the headroom rule in any run; it is evaluable for codex and it passed.
- Turn finished inside the first supervision interval again — **the 15-minute check-in loop
  is still unexercised after two turns.** See F-45.

**§Validation Posture, post-review:** `round-0.pre-review.topology` vs
`round-0.post-review.topology` — `diff` reports **no difference** across all eight
revisions (change id, commit id, bookmarks, description). `jj st` clean. The reviewer did
not touch the repository. ✓ This is the first run in which the snapshot-and-diff was done
mechanically rather than by eyeballing `jj log`; it took two commands and is the cheapest
check in the skill.

**Verdict: `approved`**, first round, 6/6 acceptance criteria `pass`, 1 `suggestion`, 0
important/critical. `review.change_id` = `srwvxuvyrotqlrpuprpvlvqmuqtqsntz` = `@-`. ✓

**Degradation check (§Troubleshooting: "a zero-finding approval arriving right after a run
of `changes_requested`").** This is a *round-0* approval, not a post-rework one, so the
pattern that section warns about does not apply. I applied its test anyway: every one of
the six criteria cites concrete `file:line` evidence
(`manifest.go:231-245`, `authority.go:76-87`, `authority.go:57-74`, `schema_test.go:23-61`,
…), and the one finding it did raise is a real defect I verified myself —
`authority_test.go:93` compares `&solo.Set` against `nil`, which cannot be nil for the
address of a local, so the one-sided alias case the comment claims to test is not tested.
It also independently counted the series as **five** changes, corroborating F-43 against
the implementer's "four". This is a real approval, not an asserted one.

### §4.6 finalize

- `@` empty ✓.
- Described the **oldest** produced change `vroypskv` with the approved review's
  `merge_request`. `jj describe` reported **`Rebased 5 descendant commits`** — exactly what
  §4.6 predicts, and every change id in the series is unchanged while every commit id below
  `@` was rewritten. The skill's insistence on comparing change ids and never commit ids is
  vindicated a second time.
- Bookmark `pr/2026-08-04-compositional-component-analysis/step03/task-02-add-authority-declaration-lattice.code-task`
  created on the **newest** produced change `srwvxuvy`, with `jj bookmark create`. Succeeded
  first time (no collision).
- Both sessions closed with `acpx-close.sh`; both printed their session id and `closed …`.
- `task-record.json` `outcome` written: `approved`, 0 rework rounds, open findings recorded.

### F-44 — §4.6's rewrite licence covers the body but not the title, which had the same defect (DEVIATION)

§4.6 grants: *"**You MAY rewrite that body** when it narrates the review instead of
describing the change"* — added in this revision in response to RUN 2's F-27. The licence
worked exactly as intended and was needed again: this reviewer's body opens

> *"Reviews the complete ordered five-change task series from the supplied base through the
> current change. … No rework round was present."*

which is reviewer voice, addressed to an orchestrator, and would have been permanently
attached to the commit as the PR description. I rewrote it in the change's own voice,
preserving every substantive claim including the open `suggestion` finding, which I carried
into a closing paragraph rather than dropping. **F-27 fixed; licence exercised and
sufficient — for the body.**

It is not sufficient for the **title**. The reviewer emitted:

```
feat(manifest): add persisted authority lattice and parity [Authority Lattice: Step 03/Task 02]
```

`[Authority Lattice: …]` is a project name the reviewer invented. Every other commit in
this plan uses `[Compositional Analysis: Step NN/Task MM]` — including task 01, three
changes below it. §4.6 says to use `merge_request.title` and grants no licence to touch it.

**Deviation, declared:** I changed the bracketed tag to
`[Compositional Analysis: Step 03/Task 02]` and left the rest of the title verbatim.
Reasoning: the defect is identical in kind to the one the body licence exists for — the
reviewer writing in its own frame of reference rather than the change's — and the tag is
consumed by humans scanning `jj log` for a plan's commits, where a one-off project name
silently breaks the grouping. The licence's own limit ("for voice and readability, not for
content") is respected: no substantive claim was altered.
**Confidence: high** that the fix is right; **medium** that deviating was better than
applying it verbatim and filing the finding. A stricter reading of §4.6 would have applied
it as written, and RUN 2's F-27 records exactly that choice being made and regretted.
**Fix the skill should carry:** extend §4.6's licence to the title, with the same "voice
and readability, not content" limit, and name the specific failure — a reviewer inventing a
project tag that does not match the planning slug's established convention.

### §4.7 — first execution on a task actually run by this orchestrator

Copied `task-record.json`, `round-0.result.yaml`, `round-0.review.yaml` into
`.agents/awo/runs/2026-08-04-compositional-component-analysis/step03/task-02-add-authority-declaration-lattice/`.
No `kill-evidence/` (no lost turns). `jj st` showed the three files as `A`, confirming
again the path is tracked. Committed as `tkykompn 822fd86f`
*chore(awo): record bookkeeping for step03 task 02*, containing nothing else, unbookmarked.
`@` empty afterwards. **§4.7 works as written**, subject to F-41.

### §4.8 — task summary

| | |
|---|---|
| Task | `step03/task-02-add-authority-declaration-lattice.code-task.md` |
| Outcome | **approved**, round 0, **0 rework rounds** |
| Produced changes | `vroypskv`, `xsurzmsp`, `pzwznmux`, `wqonwuqw`, `srwvxuvy` (5) |
| Bookmark | `pr/…/step03/task-02-add-authority-declaration-lattice.code-task` on `srwvxuvy` |
| Implementer | 759 s, `total=74122 cached=72384`, no compaction |
| Reviewer | 670 s, `total=194812 cached=193280`, no compaction, 22.9 % of window |
| Total agent wall | **23m49s** |
| Deferred | 1 `suggestion` — `authority_test.go:93` impossible nil check |

**Prototype-evaluation observations for this task:**
- **Implementer context across rework rounds: no data.** The task approved on round 0, so
  §4.5 never ran. This run has produced zero evidence about the prototype's central
  hypothesis so far, which is worth stating plainly rather than letting the absence pass.
- **Reviewer continuity across rounds: no data**, same reason.
- Both sessions therefore ran exactly one turn each. Every claim this run can make about
  long-lived sessions is a claim about *opening, pinning and closing* them, not about
  reusing them.

## §4 — Step 3, Task 03: define-persisted-artifact-schemas

Base `tkykompnzyuvxxvxnkmlwzxyvosrsrnt` (the task-02 bookkeeping commit — F-41 again, no
bookmark). Run dir
`.agents/runs-acpx/20260903T200114Z-step03-task-03-define-persisted-artifact-schemas/`.

### Round 0 — implementer turn KILLED at 17 seconds

`acpx-open.sh` opened `awo-impl-…-step03-task03` and verified the model. The turn was
launched at 20:01:22Z. At 20:01:39Z the **orchestrating harness killed both backgrounded
bash calls simultaneously** — the `acpx-prompt.sh` call *and* an unrelated `sleep 900`
supervision timer that had nothing to do with acpx. Wrapper stdout: empty, `[killed]`.
No `stopReason`, no token line. This is RUN 2's F-30 vector recurring, and the fact that a
bare `sleep` died with it rules out acpx, the adapter, and the wrapper as the cause.

**Recovery, per §Recovering from a lost turn:**

1. Did not touch the repository. Ran `acpx-progress.sh` first, as the section requires.
2. Confirmed dead by four independent signals: no `opencode` or `acpx` process alive at
   all; `pid: -`, `status: idle`; `lastExitAt 20:01:39.145Z`,
   `disconnectReason: pipe_close`; and the ACP wire log **frozen** at 20:01:39, polled
   every 10 s for 90 s with zero growth.
3. Captured evidence into `round-0.implementer/kill-evidence/` — `out.json`, `out.err`,
   `sessions show`, `status -s`, a 50-line wire-log tail, `jj st`, `jj diff --stat`,
   `jj log`, and a `NOTES.md` stating the timeline.
4. Repository state: **untouched**. `jj st` clean, `jj diff --stat` 0 files, and the newest
   `jj op log` entry is still my own §4.7 commit. The turn died during exploration — 28
   tool events, all reads and greps, **0 assistant message chunks**. It left neither
   committed nor uncommitted work, so §Recovering's `jj abandon` predicate and its
   `wip(...)` commit rule both correctly did not apply. Nothing to preserve.
5. The loss does **not** consume a `max_rework_rounds` slot (§Recovering). Round 0 is
   re-run, not charged.

### ★★ F-45 — §Recovering's "poll until it reports 3 (idle)" can never be satisfied for a killed turn

§Recovering from a lost turn: *"You MUST first confirm the turn is actually over, with
`acpx-progress.sh`. Never act on a turn that is still producing events. **Poll until it
reports `3` (idle).**"*

`acpx-progress.sh` returns 3 in exactly two cases, and a killed turn produces neither:

| Exit-3 condition in the script | Killed turn |
|---|---|
| the wire log path is empty or the file does not exist | the wire log **exists** — the turn ran and wrote 380 KB to it |
| `--out-dir`'s `out.json` contains a `"stopReason"` | it does not — **that is the definition of a killed turn** |

Everything else falls through to the age test: `WIRE_AGE <= idle-warn` → **0 (WORKING)**,
otherwise → **1 (STALLED)**. So for a turn that has been dead for 90 seconds the script
says **WORKING**, and it will keep saying WORKING for 15 minutes, then say STALLED forever.
It never says idle.

Directly observed: with the adapter process gone, `pid: -`, and the wire log frozen for 90
seconds, `acpx-progress.sh` printed `verdict: WORKING` and exited **0**.

Follow the two sections literally and the cost compounds. §Recovering blocks until exit 3,
which never comes. §Supervising says on `1` (stalled) *"check once more after another 15
minutes. If it is still stalled with the same last tool, **stop and ask**"* — so the
literal path is: 15 minutes of false WORKING, then 15 minutes of STALLED, then halt the run
and wake the user, for a turn that was provably dead within 20 seconds by four signals the
script never consults. **Thirty minutes of dead waiting and a spurious stop-and-ask, on
what the skill itself calls the common failure.**

The irony is that `acpx-progress.sh` *collects* the disambiguating evidence and then throws
it away: it reads `status -s`'s `pid` field and prints it, labelled *"advisory only — not a
liveness test"*. That label is right about `status: running` — RUN 2's F-31 and the
script's own header document `running` being reported for a dead turn. But it is wrong in
the other direction. **`pid: -` with a wire log that has not grown is not advisory; there
is no process left to produce an event.** The script generalised one true asymmetry into a
false symmetry.

**Deviation, declared: I treated the turn as over without ever seeing exit 3.** I could not
have done otherwise — the exit code is unreachable. The evidence I used instead:

1. `ps` shows no `opencode` and no `acpx` process at all;
2. `status -s` reports `pid: -`;
3. `sessions show` reports `lastExitAt 20:01:39.145Z` — an *exit*, not a disconnect-in-flight;
4. the wire log's size and mtime unchanged across 6 polls over 90 s.

(3) is worth separating from the kill-signature warning §Deciding whether a turn finished
gives. That section is right that `disconnectReason: pipe_close` + a `lastExitAt` appears
on a healthy just-configured session. But here `lastExitAt` is **after** `lastPrompt`
(20:01:39 vs 20:01:22) and there is no live pid, which the healthy-session case cannot
produce. The skill treats the signature as uninformative; it is uninformative *in
isolation*, and informative when ordered against `lastPrompt`.

**Fix the skill should carry:** `acpx-progress.sh` needs a fourth verdict — *dead*: no
live pid **and** wire-log age above a short threshold (30–60 s, not 900) **and** no
`stopReason`. That is a sound, cheap, deterministic test, and it is the single check that
turns a 30-minute stall-and-halt into a 60-second recovery. Until it exists, §Recovering's
"poll until 3" should be rewritten to say what evidence actually establishes death.

**Severity: high.** It does not destroy work — it wastes it, and it fires *toward halting a
healthy run*, which is the failure mode §Sessions explicitly says it is trying to avoid.
**Confidence: high.** The exit-3 unreachability is read directly off the script's control
flow and confirmed by observing `WORKING` on a turn with no process behind it.

### F-46 — the harness kill vector is unchanged from RUN 2, and now killed a bare `sleep`

RUN 2's F-30 recorded the orchestrating harness killing a background call at 141 s. This
one died at **17 s**, and took a completely unrelated `sleep 900` with it in the same
instant. That rules out acpx, the adapter, the wrapper and the turn's own behaviour: it is
the harness reaping background tasks. Nothing in the skill can prevent it, and
§Operating Constraints' advice ("run it in the background and supervise it") is already
the mitigation — the background call is what gets killed.

The one thing the skill *can* do, it already does: §4.3's incremental-commit paragraph.
Here it made no difference because the turn died in exploration, but it is what turned RUN
2's 65-minute loss into a 0-minute one.

**Loop-guard accounting (§Recovering).** One automatic recovery, cause **undiagnosed** —
I can characterise it (harness-level, kills all background tasks, not acpx) but I cannot
name the trigger or a fix. Per the guard, this is my one free recovery on this round. **If
round 0 of task 03 is killed again, I stop and ask** rather than retrying.

**Recovery action:** fresh session `awo-impl-…-step03-task03b` per §Recovering ("A lost turn
is never resumed"), same §4.3 prompt. No resume-and-verify paragraph is needed — unlike RUN
2's F-29 case there is no partial work to distrust, because there is no partial work.

### Round 0b — implementer (fresh session `…-task03b`, restart after the kill)

`acpx-prompt.sh` exit **0**, `stopReason=end_turn`.

- Wall **625 s (10m25s)**. Tool calls 280, assistant text 816 chars.
- Tokens: `inputTokens=1611 outputTokens=137 totalTokens=68116 cachedReadTokens=66368`
- **No compaction.** Headroom: not evaluable (F-37); on any plausible window, far below.
- Turn finished in 10m25s — **under the 15-minute interval for the third time running.**
  See F-47.
- Cost of the kill: **17 seconds of agent work**, no repository damage, one wasted session
  open/close. The recovery itself cost about four minutes of orchestrator time, almost all
  of it establishing death against a script that would not say so (F-45).

Produced two changes:

```
pvysxzts test(archcontracts): add descriptor-level schema tests for surface and stdlib map  <- @-
mvzpmomu feat(proto): add surface and stdlib-map persisted artifact schemas
tkykompn chore(awo): record bookkeeping for step03 task 02                                  <- base
```

**§Validation Posture, post-implementation:** `@` empty and childless ✓; `@-` described and
unbookmarked ✓; base still an ancestor with an unchanged id ✓; all three ids resolve ✓.
`result.change_id` is `pvysxzts` — an **8-character prefix** this time, not the full id
task 02's implementer emitted. §Validation Posture's prefix-containment rule covers it and
`jj-change-id.sh --check` resolved it; no rework round was spent on a string. The rule is
doing its job, and the two tasks together show the producers are genuinely inconsistent
about id length within a single step, which is why the rule is needed.

**F-43 follow-up.** The same situation recurred — the implementer again inherited the
empty working copy `@` and committed into it — but this time it counted correctly ("Two
incremental commits", and there are two). So the producer's count is not *biased*, it is
*unreliable*: it was wrong on task 02 and right on task 03 under identical conditions.
That strengthens rather than weakens F-43: `produced_changes` must be derived from
`jj log`, because there is no way to tell from the outside which kind of count you got.

### Round 0 — reviewer (codex / gpt-5.6-luna / max), fresh session

Opened and verified at luna/max. Prompt: §4.4 initial-review template verbatim, full
32-character ids for `base_change` and both `produced_changes` entries, `current_change`
given as the full form of the prefix the implementer reported. All `--check`ed.

### Round 0 reviewer — KILLED at 19 seconds. Second loss on the same round.

Identical signature to the first. `lastPrompt 20:15:49.058Z`, `lastExitAt 20:16:08.838Z` —
**19 seconds**. Wrapper stdout empty, `[killed]`, no `stopReason`. 4 tool events, 0
assistant message chunks; the reviewer had barely begun. `pid: -`, wire log frozen at
20:16:08 across 6 polls over 60 s.

Repository: untouched. `jj diff --stat` 0 files; the pre/post-review topology snapshots
`diff` clean across all six revisions. Nothing to recover. Evidence in
`round-0.reviewer/kill-evidence/`.

**F-45 reproduced exactly.** With the adapter process gone and the wire log dead for 108
seconds, `acpx-progress.sh` printed `verdict: WORKING` and exited **0**. Second independent
observation; the finding is not a one-off.

### F-47 — the 15-minute supervision loop is *still* unexercised after five turns

Turn durations this run: 759 s, 670 s, 17 s (killed), 625 s, 19 s (killed). Every turn that
completed did so in **10–13 minutes**, under `turn_check_interval` (900 s). Not one
`acpx-progress.sh` check-in was ever *triggered by the schedule*; every invocation of it in
this run was a kill investigation.

So the check-in loop remains untested for its actual purpose, and the reason is
structural rather than accidental: the skill's own §Supervising says *"A real
implementation turn runs for tens of minutes; the longest observed was 65"*, and §Prompting
warns about turns of that length — but on this codebase, with this role config, the
observed distribution is 10–13 minutes for both roles. **A 900-second interval on a
650-second turn samples nothing.** RUN 2's turns ran 3–23 minutes; combined, 12 of 13
completed turns across both runs would have produced at most one check-in.

The `turn_check_interval` default is not obviously wrong — it is tuned for the 65-minute
outlier, which is the case where supervision actually matters. But the skill presents
check-ins as a routine part of every turn (§Supervising: *"Record each check-in in
`work_log` as one line … Those lines are how a run's real cost is reconstructed
afterwards"*), and in practice they essentially never happen, so that reconstruction never
materialises. The per-turn wall-clock and token lines are doing all of that work.

**Severity: low**, but it means the supervision path has now survived three runs without
being exercised on a healthy turn, and any confidence in it is untested confidence.
**Suggested change:** either drop the interval to ~300 s so the loop actually runs and its
output can be evaluated, or say plainly that check-ins are an exception path for long turns
and that per-turn token/wall lines are the routine record.
**Confidence: high** on the observation; **low** on which change is right.

### F-48 — the loop guard's "per round" is ambiguous, and the abort path contradicts itself

Two questions the skill does not answer, both of which I had to decide:

**(a) Is an implementer kill and a reviewer kill "the same round"?** §Recovering: *"at most
one automatic recovery per round from an undiagnosed cause. A second loss on the same round
is stop-and-ask."* Round 0 of task 03 contains two turns in two different sessions with two
different agents. Read as "round" = one implement/review cycle, these are the same round and
I must stop. Read as "round" = one turn, they are different and I may recover again.

I took the **first** reading: the skill counts rounds, not turns, everywhere else — §4.5 is
"Rework Round", `max_rework_rounds` counts implement+review cycles, and `rounds[]` in
`task-record.json` holds both roles under one round number. **So: stop and ask.** I am
moderately confident this is what the skill means and less confident it is what the skill
*wants* — a reviewer turn can be re-run at zero cost and zero risk, because the reviewer
does not write to the repository, so the guard's stated purpose ("stop an orchestrator
grinding against a flake it does not understand") is served by a much weaker rule for
reviewer losses than for implementer ones.

**(b) Sweep or leave open? (DEVIATION.)** §5.1: *"You MUST run
`acpx-close.sh --sweep` … on **every** abort path, including stop-and-ask."* §E.2, for its
own stop-and-ask: *"**Leave both sessions open** — the user may want you to resume."* These
are directly contradictory for a mid-task stop, and a mid-task stop is exactly what this is.

**What I did, declared as a deviation from §5.1:** a *partial* sweep.

- **Closed** `awo-rev-…-step03-task03` — its adapter is already dead and §Recovering
  forbids resuming a lost turn anyway, so the session holds nothing worth keeping.
- **Left open** `awo-impl-…-step03-task03b`. Its adapter is **alive** — `opencode acp`
  pid 1045029, up since 20:04 — holding the whole task's context. Closing it would destroy
  the one thing this prototype exists to measure, in exchange for freeing one process, on
  an abort where the user may well say "just re-run the review".

  (Incidentally this is the run's cleanest confirmation that `--ttl 0` does what
  `scripts/README.md` claims: the implementer's adapter is still resident 14 minutes after
  its turn ended, where the default `ttl: 300` would have reaped it at 5 minutes. The
  claim is verified — **and so is its price**: that process only goes away because I close
  it.)

I recorded the open session prominently below so it cannot be silently orphaned.
**Confidence: high** that a full sweep would have been wrong here; **medium** that a
partial one is defensible rather than simply a violation.
**Fix the skill should carry:** §5.1's sweep should be scoped to *step-boundary and
end-of-run* aborts, and a mid-task stop-and-ask should adopt §E.2's rule — close what is
dead, keep what still holds context, and name the open sessions in `work_log`.

---

# RUN 3 STOP — stop-and-ask, per §Recovering's loop guard

**Why:** two turn losses on round 0 of step 3 task 03, from an **undiagnosed** cause, which
§Recovering makes a stop-and-ask condition.

**What I know about the cause.** The orchestrating harness kills the backgrounded call
~17–19 seconds after launch. It is not acpx, not `--timeout` (the wrappers never pass one),
not the adapter, and not the turn's own behaviour: the first kill took an unrelated
`sleep 900` with it in the same instant. Five turns were launched identically through
`acpx-prompt.sh`; three ran 10–13 minutes to a clean `stopReason=end_turn`, two died at
~18 s. I could not find a structural difference between the two groups — the presence of a
second background task, the launch order, and the agent (opencode vs codex) are all
distributed across both. I cannot name a fix, which is precisely the condition the guard
covers.

**Repository state — clean, mid-task.**

```
mpvsulpl (empty)                                                      <- @
pvysxzts test(archcontracts): descriptor-level schema tests …         <- @-, task 03 tip
mvzpmomu feat(proto): surface and stdlib-map persisted artifact schemas
tkykompn chore(awo): record bookkeeping for step03 task 02            <- task 03 base
srwvxuvy build(manifest): add authority sources …  pr/…/step03/task-02-….code-task
…
```

`jj st` clean, `@` empty and childless, no stray files, nothing abandoned, no `jj undo`
used, every change reachable and described.

**Where the loop is** (in F-39's bookmark terms):

| | |
|---|---|
| Step 3 §2 | done, `pr/awo-generate-task-…-step-3` |
| task 01 | approved, bookmarked, §4.7 recorded |
| task 02 | **approved this run**, bookmarked, §4.7 recorded |
| task 03 | implementation committed (`mvzpmomu`, `pvysxzts`), **not reviewed**, not described, **not bookmarked** |
| tasks 04–06 | not started |
| §5.1–§5.3 | not reached |

**Open acpx session, deliberately not swept:**
`awo-impl-2026-08-04-compositional-component-analysis-step03-task03b` (opencode, adapter
pid 1045029 alive). Everything else `awo-*` is closed.

**To resume:** re-open a reviewer session for task 03 and re-issue the §4.4 initial-review
prompt with `base_change: tkykompnzyuvxxvxnkmlwzxyvosrsrnt`, `current_change:
pvysxztskmkkkzpzovrrmsnzwytxwzrs`, `produced_changes: [mvzpmomuwypumvxkqxpoyksutnooxrvr,
pvysxztskmkkkzpzovrrmsnzwytxwzrs]`. The prompt is already written at
`round-0.reviewer/prompt.md`. Neither loss consumed a `max_rework_rounds` slot.

---

# RUN 3 — kill-vector investigation (user directed: "investigate the kill vector first")

The stop-and-ask above went to the user, who chose investigation over any retry. What
follows is not part of the skill's loop; it is diagnosis of the environment the skill runs
in, because §Recovering's loop guard cannot be lifted honestly without it.

## The hypothesis

I had been looking for a *structural* difference between the killed and surviving launches
— concurrent background-task count, launch order, which agent, whether a Monitor was armed
— and every one of those is distributed across both groups. So I looked at the clock
instead.

- kill 1: `lastExitAt 20:01:39`
- kill 2: `lastExitAt 20:16:08`
- **Δ = 14 m 29 s.**

Projecting that period backwards and forwards gives a reap schedule of …19:32:41, 19:47:10,
20:01:39, 20:16:08, **20:30:37**, 20:45:06… Every one of the five turns fits it exactly:

| Turn | Ran | Reap boundaries either side | Outcome | Fits? |
|---|---|---|---|---|
| task02 impl | 19:33:57 → 19:46:43 (759 s) | 19:32:41 / 19:47:10 | survived | ✓ finished 27 s before a reap |
| task02 rev | ~19:48:55 → 19:59:5x (670 s) | 19:47:10 / 20:01:39 | survived | ✓ |
| task03 impl | 20:01:22 → **20:01:39** (17 s) | — / **20:01:39** | **killed** | ✓ launched 17 s before a reap |
| task03b impl | 20:04:47 → 20:15:12 (625 s) | 20:01:39 / 20:16:08 | survived | ✓ entirely inside one window |
| task03 rev | 20:15:49 → **20:16:08** (19 s) | — / **20:16:08** | **killed** | ✓ launched 19 s before a reap |

Five for five, including both kills predicted to the second and all three survivals
explained as *phase luck* rather than as anything the turns did differently.

**Hypothesis: the orchestrating harness reaps backgrounded tasks on a periodic schedule
(~14.5 min here), killing whatever is in flight when it fires.** A turn's survival is then a
function of *when it was launched relative to the phase*, not of its own duration or
behaviour — which is exactly why no structural difference was findable, and why the same
`acpx-prompt.sh` invocation succeeded three times and died twice.

This also retro-explains RUN 2's F-30, where a background call died at 141 s "without an
error": that run attributed it to an out-of-range harness timeout on the call itself. Under
this hypothesis the 141 s was simply the remaining phase.

## The test

It is 20:29:43. The next predicted reap is **20:30:37**, 54 seconds away. I launched a
trivial heartbeat — `for i in seq 1 400; do echo beat; sleep 3; done`, ~20 minutes of
runtime, nothing to do with acpx or jj — as a background task at ~20:29:50.

Predictions, stated before the result:
- **If the hypothesis holds:** the heartbeat is killed within ~60 s of launch, at ≈20:30:37,
  having logged ~15 beats, with no `CLEAN_EXIT` line.
- **If it is wrong** (per-call timeout, output-volume, concurrency limit): the heartbeat runs
  on well past 20:31, since it is a single task producing three bytes every three seconds.

A kill at ≈20:30:37 would confirm a *global periodic reaper* and rule out every per-call
explanation at once, because this call shares nothing with an acpx turn but its
backgroundedness.

## The result: hypothesis FALSIFIED

The heartbeat ran **20:29:49 → 20:49:50, all 400 beats, `CLEAN_EXIT`, zero gaps greater
than 6 seconds** — straight through the predicted reap at 20:30:37 (54 s after its launch,
the tightest possible test) and through 20:45:06 as well.

There is **no periodic background-task reaper.** A backgrounded call can run twenty minutes
untouched. The 14 m 29 s that fit all five turns so neatly was coincidence, and I should
record how easily it fooled me: five out of five data points, both kills predicted to the
second, and the three survivals "explained". It was the best-fitting wrong answer I have
produced in this run, and the only reason it did not become the run's conclusion is that it
made a cheap falsifiable prediction and I ran it before writing it up as fact. A structural
hypothesis (concurrency, ordering, agent) would have been much harder to kill.

### F-49 — what the kill vector is, and is not

**Ruled out by evidence:**

| Explanation | Ruled out by |
|---|---|
| Periodic global reaper | the heartbeat spanning two predicted reaps cleanly |
| Per-call duration limit | a 20-minute background call completing normally |
| Concurrency limit on background tasks | two concurrent tasks survived (task02 rev + its timer) and two died (task03 impl + its timer) |
| acpx `--timeout` | the wrappers never pass one; and a `sleep 900` with no acpx involvement died in the same instant |
| The adapter, the model, or the turn's own behaviour | same wrapper, same prompt shape, same agents; three survived, two died |
| Anything the skill or `scripts/` controls | as above |

**What remains:** an **external, session-wide stop event** that terminates every in-flight
background task at once. That signature is unambiguous in kill 1 — the `acpx-prompt.sh`
call and a bare, unrelated `sleep 900` died at the same second — and it is the only
explanation left standing. The harness reported both with the same status wording it uses
for an explicit stop, not with a failure. I cannot determine from inside the session what
triggered it, and one later interrupt did **not** kill a running background task, so it is
not simply "any interruption".

**What this means for the skill.** The kill vector is real, it is outside acpx and outside
this skill, and it is not predictable from anything the orchestrator can observe *before*
launching a turn. Consequences:

1. **§4.3's incremental-commit paragraph is the only real mitigation, and it should be
   stated as such.** The skill currently justifies it with one anecdote; it is in fact the
   entire defence, because turn loss cannot be prevented, only bounded.
2. **F-45's missing "dead" verdict is what makes the loss expensive.** Both losses here cost
   ~18 s of agent work and roughly four minutes each of orchestrator time, essentially all
   of it spent proving death against a script that reports `WORKING`. Fix that and a loss
   costs seconds.
3. **§Recovering's loop guard should distinguish the roles it is protecting.** An
   *implementer* loss can leave unvalidated partial work, which is what the guard's caution
   is for. A *reviewer* loss cannot: the reviewer does not write to the repository, the
   topology diff proved it, and re-running it is idempotent. Counting a reviewer kill
   against the same one-recovery budget as an implementer kill is what turned a zero-risk
   19-second flake into a full run halt. **The guard should be per-role, or at minimum
   should not count losses on turns that provably left the repository unchanged.**

**Confidence:** high that the listed causes are ruled out — each rests on a direct
observation, not on reasoning. Medium-low on "external session-wide stop" as the positive
identification: it is the last hypothesis standing rather than one I confirmed, and I could
not reproduce it on demand.

## Resuming — declared override of §Recovering's loop guard

The user was asked and chose to resume. Recording the override explicitly, because it is a
MUST I am setting aside:

> §Recovering: *"A second loss on the same round is stop-and-ask **unless** you have
> diagnosed the cause and can name the specific fix."*

I have **diagnosed** the cause (F-49: external, session-wide stop; every mechanism inside
acpx, the wrappers and the skill ruled out by direct observation) but I **cannot name a
fix** — there is nothing to fix on this side. So the guard's escape clause does not
strictly apply and I am overriding it, with the user's approval, on this reasoning:

1. The lost turn was a **reviewer** turn. It wrote nothing — the pre/post topology
   snapshots diff clean — so re-running it cannot corrupt anything. The guard exists to
   stop an orchestrator grinding against a flake *while it damages state*; there is no
   state to damage here.
2. The failure is not correlated with anything the retry would repeat: three identical
   launches succeeded.
3. Per §Recovering, I declare the override and **stop unconditionally if it recurs** — no
   further retries on this round regardless of role.

Fresh session `awo-rev-…-step03-task03b` per §Recovering ("a lost turn is never resumed"),
same §4.4 prompt, unchanged ids.

### Round 0b — reviewer (fresh session `…-task03b`, retry after the kill)

`acpx-prompt.sh` exit **0**, `stopReason=end_turn`. The retry ran to completion.

- Wall **717 s (11m57s)**. Tool calls 123, assistant text 378 chars.
- Tokens: `totalTokens=187551 inputTokens=1262 cachedReadTokens=186112 outputTokens=177
  thoughtTokens=68`
- **No compaction.** Headroom **22.1 %** of 850 000. Below the flag.
- Topology diff pre/post: **unchanged** across all six revisions ✓. `jj st` clean.

**Verdict: `changes_requested`** — 6/6 acceptance criteria `pass`, but **1 `important`**
finding, `category: architecture`:

> *"Generated schema package has no component ownership … There is no `go_component` or
> checked-in component metadata owning that package … This differs from the established
> generated-package pattern, where `go/internal/manifest/BUILD.bazel:56-95` explicitly lists
> `manifest/gen` as a component member. Consequently the new generated package is absent
> from the architectural ownership graph and the schema tests run only through native
> `go test`; **a green `bazel build //...` does not exercise the un-BUILDed test
> package.**"*

Worth pausing on. Every acceptance criterion passed and `just ci` was green, so a checker
routing purely on criteria and CI would have approved this. The reviewer instead noticed
that the *green build did not cover the new tests*, and located the established pattern it
should have followed by pointing at a sibling BUILD file's line range. That is the class of
finding §Role Configuration's "spend capability on the task reviewer" argument predicts, and
it is the second run in a row where luna/`max` produced a finding that no acceptance
criterion would have caught. On this repository — a tool whose entire subject is
architectural ownership of Go packages — a generated package outside the ownership graph is
close to the worst kind of silent drift.

**Note against F-47:** this reviewer turn ran 717 s, the longest of the run, and *still*
finished under the 900 s check-in interval.

### `--ttl 0` verified across a 67-minute idle gap

Before the rework prompt I checked the implementer's adapter. `opencode acp` **pid 1045029,
ELAPSED 01:17:20**, last prompted at 20:04:44 — i.e. resident and idle for **67 minutes**,
across the kill, the stop-and-ask, the whole kill-vector investigation, and a user
round-trip. Under the harness default `ttl: 300` it would have been reaped at 5 minutes and
the next turn would have paid RUN 2's ~348k-token uncached replay (F-32).

`scripts/README.md`'s `--ttl 0` claim is **verified**, and so is the price it names: nothing
reaps it but me.

Incidentally `acpx status -s` reported `status: running` for this session with **no turn in
flight** — exactly the false positive §Deciding whether a turn finished warns about, here
observed in its benign direction. Third independent confirmation that `status` reports
adapter residency, not turn activity.

### Round 1 — rework, SAME implementer session, §4.5 template verbatim

This is the prototype's central hypothesis and the first time this run has reached it. The
session has been idle 67 minutes and holds the task, its exploration, its plan and its own
two commits. The prompt restates **nothing** — no task, no skill, no summary of prior work,
no mention of what it built. It names a review path and asks for a fresh commit. Sent
exactly as §4.5 writes it.

**Round 1 rework result.** `acpx-prompt.sh` exit **0**, `stopReason=end_turn`.

- Wall **569 s (9m29s)**. Tool calls 206, assistant text 1108 chars.
- Tokens: `inputTokens=536 outputTokens=148 totalTokens=95404 cachedReadTokens=94720`.
  `cachedReadTokens` grew 66 368 → 94 720 within the session, monotonically, as
  §Prompting says it should. No compaction.
- Fresh child `mpvsulplnwprozwkqywtmnymxkqzwnpt`; `pvysxzts` and `mvzpmomu` both still
  present in `jj log` and still ancestors of `@-` ✓ — no rewrite (§4.5's MUST).
- `@` empty and childless ✓.

**★ The continuity hypothesis: held, and the prompt restated nothing.** The session had
been idle 67 minutes. Its first sentence back was:

> *"The reviewer's finding: the new gen package has no component ownership and the schema
> tests have no Bazel target. The cleanest fix compatible with **task req 4**
> (ownership/import compatibility): generate both new schemas into the existing
> `manifest/gen` package — which is already a member of the checked `manifest` component."*

It cited **"task req 4"** by number. Nothing in the §4.5 prompt contains the task file, its
path, or any requirement — the prompt is five lines naming a `review.yaml`. It also knew
which package it had generated into and why, and reasoned about the constraint that its own
earlier choice had been made under. That is the prototype's core claim, reproduced.

**But the speed claim did not reproduce.** §Overview asserts rework rounds run "3–5× faster
than the initial round"; RUN 2 measured 2.8×, 3.7× and 5.2×. Here: round 0b 625 s → round 1
**569 s, only 1.1× faster**. The reason is visible in the tool counts — 280 then 206, i.e.
the rework did nearly as much *work*, because the finding required moving a generated
package between Go packages, updating BUILD metadata and re-running the full Bazel gate,
not editing a few lines. **The saving is in re-orientation, not in execution**, and when
the fix is large the re-orientation saving is a small fraction of the round. The skill
states the 3–5× as a general property; it is better described as an upper bound on tasks
whose rework is small. One data point, but a clean one.

### F-50 — `jj-change-id.sh --check` silently launders a **commit** id into a change id

The implementer emitted `result.change_id: bc6c358c`. That is `@-`'s **commit** id, not a
change id — the one substitution §Validation Posture explicitly forbids ("Compare change
ids, **never** commit ids"). Run through the skill's own validator:

```
$ jj-change-id.sh --repo "$REPO" --check bc6c358c
ok         bc6c358c -> mpvsulplnwprozwkqywtmnymxkqzwnpt
rc=0
```

**`ok`, exit 0.** The script resolves it — `jj log -r <id>` accepts commit ids as revsets —
and prints a change id, giving the orchestrator positive confirmation for exactly the input
class the skill says must never be used. The check the skill offers as its mechanical
defence against id confusion is the thing that hides it.

Why this is not academic: §4.6's `jj describe` **rewrites the commit id of every earlier
change in the task** (observed twice this run: "Rebased 5 descendant commits", "Rebased 2
descendant commits"). So a commit id that resolves cleanly *now* resolves to nothing after
§4.6. An orchestrator that took `--check`'s `ok` at face value and wrote `bc6c358c` into
`produced_changes` — which §4.2 tells it to do — would have a task record that is valid
until finalisation and silently dangling afterwards, and any later prompt built from it
would mis-scope without erroring. That is RUN 2's F-36 failure mode arriving through the
tool built to prevent it.

**What I did (§Validation Posture's "malformed but unambiguous" tolerance):** accepted it,
because it identifies `@-` with certainty and no other change shares the prefix, and wrote
the **real** change id `mpvsulplnwprozwkqywtmnymxkqzwnpt` into `produced_changes` and into
the re-review prompt. Recorded here as the section requires. No rework round spent on it.

Note the tolerance clause anticipated a *different* malformation — "a change-id prefix
concatenated with a commit-id prefix … which resolves to nothing". That variant is
self-announcing: it fails to resolve. A bare commit id is the dangerous variant precisely
because it *does* resolve, and the skill does not mention it.

**Fix the scripts should carry:** `--check` must report the id **kind**. `jj log -r <id> -T
'change_id ++ " " ++ commit_id'` gives both; if the input is a prefix of the commit id and
not of the change id, print `COMMIT-ID <given> -> <change_id>` and exit non-zero, or at
minimum warn. It is three lines and it converts a silent laundering into a loud one.
**Severity: medium-high.** **Confidence: high** — reproduced directly, output quoted above.

### Round 1 — re-review, SAME reviewer session (`…-task03b`)

Sent §4.4's re-review template verbatim — it does **not** restate the prior review, which is
the point ("the reviewer already holds its prior review; say so rather than restating it").
`current_change` and `produced_changes` given as full 32-character change ids, all
`--check`ed. This is the first re-review this run has reached, so it is also the first test
of reviewer continuity across rounds.

**Round 1 re-review result.** Exit **0**, `stopReason=end_turn`.

- Wall **364 s (6m04s)** — **2.0× faster** than its own round-0b turn (717 s), and tool
  calls fell 123 → 61. Reviewer continuity is doing real work.
- Tokens: `totalTokens=289073 inputTokens=436 cachedReadTokens=288512 outputTokens=125`.
  `cachedReadTokens` grew 186 112 → 288 512 monotonically within the session. No compaction.
- Headroom **34.0 %** of 850 000 — the highest of the run, still under the 50 % flag. Two
  rounds on a 3-change task reached a third of the window; a 5-round task on this
  configuration would plausibly cross it, which is exactly the case §Prompting's rule is
  for. It did not fire here, but it is no longer hypothetical.
- Topology diff: **unchanged** ✓.

**Verdict: `approved`.** Reviewer continuity confirmed — its summary opens *"The prior
important ownership finding is resolved"* and its `merge_request.body` states *"The prior
review's important finding is resolved; no test deletion or weakening was introduced."* It
was never re-fed the earlier review; §4.4's re-review template deliberately does not include
it. One new `suggestion` (a stale `justfile` comment naming the directory the rework
removed) — a finding that only exists *because* of the rework, which is a re-reviewer
noticing a second-order consequence rather than re-reading its checklist.

### §4.6 finalize (task 03)

- Described the oldest change `mvzpmomu`; `jj describe` reported **`Rebased 3 descendant
  commits`**. Change ids stable, commit ids rewritten, as designed.
- **F-44 recurred, third variant.** The reviewer's title was
  `[Compositional Schemas: Step 03/Task 03]` — a *third* invented project tag in this run
  (task 02 produced `[Authority Lattice: …]`, and the correct one is
  `[Compositional Analysis: …]`). The body again opened *"Reviews the complete ordered
  series from the supplied base through the current change"* and then listed three raw
  32-character change ids inline. Rewrote both per the §4.6 licence (title by the same
  declared deviation as F-44), preserving every substantive claim including the two-round
  review history and the open suggestion. **Three for three**: every `merge_request` this
  run produced was unusable as written. This is not an occasional wart — it is the default
  output of `code-task-review`, and §4.6's "**MAY** rewrite" should be "**MUST** check, and
  rewrite when it is written in the reviewer's voice".
- Bookmark `pr/…/step03/task-03-define-persisted-artifact-schemas.code-task` created on the
  newest change `mpvsulpl`. Both sessions closed.

### F-51 — §4.7 + §Recovering together commit ~250 KB of raw transcript per lost turn

§Recovering says to capture "`out.json`, `out.err`, the `sessions show` output and the
**wire-log tail**" into `kill-evidence/`. §4.7 then says to copy `kill-evidence/` into the
**tracked** record directory. Composed, they put the raw ACP wire log into permanent history.

Measured here: the task-03 record is **600 KB, of which 560 KB is `kill-evidence/`**, and
243 KB of that is a single `wire-tail.ndjson` — my `tail -50` of the wire log. Fifty lines,
243 KB, because ACP wire lines embed whole file contents from every read the agent did.
(`acpx-prompt.sh` passes `--suppress-reads`, but that governs acpx's *stdout*, not the wire
log.) Two kills on one task, neither of which produced a single line of code, cost more
tracked bytes than the entire distilled record of all three tasks combined.

I followed the skill and committed it. But the ratio is wrong: §4.7's stated purpose is the
record "still worth reading in six months", and a 243 KB wire tail is the least readable
artifact in the run — the *useful* evidence is the 800-byte `NOTES.md`, `sessions-show.txt`
and `jj-st.txt`, which together are under 2 KB and answer every question about the kill.

**Fix:** §4.7 should copy the *interpreted* kill evidence (notes, `sessions show`, `status`,
`jj st`/`jj log`) and leave `out.json` and the wire tail in the gitignored run dir, where
§Recovering already puts them and where they are actually used — during the incident.
Or cap the wire tail by bytes rather than lines.
**Severity: low** (bloat, not correctness) but it compounds: at two kills per step this adds
~½ MB per step to a repository whose subject is architectural hygiene.
**Confidence: high** — measured, not estimated.

### §4.8 — task 03 summary

| | |
|---|---|
| Task | `step03/task-03-define-persisted-artifact-schemas.code-task.md` |
| Outcome | **approved**, after **1 rework round** |
| Produced changes | `mvzpmomu`, `pvysxzts`, `mpvsulpl` (3) |
| Bookmark | `pr/…/step03/task-03-define-persisted-artifact-schemas.code-task` on `mpvsulpl` |
| Lost turns | **2** (round-0 implementer, round-0 reviewer) — neither charged |
| Deferred | 1 `suggestion` — stale `justfile:28` comment |

| Round | Role | Wall | Tokens (total / cached) | Compacted |
|---|---|---|---|---|
| 0 | implementer | 17 s **KILLED** | — | — |
| 0b | implementer | 625 s | 68 116 / 66 368 | no |
| 0 | reviewer | 19 s **KILLED** | — | — |
| 0b | reviewer | 717 s | 187 551 / 186 112 | no |
| 1 | implementer | 569 s | 95 404 / 94 720 | no |
| 1 | reviewer | 364 s | 289 073 / 288 512 | no |

Agent wall **37m51s** productive + 36 s destroyed. **No session compacted at any point in
this run.**

**Prototype-evaluation observations:**
- **Implementer continuity: confirmed**, across a 67-minute idle gap, citing a task
  requirement by number that appeared nowhere in the prompt.
- **Reviewer continuity: confirmed**, awarding credit against its own prior finding without
  being re-fed it, at 2.0× the speed and half the tool calls of its first pass.
- **The 3–5× rework speed-up did not reproduce** (1.1×) — see the round-1 note above.

## §4 — Step 3, Task 04: implement-symbol-id-grammar — KILLED, run stops

Base `tvmnmlxskowosxountmxptwszvyzkywr`. Session opened and model-verified, §4.3 prompt sent
at 21:40:13. Killed at **21:41:19 — 66 seconds**. Repository untouched: `jj st` clean,
`jj diff --stat` 0 files, nothing committed, nothing to recover.

**Honouring the declared stop.** When I overrode the loop guard to retry the task-03 review,
I wrote: *"I declare the override and **stop unconditionally if it recurs** — no further
retries on this round regardless of role."* It recurred. Stopping, without asking again.

### F-49 (revised) — the kills are bimodal, and it is not a schedule

Kill 3 at 66 s does not fit the 14 m 29 s period at all, independently re-confirming the
falsification. But adding it to the set exposes a sharper pattern:

| Turn duration | Outcome | n |
|---|---|---|
| 17 s, 19 s, 66 s (and RUN 2's 141 s) | **killed** | 4 |
| 364 s, 569 s, 625 s, 670 s, 717 s, 759 s (and the 1200 s heartbeat) | survived | 7 |

**Every kill is under 150 seconds; every survival is over 360.** No overlap in four runs'
worth of data. Whatever the mechanism is, it acts in the **first ~2½ minutes of a turn or
not at all** — which is why "it looked periodic" was so seductive and why duration-based
explanations kept failing: the risk is front-loaded, not accumulating.

What is distinctive about that window: it is when acpx **spawns the adapter**. `opencode
acp` was measured at 562 MB RSS, and the machine at kill 3 was at **21.7 GB of 31.4 GB used
with 7.4 GB of swap in use**. A spawn under that pressure is a plausible trigger, and it
would explain the front-loading exactly. I could not confirm it: `dmesg` and `journalctl`
are unavailable in this sandbox, so an OOM kill can be neither shown nor excluded.

**It does not explain everything.** An OOM killer would not have taken kill 1's unrelated
`sleep 900` — a process using kilobytes — in the same second. So either two mechanisms are
in play, or the reaper is a supervisor acting on memory pressure over the whole background
task group rather than the kernel picking a victim.

**Confidence:** high on the bimodal observation (11 data points, no overlap); **low** on the
adapter-spawn/memory mechanism — it is a hypothesis consistent with the evidence, not a
diagnosis, and I am flagging it as the next thing to test rather than as a finding.

**What the skill should take from this regardless of mechanism:** turn loss is concentrated
in the first ~2 minutes, when the agent has done nothing. That is the *cheapest* possible
time to lose a turn and it is why every loss in this run cost seconds of agent work rather
than RUN 2's 65 minutes. §4.3's incremental-commit paragraph plus a fast death-detection
verdict (F-45) are together a complete answer to this failure mode; nothing else is needed.

### §5.1 sweep on the abort path — first execution, works

`acpx-close.sh --repo … --sweep --slug 2026-08-04-compositional-component-analysis`:

```
sweeping opencode/awo-impl-2026-08-04-compositional-component-analysis-step03-task04
swept 1 session(s)
```

It found exactly the one session left open by the killed task, closed it, and reported the
count as §5.1 requires. That it found **only** one is itself the verification that every
other session this run opened — 3 implementers, 3 reviewers, 2 restarts — was closed at its
task boundary as §4.6 requires. `--sweep`, `--slug` filtering, the count line, and the
close discipline they audit are all confirmed working on first execution.

---

# RUN 3 STOP — task boundary, repository clean

Stopped at a **task boundary** with tasks 01–03 of step 3 complete and task 04 not begun.
Nothing partial, nothing uncommitted, nothing abandoned, no `jj undo`, no bookmark moved.

**Final topology:**

```
qzumvyml (empty)                                                          <- @
tvmnmlxs chore(awo): record bookkeeping for step03 task 03
mpvsulpl refactor(proto): generate schemas into manifest gen   pr/…/step03/task-03-….code-task
pvysxzts test(archcontracts): descriptor-level schema tests
mvzpmomu feat(proto): define persisted artifact schemas [Compositional Analysis: Step 03/Task 03]
tkykompn chore(awo): record bookkeeping for step03 task 02
srwvxuvy build(manifest): add authority sources …              pr/…/step03/task-02-….code-task
wqonwuqw feat(manifestparity): compare the authority declaration
pzwznmux feat(manifest): parse the persisted authority axis
xsurzmsp feat(manifest): add AuthorityDeclaration lattice with total join
vroypskv feat(manifest): add persisted authority lattice and parity [Compositional Analysis: Step 03/Task 02]
orxzvxlk chore(awo): record bookkeeping for step03 task 01
yszrupsy docs(readme): finish retirement cleanup                pr/…/step03/task-01-….code-task
…
```

**Step 3 progress:** tasks 01, 02, 03 approved and bookmarked; 04, 05, 06 not started.
§5.1–§5.3 not reached, so **§5.2's remediation branch remains unexercised for a third
run** — it needs a completed step, and the step needs three more tasks.

**All acpx sessions closed** (sweep verified). Plan checklist untouched — Step 3 correctly
still `- [ ]`.

**To resume:** step 3 task 04, base `tvmnmlxskowosxountmxptwszvyzkywr`, run dir and §4.3
prompt already written at
`.agents/runs-acpx/20260903T214006Z-step03-task-04-implement-symbol-id-grammar/`.

---

# Consolidated evaluation — RUN 3

**Skill revision tested:** `suwsoytq 31c4b438`. **Scope:** step 3, tasks 02–03 complete,
task 04 killed at launch. **Findings:** F-37 … F-51 (15).

## Findings index

| # | Section | Severity | One line |
|---|---|---|---|
| F-37 | §Prompting | medium | The 50 % headroom rule has no context-window figure for the opencode implementer |
| F-38 | §Role Config / `acpx-config.yaml` | low | The config file's header still tells you to re-assert model/effort, which §Sessions now forbids |
| F-39 | §Parameters / §Steps | **high** | The resume rule resolves only to a *step*; §2 has no idempotence guard, so a literal resume re-runs task generation over a half-implemented step |
| F-40 | §4.7 | — | No story for a task completed before §4.7 existed *(deviation: ran it retroactively)* |
| F-41 | §4.7 vs §4.1 | med-high | §4.7 forbids bookmarking the commit that §4.1 then requires to be bookmarked *(deviation: left it unbookmarked)* |
| F-42 | `acpx-open.sh` | cosmetic | Prints Python's `None` for an unset effort |
| F-43 | §4.2 / §4.4 | med-high | The producer's own count of its changes was wrong; §4.2 says to record changes "as created", which §Supervising forbids |
| F-44 | §4.6 | medium | The rewrite licence covers the body but not the title, which had the same defect *(deviation: rewrote the title too)* — 3/3 merge requests unusable as written |
| F-45 | §Recovering / `acpx-progress.sh` | **high** | "Poll until it reports 3 (idle)" is unreachable for a killed turn; the script says WORKING for 15 min, then STALLED forever |
| F-46 | §Operating Constraints | medium | RUN 2's harness kill vector recurs; it killed a bare `sleep` alongside the turn |
| F-47 | §Supervising | low | The 15-minute check-in loop never fires: every completed turn ran 6–13 min |
| F-48 | §Recovering / §5.1 vs §E.2 | medium | "Per round" is ambiguous across roles; sweep-on-every-abort contradicts leave-sessions-open *(deviation: partial sweep)* |
| F-49 | environment | — | Kill vector: periodic-reaper hypothesis **falsified by experiment**; kills are bimodal, all under 150 s |
| F-50 | `jj-change-id.sh` | med-high | `--check` silently launders a **commit** id into a change id and reports `ok` |
| F-51 | §4.7 + §Recovering | low | Together they commit ~250 KB of raw ACP wire log per lost turn into tracked history |

## What the skill got right

- **`scripts/` is the right answer to RUN 2's central complaint.** Every wrapper worked on
  first execution and each encoded claim that could be tested, was: `acpx-open.sh` verified
  model+effort against the session record (fixing F-31); `acpx-prompt.sh` routed on
  `stopReason` and was correct all eleven times, including four where acpx's own exit code
  would have lied; `--ttl 0` kept an adapter resident **67 minutes** across a kill, a
  stop-and-ask and a user round-trip; `--sweep` found exactly the one leaked session.
- **`jj-change-id.sh` fixes F-36.** Every id in this run was read, never retyped. It has its
  own hole (F-50), but the class of error RUN 2 nearly shipped did not recur.
- **The topology contract held through 11 changes, two `jj describe` rebases (5 and 3
  descendants), three kills and two restarts** — no rewrite, no lost change, no moved
  bookmark, no `jj undo`.
- **The pre/post-review topology snapshot** caught nothing, three times, in two commands
  each. That is the correct outcome for a cheap check and it should stay.
- **§4.3's incremental-commit paragraph is the whole defence against turn loss** and should
  be labelled as such rather than justified by anecdote.
- **Both continuity hypotheses reproduced** — see below.
- **No session compacted at any point.** Peak was 289 073 tokens, 34 % of the 850 000
  window. The combination of task-scoped sessions, `--ttl 0` and a near-maximal window has,
  on this evidence, eliminated the problem that dominated RUN 2.

## What the skill got wrong, by section

- **§Parameters/§Steps** cannot resume mid-step (F-39) — and mid-step resumption is how both
  previous runs ended. The bookmarks already encode the answer; the skill just never reads
  them.
- **§Recovering** contains an unreachable instruction (F-45) that costs ~30 minutes and a
  spurious halt per kill, and its loop guard does not distinguish a reviewer loss (which
  provably changes nothing) from an implementer loss (which can leave unvalidated work)
  (F-48).
- **§4.7 is new and collides with §4.1** (F-41) on every task after the first, and with
  §Recovering on evidence size (F-51).
- **§4.2's "append each produced change as it is created"** describes an access pattern
  §Supervising forbids, and the alternative — trusting the producer's count — is wrong
  (F-43).
- **§4.6's licence is scoped too narrowly** (F-44); on three of three tasks the
  `merge_request` needed rewriting, so "MAY" understates it.
- **`jj-change-id.sh --check`** is the run's sharpest single defect (F-50): the tool built
  to prevent id confusion positively confirms the one id class the skill forbids.

## The two continuity hypotheses

**Implementer across rework: confirmed, strongly.** One rework round was reached (task 03).
The session had been idle **67 minutes** — across a kill, a stop-and-ask, a 20-minute
experiment and a user round-trip — and its first sentence back cited **"task req 4"** by
number. The §4.5 prompt is five lines naming a `review.yaml` path; it contains no task, no
path, no requirement, no summary of prior work. Nothing was padded.

**Reviewer across rework: confirmed.** The re-review opened *"The prior important ownership
finding is resolved"* without being re-fed the earlier review, ran **2.0× faster** than its
first pass (717 s → 364 s) with half the tool calls, and raised a *new* suggestion that
existed only as a consequence of the rework — second-order noticing, not checklist re-reading.

**One published claim did not reproduce.** §Overview says rework rounds run "3–5× faster";
RUN 2 saw 2.8–5.2×. Here: **1.1×** (625 s → 569 s), because the fix was structural — moving
a generated package between Go packages and re-running the full Bazel gate. The saving is in
**re-orientation, not execution**; when the fix is large it is a small fraction of the round.
The 3–5× figure should be stated as an upper bound conditioned on small rework.

## Judgement calls a deterministic checker would have made for me

Ranked by how uneasy I am about each.

1. **Overriding the loop guard to retry the task-03 review (F-48/F-49).** *Least confident.*
   I had the user's approval and a real argument (a reviewer writes nothing; I proved it
   with a topology diff), but the guard's escape clause requires naming a **fix**, and I
   could not. I named a *diagnosis instead of a fix* and proceeded. The retry succeeded and
   produced the run's best finding — and that outcome is not evidence the call was right.
   When it recurred at task 04 I stopped as declared.
2. **Rewriting the reviewer's `merge_request.title` (F-44).** *Medium.* §4.6 licenses the
   body only. RUN 2 recorded applying an unusable body verbatim and regretting it, so I had
   evidence for the spirit of the rule; I still went past its letter, three times.
3. **Not bookmarking the task base (F-41).** *Medium-high.* Two MUSTs conflict and I picked
   the newer one. It silently lowers §Recovering's `jj abandon` anchor by one change — a
   real, if small, safety loss that nothing would have told me about.
4. **Partial sweep at the mid-task stop (F-48b).** *Medium-high.* §5.1 says sweep on every
   abort path; §E.2 says leave sessions open. I kept the live implementer because closing it
   would have destroyed the thing under test. Defensible, still a declared violation of a MUST.
5. **Accepting a bare commit id as `result.change_id` (F-50).** *High confidence* — it
   identifies `@-` uniquely and §Validation Posture's tolerance clause covers it — but only
   because I noticed it was a commit id. The skill's own checker told me `ok`.
6. **Running §4.7 retroactively for task 01 (F-40).** *High.* Pure copy, nothing synthesised.
7. **Deriving `produced_changes` from `jj log` rather than the producer (F-43).** *Highest.*
   The producer was demonstrably wrong once and right once under identical conditions.

## Cost

| | |
|---|---|
| Productive agent wall | **61m40s** (6 completed turns) |
| Destroyed by kills | **1m42s** (3 turns: 17 s, 19 s, 66 s) |
| Tasks completed | 2 (step 3 tasks 02, 03) |
| Changes produced | 8 implementation + 3 bookkeeping |
| Rework rounds | 1 |
| Turns compacted | **0** |
| Peak session context | 289 073 / 850 000 (34 %) |

**Infrastructure cost inverted from RUN 2.** There, 33 % of agent time was destroyed by two
kills. Here, kills destroyed **1.4 %** of agent time — but consumed a large share of
*orchestrator* time, almost all of it establishing death against a script that reports
`WORKING` (F-45). The failure moved from the agents to the operator, and that is a fixable,
three-line problem.

## Verdict on the prototype, RUN 3

The tooling rewrite worked. RUN 2 concluded the orchestration logic was sound while the
skill's model of its own tooling was wrong in five places; those five are fixed, the fixes
are executable and were each verified in flight, and no comparable defect appeared in the
acpx layer this run.

**What the run exposed instead is the layer above: the skill's model of its own *control
flow*.** The three highest findings — F-39 (cannot resume mid-step), F-45 (an unreachable
polling instruction), F-41 (two MUSTs that cannot both hold) — are all cases where two
sections of the skill are individually reasonable and jointly unsatisfiable, and each one
surfaces only on a path the skill treats as exceptional but which is in fact routine:
resuming a run, losing a turn, and finishing a task. All three failure modes fire *toward
halting a healthy run*, which is the specific hazard §Sessions says it was written to avoid.

The prototype's own hypotheses are now well supported twice over, and compaction — RUN 2's
dominant technical problem — did not occur once. The remaining work is not on the
hypotheses; it is on making the skill's exceptional paths as executable as its acpx surface
now is.

**Still unexercised after three runs:** §5.2's remediation branch, §Escalation Handling
(E.1–E.4) in full, and §Recovering's `jj abandon` predicate — the last of which has now
failed to apply in all three real kills, because in every case the killed turn left nothing
committed. That is worth noting: the predicate may be guarding a case that does not occur.
