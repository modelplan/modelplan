#!/bin/bash
# SPDX-License-Identifier: MIT
# headless-seed.sh <restore|publish>: warm-build helper for the native-headless leg (trusted-mac.yml, from #1065).
# The workflow runs this file from a sparse checkout of main. #1065 merged before the real helper (#1066), so every
# merge group's native-headless job failed with "No such file or directory" (exit 127). Until #1066 lands, this stub is
# a deliberate no-op: the leg builds cold exactly as it did before #1065, and nothing is published.
# It never fails the job: any argument, any environment, exit 0.
echo "headless-seed: ${1:-restore}: no-op (warm-build helper not on main yet; cold build)"
exit 0
