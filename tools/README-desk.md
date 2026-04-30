# desk — CLI for priorities.json

Edits `$STEWARD_HOME/focus-dash/priorities.json` atomically under `flock`. If the
focus-dash server is running, it watches the file's mtime and pushes SSE updates
to the UI, so the browser tab reloads automatically after any `desk` mutation.

## Why this exists

Before: an agent reads the whole JSON and does an Edit with large string replacements, burning context per mutation.
After: `desk add-today --title "..."` or `desk done <id>` — one bash line, minimal context.

## Configuration

- `STEWARD_PRIORITIES` — path to `priorities.json` (overrides default)
- `STEWARD_HOME` — base dir; priorities default to `$STEWARD_HOME/focus-dash/priorities.json`
- `STEWARD_ACTIVITY_DB` — path to activity.db (overrides default)

If neither is set, `desk` assumes it's installed as `$STEWARD_HOME/bin/desk` and uses sibling paths.

## Commands

```
desk list [SECTION]                list items (default: all sections)
desk show ID                       show one item as pretty JSON
desk add-today --title T [...]     add a priority to today[]
desk add-room  --title T [...]     add an item to if_theres_room[]
desk done ID                       today -> done, log to activity.db
desk undone ID                     reverse done -> today
desk remove ID|TITLE               delete item (matches id, falls back to title)
desk move ID --to SECTION          move between today|done|if_theres_room
desk set ID FIELD VALUE            set a top-level field (title|context|estimate)
desk northstar TEXT [--horizon H]  update the northstar block
desk subtitle TEXT                 update the dashboard subtitle
desk from-file PATH --to SECTION   load a full JSON item from a file
desk clear-done                    wipe done[]
desk append-expand ID --kind K --heading H --body B [--copyable] [--release R]
```

## add-today flags

```
--title T                (required)
--context "..."
--estimate "~60 min"
--id "custom-id"         (default: slugify title)
--action-label "Open X"  pairs with action-url
--action-url  "https://..."
--log-project  client-a  ) when all --log-* flags are set, the item
--log-category writing   ) gets a `log` block that desk done
--log-activity "..."     ) writes to $STEWARD_HOME/activity.db
--log-duration 60
--log-notes "..."
--expand-file path.json  load a pre-written expand block
```

## Complex items (with expand sections)

For anything with nested `expand.sections`, write a JSON file and pass it:

```bash
desk from-file /tmp/new-priority.json --to today
```

Or build it up incrementally:

```bash
desk add-today --title "Ship the thing" --context "..."
desk append-expand ship-the-thing --kind action --heading "Do this now" --body "Step 1..."
desk append-expand ship-the-thing --kind paste --heading "Copy this" --body "..." --copyable
desk append-expand ship-the-thing --kind block --heading "What's in the way" --body "..." --release "..."
```

## Safety

- `flock` on every read-modify-write — safe against concurrent edits by server.py or parallel CLI calls
- `find_item` matches ids first, then titles — no silent wrong-item edits
- `done` replicates server.py's `_mark_done` logic incl. activity-db write
- On failure, the lock is released and the original JSON stays intact (atomic truncate+write under the lock)

## Not yet implemented

- Reordering within a section (e.g. bump priority to top)
- Editing an existing expand block (only append / full-replace via from-file)
- Fuzzy id match (current match is exact)
