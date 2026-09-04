# awo-acpx run reports

Work logs from real `awo-acpx` runs, kept as the evidence behind the skill's design
decisions. The orchestrator writes its `work_log` to a gitignored scratchpad in the
target repository, so without checking a copy in here the reasoning behind a change
survives only in a commit message.

Each report is a verbatim copy, written incrementally during the run. They are
chronological rather than tidy: in-flight reasoning, corrections and dead ends are left
in, because *how* a defect was noticed is often more useful than the finished statement
of it.

Conventions:

- Name reports `{YYYY-MM-DD}-{repo}-{scope}-{plan-slug}.md`.
- Tag findings `[F-nn]` and keep the numbering stable within a report, so skill changes
  and commit messages can cite them.
- State the skill revision under test, and — once the report has produced changes — the
  revision that resulted. A report whose findings have been acted on should say so.
- Record judgement calls the orchestrator had to make where a deterministic tool would
  not have, and be explicit about which ones it was unsure of. Those are the candidates
  for future validation tooling, and they are the least recoverable information in a run.

| Report | Skill revision tested | Outcome |
|---|---|---|
| [2026-09-02 · arcc step 01](2026-09-02-arcc-step01-compositional-component-analysis.md) | `a949b850` (initial prototype) | 23 findings → `cfbee2a4`: reviewer scope narrowed step→task, per-step `implementation-review` added, plan progress moved to the orchestrator, per-prompt model re-assertion, killed-turn recovery |
| [2026-09-03 · arcc steps 02–03](2026-09-03-arcc-step02-03-compositional-component-analysis.md) | `cfbee2a4` (RUN 1's fixes) | 13 findings (F-24–F-36), 4 high/critical. §5.3 and §5.2 verified working; §Sessions' model of acpx found wrong on five counts (exit codes, kill signature, `status -s` model line, effort re-assertion, `cache_read` drops); §Recovering has no rule for uncommitted work |
| [2026-09-03 · arcc step 03 t02–03](2026-09-03-arcc-step03-task02-03-compositional-component-analysis.md) | `31c4b438` (scripts/ rewrite) | 15 findings (F-37–F-51) → `ecb43935`: turns run detached so a harness kill loses supervision rather than the turn (`acpx-await.sh` reattaches), `acpx-progress.sh` gains a `dead` verdict, §0 resumes off the bookmarks, §4.7 bookmarks its commit, `produced_changes` derived from a revset, `--check` rejects commit ids. 3 high/med-high. `scripts/` verified working on first execution — model/effort pinning, `stopReason` routing, `--ttl 0` over a 67-min idle gap, `--sweep`; both continuity hypotheses reproduced; zero compaction. Control-flow defects instead: §Parameters cannot resume mid-step, §Recovering's "poll until idle" is unreachable for a killed turn, §4.7 and §4.1 contradict, `jj-change-id.sh --check` launders commit ids |
| [2026-09-03 · arcc step 03 t04](2026-09-03-arcc-step03-task04-compositional-component-analysis.md) | `ecb43935` (RUN 3's fixes) | 8 findings (F-52–F-59), 2 high. **Kill vector identified**: Claude Code's own low-memory watchdog `kill()`s the turn's *explicit pid* alongside a `killpg` on the wrapper's group, in one 54 µs burst — so RUN 3's `setsid` detachment cannot work, and §Deciding's exit-`11` row ("the wrapper was killed; the turn was not") is false. Host-side `bpftrace` evidence in the appendix. F-59: `--ttl 0` trades compaction for kills — resident adapters are the dominant *controllable* term in the pressure that trips the watchdog, and §Closing a session documents only the benefit. F-58: `acpx-evidence.sh` captures `free`, which cannot see the commit-limit overcommit (2.1×) that was the actual condition. Verified working: §0 resumes off the bookmarks correctly even with one row of its table absent; `acpx-progress.sh`'s `dead` verdict (~40 s, vs ~30 min in RUN 3); §4.2's revset (producer miscounted 4 vs 5 again, omitting the change the task rests on). First controlled cold-vs-warm reviewer measurement: cold re-review cost **2.4–2.5× wall and 2.5–4.4× tool calls** on the same series. Zero compactions. **Run incomplete** — stopped at step 03 task 04, round-4 review unrun, `max_rework_rounds` consumed |
