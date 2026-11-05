# SPDX-License-Identifier: MIT
import unittest
from candidate_source import resolve


class CandidateSourceTests(unittest.TestCase):
    def test_exact_same_repository_open_main_pr_only(self):
        sha = 'a' * 40
        pr = {'state': 'open', 'base': {'ref': 'main'}, 'head': {'sha': sha, 'repo': {'full_name': 'modelplan/modelplan'}}}
        self.assertEqual(resolve(pr, sha), sha)
        for value in ('b' * 40, 'a' * 8):
            with self.assertRaises(ValueError):
                resolve(pr, value)
        pr['head']['sha'] = 'b' * 40
        with self.assertRaises(ValueError):
            resolve(pr, sha)
        pr['head']['sha'] = sha
        pr['head']['repo']['full_name'] = 'attacker/repo'
        with self.assertRaises(ValueError):
            resolve(pr, sha)
