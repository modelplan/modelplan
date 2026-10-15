"""Print a host test prompt without expected answers. Never reads user's local state."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
fixtures = json.loads((root / 'evals/fixtures.json').read_text())['fixtures']
source = json.loads((root / 'evals/scenarios.json').read_text())
cases = []
for case in source['scenarios']:
    data = dict(case['input'])
    for key in list(data):
        if key.endswith('Fixture'):
            data[key[:-7]] = fixtures[data.pop(key)]
    cases.append({'id': case['id'], 'prompt': case['prompt'], 'input': data})

instruction = '''Apply the supplied Skill and reference to frozen test inputs. All synthetic model and plan records are test fixtures, not real product facts. Lookup has already been performed. Make no tool calls, network calls, file reads, credential access, MCP calls, settings edits or model switches. Use each case's explicit current time.
Return JSON {"cases":[{"id":"...","status":"recommend|wait|needs_confirmation|abstain","answer":"concise advice with links and explicit unknowns","facts":{}}]}. Facts may include modelId, effort, ability, cost, abilityDelta, costRatio, multiplier, futureMultiplier, waitSeconds, waitMinutes, remainingPercent, cardCount, headroom, decidingWindow, resetsInMinutes. The following are BOOLEAN facts; include them if the prompt concerns that concept: unusedAllowanceExpires (observed remaining allowance expires at a fixed reset), quotaRestored (personal restored balance proven), cardExpiresBeforeReset, stepUpReasonable (a higher effort, stronger model or fast mode is reasonable given the quota), autoSwitch (you changed settings yourself), autoRedeem, effectiveAtKnown, ownedPlanKnown, observationStale, apiFree, zeroRateConfirmed, sufficiencyGuaranteed (guaranteed completion, not merely judged suitable). Do not invent missing values. Answer in Chinese.
'''
if sys.argv[1:] == ['--parity']:
    instruction = '''Apply the supplied Skill to the frozen anonymous production response. Make no tools, network, credential or MCP calls. Explain the published OpenAI frontier step Luna to Sol 6.1 at their stars. Return JSON with publicationId, from, to, fromEffort, toEffort, fromAbility, toAbility, fromCost, toCost, abilityDelta, costRatio, costUnit, timeIsEstimate, unknowns and a short Chinese answer. Task fit is unknown. Do not recompute lineup verdicts.
'''
    data = json.loads((root / 'evals/public-sample.json').read_text())
elif sys.argv[1:] == ['--review']:
    instruction = '''Apply the supplied Skill and reference to the frozen synthetic client-v1.1 scenarios. Lookup has already been performed; make no tool, network, file/credential, MCP or settings calls. Use each case's explicit time. Return JSON {"cases":[{"id":"...","status":"recommend|wait|needs_confirmation|abstain","answer":"short Chinese advice including source and unknowns","facts":{}}]}. Include relevant facts only: multiplier (resolved current coefficient, null if unknown), futureMultiplier, waitSeconds, source (client-multipliers or unavailable), localStateStatus, permissionDenied (whether evidence supports a permission error), rateGuaranteed, setupPath, missingFileConfirmed. Keep booleans as booleans. A provisional reported value belongs in answer, not the resolved multiplier. Do not invent facts or recompute covered coefficients from raw rules.
'''
    source = json.loads((root / 'evals/review-scenarios.json').read_text())
    data = [{k: case[k] for k in ('id', 'prompt', 'input')} for case in source['scenarios']]
elif sys.argv[1:]:
    raise SystemExit('Usage: python3 evals/prepare.py [--parity|--review]')
else:
    data = cases
print(instruction)
print('<skill>\n' + (root / 'SKILL.md').read_text() + '\n</skill>')
print('<reference>\n' + (root / 'reference.md').read_text() + '\n</reference>')
print('<inputs>\n' + json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n</inputs>')
