# 0007. Store settings by name, never by index

Status   - Accepted
Date     - standing
Commits  - `6f128d5` and the ExtState rename that followed

## Context

Scales, roots and highlight colours live in ordered tables. Saving the user's
choice as an index is one integer and is wrong the first time anybody inserts
a row: every existing install silently repoints to a different colour.

## Decision

Every stored choice is a **name**. Reading resolves the name against the
current table and falls back to the default when it no longer exists.
`EXT_LEGACY` and `PROJECT_LEGACY` carry the section names used under earlier
script names so a rename does not reset an existing install.

## Consequences

- Tables can be reordered freely, and entries added, without touching anyone's
  settings.
- **Dropping an entry is the case that needs a test**, because it exercises
  the fallback. Both suites keep one, pointed at whichever name has most
  recently left the palette (White until 2026-09-18, Gold after it).
- A key is tied to what a script *is*, not what it is called. The ExtState
  keys were renamed once, in the single moment when the scripts had exactly
  one install; there will be no second free moment.

## Evidence

`CLAUDE.md`, *REAPER API facts* and *Publishing through ReaPack*. The plugin
does the same through `indexOfNamed`, and a test patches the highlight name
inside a real saved state block to prove the fallback - **asserting the root
and scale came through as well**, because a state block that failed to parse
would otherwise leave the default in place and pass the test for free.
