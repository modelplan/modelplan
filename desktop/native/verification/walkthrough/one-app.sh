#!/bin/bash
# SPDX-License-Identifier: MIT
# Print the one packaged app in a directory: ModelPlan.app, or "ModelPlan Community.app" for a ref
# from before the D57 rename. Anything else (none, both, another name) is refused.
set -euo pipefail
dir=${1:?Pass the directory holding the packaged app}
found=()
for name in 'ModelPlan.app' 'ModelPlan Community.app'; do
    if [ -d "$dir/$name" ] && [ ! -L "$dir/$name" ]; then found+=("$dir/$name"); fi
done
if [ "${#found[@]}" -ne 1 ]; then echo "expected exactly one packaged ModelPlan app in $dir" >&2; exit 1; fi
printf '%s\n' "${found[0]}"
