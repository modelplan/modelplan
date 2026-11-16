#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Job-started hook for the review runner (ACTIONS_RUNNER_HOOK_JOB_STARTED). The owner installs a root-owned copy
outside the runner user's home; it refuses every job except pr-review.yml's review job from main, started by
workflow_run or workflow_dispatch. Defence in depth: the runner group's workflow allow-list is the enforced boundary."""
import os
import sys

REPOSITORY = 'modelplan/modelplan'
WORKFLOW_REF = REPOSITORY + '/.github/workflows/pr-review.yml@refs/heads/main'
JOBS = {'review'}
EVENTS = {'workflow_run', 'workflow_dispatch'}


def validate(env):
    if env.get('GITHUB_REPOSITORY') != REPOSITORY:
        raise ValueError('review_repository_denied')
    if env.get('GITHUB_WORKFLOW_REF') != WORKFLOW_REF:
        raise ValueError('review_workflow_ref_denied')
    if env.get('GITHUB_REF') != 'refs/heads/main':
        raise ValueError('review_ref_denied')
    if env.get('GITHUB_EVENT_NAME') not in EVENTS:
        raise ValueError('review_event_denied')
    if env.get('GITHUB_JOB') not in JOBS:
        raise ValueError('review_job_denied')


if __name__ == '__main__':
    try:
        validate(os.environ)
        print('review_main_policy_verified')
    except ValueError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
