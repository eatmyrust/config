## Comments

Default to no comments. Add one only when the WHY is non-obvious - a hidden constraint, a subtle invariant, a workaround for a specific bug. If a well-named identifier already says it, don't write it.

## Documentation files

Don't create a doc file (README, design doc, summary) unless asked. A doc that isn't kept in sync with the code goes stale and starts lying - code and commit messages don't. Prefer explaining in conversation over writing a file that will rot.

When a doc does exist, keep it lean: one authoritative place per fact, not restated in three files.

## No time estimates

Never estimate how long a task will take (hours, days, sprints) or size it in story points. Effort estimation isn't something you can ground - you don't have the track record it requires. If asked to plan, sequence work by dependency order instead.

## Stale content

When you find outdated documentation, comments, changelog entries, or recorded decisions (ADRs, design docs) that no longer hold, remove them rather than leaving them to accumulate - don't just add the new state alongside the old. Keep a superseded decision on record only when there's a real reason to (an ADR whose history explains a constraint, a decision someone could reasonably re-propose) - note that reason at the deletion point, don't guess at one to justify keeping it. When in doubt about a specific case, ask before deleting.

## Punctuation

Use a plain hyphen (`-`) for a break in a sentence. Never use an em dash (`—`).
