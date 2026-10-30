# SPDX-License-Identifier: MIT
import unittest
from verify_u11a import verify

def fixture():
    base=dict(viewID='synthetic-view',generation=1)
    return [base|dict(event='window-observation',appActive=True,keyWindow=True,windowVisible=True,occlusionVisible=True),
            base|dict(event='process-attribution',role='WebContent',status='attributed',pid=123,startSeconds=100,startMicroseconds=1),
            *[base|dict(event='animation-frames',documentVisible=True,groups={k:dict(advancingFrames=n) for k in ('indicator','session','HUD')}) for n in (10,20)]]

class ObservationTests(unittest.TestCase):
    def test_complete_context_is_observation_only(self):
        r=verify(fixture());self.assertTrue(r['observationReady']);self.assertIn('unproven',r['budgetVerdict'])
    def test_each_activation_condition_retained_and_required(self):
        for key in ('appActive','keyWindow','windowVisible','occlusionVisible'):
            rows=fixture();rows[0][key]=False;r=verify(rows)
            self.assertFalse(r['observationReady']);self.assertFalse(r['contexts'][0]['windowObservations'][0][key])
    def test_presence_frozen_frames_or_hidden_document_are_not_activity(self):
        for mutate in ('frozen','hidden','missing-group'):
            rows=fixture()
            if mutate=='frozen':rows[-1]['groups']=rows[-2]['groups']
            if mutate=='hidden':rows[-1]['documentVisible']=False
            if mutate=='missing-group':del rows[-1]['groups']['HUD']
            self.assertFalse(verify(rows)['observationReady'])
    def test_contexts_must_not_be_stitched(self):
        rows=fixture();rows[-1]['generation']=2
        self.assertFalse(verify(rows)['observationReady'])
        rows=fixture();rows[1]['viewID']='other-view'
        self.assertFalse(verify(rows)['observationReady'])
    def test_pid_reuse_requires_retirement_and_unsupported_stays_missing(self):
        rows=fixture();rows.insert(2,rows[1]|dict(startSeconds=200))
        self.assertFalse(verify(rows)['observationReady'])
        rows=fixture();rows[1]['status']='unsupported'
        self.assertFalse(verify(rows)['observationReady'])

if __name__=='__main__':unittest.main()
