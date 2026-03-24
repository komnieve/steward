#!/bin/bash
# Updates the stuck item tracker after a steward run
# Called by the steward's deep-think phase — the steward outputs a JSON block
# tagged with STUCK_UPDATE that this script parses and merges
#
# Usage: steward-update-stuck.sh <steward-output-file>

set -euo pipefail

STUCK_FILE="$HOME/.claude/steward-stuck.json"
STEWARD_OUTPUT="${1:-}"

if [ -z "$STEWARD_OUTPUT" ] || [ ! -f "$STEWARD_OUTPUT" ]; then
  exit 0
fi

# Look for STUCK_UPDATE JSON block in steward output
# Format: <<<STUCK_UPDATE>>> { json } <<<END_STUCK_UPDATE>>>
STUCK_BLOCK=$(sed -n '/<<<STUCK_UPDATE>>>/,/<<<END_STUCK_UPDATE>>>/p' "$STEWARD_OUTPUT" 2>/dev/null | grep -v '<<<' || true)

if [ -z "$STUCK_BLOCK" ]; then
  exit 0
fi

# Merge the update into the existing stuck file using python
python3 -c "
import json, sys

try:
    with open('$STUCK_FILE', 'r') as f:
        existing = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    existing = {'items': {}, 'escalation_levels': {}}

try:
    update = json.loads('''$STUCK_BLOCK''')
except json.JSONDecodeError:
    sys.exit(0)

# Merge: update existing items, add new ones
if 'items' in update:
    for key, val in update['items'].items():
        if key in existing.get('items', {}):
            # Update existing: increment count, update dates
            item = existing['items'][key]
            item['times_flagged'] = val.get('times_flagged', item.get('times_flagged', 0) + 1)
            item['last_flagged'] = val.get('last_flagged', item.get('last_flagged'))
            if 'escalation_level' in val:
                item['escalation_level'] = val['escalation_level']
            if 'last_action_taken' in val:
                item['last_action_taken'] = val['last_action_taken']
            if 'notes' in val:
                item['notes'] = val['notes']
        else:
            existing.setdefault('items', {})[key] = val

# Remove items marked as resolved
if 'resolved' in update:
    for key in update['resolved']:
        existing.get('items', {}).pop(key, None)

with open('$STUCK_FILE', 'w') as f:
    json.dump(existing, f, indent=2)

print(f'Stuck tracker updated: {len(existing.get(\"items\", {}))} items')
" 2>/dev/null || echo "Warning: stuck tracker update failed"
