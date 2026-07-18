#!/usr/bin/env python3
"""Contract checks for the paired structured-spec-to-code v2 producer protocol."""

from pathlib import Path
import re
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures" / "protocol-v2"
CHANGE_ID = re.compile(r"^[k-z]+$")


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
        expected = {"approved", "changes_requested", "blocked"}
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

        self.assertTrue(planned.endswith("[Enhancement Step 02/Task 01]"))
        self.assertTrue(standalone.endswith("[Enhancement Task 01]"))

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

        for name in ("approved", "changes-requested", "blocked"):
            review_meta, review_after = metadata(
                (FIXTURES / f"review-{name}.finaltext.txt").read_text()
            )
            self.assertEqual(review_meta["status"], "completed")
            self.assertEqual(review_meta["schema_version"], 1)
            self.assertTrue(review_after.strip())

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
        self.assertIn("[Enhancement Step NN/Task NN]", reviewer)
        self.assertIn("[Enhancement Task NN]", reviewer)
        self.assertIn("status: completed", reviewer)
        self.assertNotIn("result.commit", implementer + result_schema)
        self.assertNotIn("review.commit", reviewer + report_schema)


if __name__ == "__main__":
    unittest.main()
