# SPDX-License-Identifier: MIT
import copy,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'U6'))
from reading_fingerprint import reading_sha256

VECTOR=[dict(route='runtime_rpc',plan=dict(id='copilot_pro'),windows=[dict(id='premium',limitKey='premium_requests',
    poolKey='copilot',remainingPercent=75.25,resetsAt='2099-01-01T00:00:00Z')])]

class ReadingFingerprintTests(unittest.TestCase):
    def test_frozen_readme_vector(self):
        account=dict(route='runtime',plan=dict(id='copilot-pro'),windows=[
            dict(id='premium_interactions',limitKey='premium_interactions',poolKey='copilot',remainingPercent=62.5,resetsAt='2099-01-01T00:00:00Z'),
            dict(id='chat',limitKey='chat',poolKey='copilot',remainingPercent=None,resetsAt=None)])
        self.assertEqual(reading_sha256([account]),'c0ee46c2388e4722f519508dc441af086db96fe31cd3c4597d2392e9410589e4')
    def test_shared_swift_vector(self):
        self.assertEqual(reading_sha256(VECTOR),'92c7f08d9a030f3b6d3409c7698da1b5d0454f773983308d20c7908eb3841a4e')
    def test_changed_remaining_is_not_the_same_reading(self):
        other=copy.deepcopy(VECTOR);other[0]['windows'][0]['remainingPercent']=75
        self.assertNotEqual(reading_sha256(VECTOR),reading_sha256(other))
    def test_read_time_fields_do_not_change_fingerprint(self):
        other=copy.deepcopy(VECTOR);other[0].update(observedAt='2099-01-02T00:00:00Z',freshUntil='2099-01-03T00:00:00Z')
        self.assertEqual(reading_sha256(VECTOR),reading_sha256(other))
    def test_requires_exactly_one_account(self):
        for accounts in ([],VECTOR+VECTOR):
            with self.assertRaisesRegex(ValueError,'account-count'):reading_sha256(accounts)

if __name__=='__main__':unittest.main()
