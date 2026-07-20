#!/usr/bin/env python3
"""Contract checks for the paired structured-spec-to-code v2 producer protocol."""

from pathlib import Path
import re
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures" / "protocol-v2"
CHANGE_ID = re.compile(r"^[k-z]+$")
# Titles end with [<Topic>: <task-ref>]; task-ref is "Step NN/Task NN" under a
# plan, or "Task NN" for a standalone interactive task.
TASK_REFERENCE = re.compile(r"\[[^\]]+: (?:Step \d{2}/)?Task \d{2}\]$")
TAXONOMY = frozenset(
    {"spec_defect", "spec_ambiguity", "unrecoverable_state", "blocked_dependency"}
)


def load_fixture(name):
    with (FIXTURES / name).open() as stream:
        return yaml.safe_load(stream)


def metadata(text):
    matches = re.findall(
        r"```spec-workflow-meta\s*\n(.*?)\n```", text, flags=re.DOTALL
    )
    if not matches:
        raise AssertionError("fixture does not contain a complete metadata fence")
    return yaml.safe_load(matches[-1]), text.rsplit("```", 1)[-1]


class ProtocolV2FixturesTest(unittest.TestCase):
    def test_completed_result_is_v2_and_uses_a_jj_change_id(self):
        result = load_fixture("result-completed.yaml")

        self.assertEqual(result["result"]["schema_version"], 2)
        self.assertIn("change_id", result["result"])
        self.assertNotIn("commit", result["result"])
        self.assertRegex(result["result"]["change_id"], CHANGE_ID)

    def test_result_change_id_is_committed_parent_not_empty_working_copy(self):
        state = load_fixture("result-change-id-at-minus.yaml")

        self.assertRegex(state["working_copy"]["change_id"], CHANGE_ID)
        self.assertRegex(state["committed_change"]["change_id"], CHANGE_ID)
        self.assertEqual(
            state["result"]["change_id"], state["committed_change"]["change_id"]
        )
        self.assertNotEqual(
            state["result"]["change_id"], state["working_copy"]["change_id"]
        )

    def test_all_review_verdicts_keep_v2_change_and_merge_request_content(self):
        expected = {"approved", "changes_requested", "escalated", "blocked"}
        seen = set()
        for path in sorted(FIXTURES.glob("review-*.yaml")):
            review = load_fixture(path.name)
            seen.add(review["review"]["verdict"])
            self.assertEqual(review["review"]["schema_version"], 2)
            self.assertIn("change_id", review["review"])
            self.assertNotIn("commit", review["review"])
            self.assertRegex(review["review"]["change_id"], CHANGE_ID)
            self.assertTrue(review["merge_request"]["title"].strip())
            self.assertTrue(review["merge_request"]["body"].strip())
        self.assertEqual(seen, expected)

    def test_planned_and_standalone_titles_have_exact_context_suffixes(self):
        planned = load_fixture("review-planned.yaml")["merge_request"]["title"]
        standalone = load_fixture("review-standalone.yaml")["merge_request"]["title"]

        self.assertTrue(planned.endswith("[Enhancement: Step 02/Task 01]"))
        self.assertTrue(standalone.endswith("[Enhancement: Task 01]"))

    def test_every_review_title_ends_with_a_documented_task_reference(self):
        for path in sorted(FIXTURES.glob("review-*.yaml")):
            title = load_fixture(path.name)["merge_request"]["title"]
            self.assertRegex(
                title,
                TASK_REFERENCE,
                f"{path.name} title lacks a documented task reference",
            )

    def test_reviewer_docs_agree_on_the_task_reference_forms(self):
        reviewer = (ROOT / "code-task-review" / "SKILL.md").read_text()
        report_schema = (ROOT / "code-task-review" / "report-schema.md").read_text()

        # Cross-file contract: the skill and its schema must document the same
        # two suffix shapes, since orchestrators parse titles by them.
        for text in (reviewer, report_schema):
            self.assertIn("<Topic>", text)
            self.assertIn("Step NN/Task NN", text)
        # The schema's worked examples must satisfy the rule they document.
        for example in re.findall(r"\[[^\]\n]+Task \d{2}\]", report_schema):
            self.assertRegex(example, TASK_REFERENCE)

    def test_inline_metadata_is_yaml_v1_and_need_not_be_terminal(self):
        result_meta, result_after = metadata(
            (FIXTURES / "result-completed.finaltext.txt").read_text()
        )
        self.assertEqual(result_meta, {
            "status": "completed",
            "result_path": ".agents/scratchpad/example/result.yaml",
            "schema_version": 1,
        })
        self.assertTrue(result_after.strip())

        for name in ("approved", "changes-requested", "blocked", "escalated"):
            review_meta, review_after = metadata(
                (FIXTURES / f"review-{name}.finaltext.txt").read_text()
            )
            self.assertEqual(review_meta["status"], "completed")
            self.assertEqual(review_meta["schema_version"], 1)
            self.assertTrue(review_after.strip())

    def test_escalated_review_carries_a_reason_and_details_block(self):
        review = load_fixture("review-escalated.yaml")

        self.assertEqual(review["review"]["verdict"], "escalated")
        escalation = review["escalation"]
        self.assertIn(escalation["reason"], TAXONOMY)
        self.assertTrue(escalation["details"].strip())

    def test_escalation_block_is_present_iff_verdict_is_escalated(self):
        for path in sorted(FIXTURES.glob("review-*.yaml")):
            review = load_fixture(path.name)
            escalated = review["review"]["verdict"] == "escalated"
            self.assertEqual(
                "escalation" in review, escalated, f"{path.name} escalation block"
            )

    def test_a_fixable_critical_finding_is_changes_requested_not_terminal(self):
        review = load_fixture("review-critical-fixable.yaml")
        severities = {finding["severity"] for finding in review["findings"]}

        self.assertIn("critical", severities)
        self.assertEqual(review["review"]["verdict"], "changes_requested")
        self.assertNotIn("escalation", review)

    def test_both_producers_document_the_shared_escalation_taxonomy(self):
        result_schema = (ROOT / "task-to-code" / "result-schema.md").read_text()
        report_schema = (ROOT / "code-task-review" / "report-schema.md").read_text()

        for text in (result_schema, report_schema):
            for reason in TAXONOMY:
                self.assertIn(reason, text)

    def test_reviewer_no_longer_emits_the_deprecated_blocked_verdict(self):
        reviewer = (ROOT / "code-task-review" / "SKILL.md").read_text()
        report_schema = (ROOT / "code-task-review" / "report-schema.md").read_text()

        self.assertIn("MUST NOT emit `verdict: blocked`", reviewer)
        self.assertIn("deprecated", report_schema)
        # The archived-report fixture must still parse: awo keeps accepting it.
        self.assertEqual(
            load_fixture("review-blocked.yaml")["review"]["verdict"], "blocked"
        )

    def test_contracts_state_stable_jj_and_completion_rules(self):
        implementer = (ROOT / "task-to-code" / "SKILL.md").read_text()
        result_schema = (ROOT / "task-to-code" / "result-schema.md").read_text()
        reviewer = (ROOT / "code-task-review" / "SKILL.md").read_text()
        report_schema = (ROOT / "code-task-review" / "report-schema.md").read_text()

        for text in (implementer, reviewer):
            self.assertIn("spec-workflow-meta", text)
            self.assertIn("schema_version: 1", text)
            self.assertIn("change_id", text)
        self.assertIn("jj commit -m", implementer)
        self.assertIn("detailed body", implementer)
        self.assertIn("empty working-copy `@`", implementer)
        self.assertIn("probe the produced task change at `@-`", implementer)
        self.assertIn("result.change_id` exactly to that stable `@-` change ID", implementer)
        self.assertIn("jj log -r @-", implementer)
        self.assertIn("MUST NOT create or move bookmarks", implementer)
        self.assertIn("amend, squash, rewrite", implementer)
        self.assertIn("Repository inspection and mutation MUST use jj", implementer)
        self.assertIn("never Git", implementer)
        self.assertIn("complete ordered jj task-change series", reviewer)
        self.assertIn("never use Git", reviewer)
        self.assertIn("MUST NOT create or move bookmarks", reviewer)
        self.assertIn("mutate commits or descriptions", reviewer)
        self.assertIn("merge_request.title", reviewer)
        self.assertIn("status: completed", reviewer)
        self.assertNotIn("result.commit", implementer + result_schema)
        self.assertNotIn("review.commit", reviewer + report_schema)


if __name__ == "__main__":
    unittest.main()
