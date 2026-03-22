# list-skills

Purpose
-------
Read `.codex/INDEX.md` and print the repository's available skills
in a clean, human-readable list.

This skill is intended as a lightweight skill discovery helper for
Codex sessions where built-in skill listing is not obvious enough.

Use When
--------
- you want to see available repo skills
- you forget the exact skill names
- you want a quick menu before starting work
- you want to confirm that `.codex/INDEX.md` is current

Inputs
------
.codex/INDEX.md

Procedure
---------
1. Read `.codex/INDEX.md`.
2. Parse category headings and the listed skills beneath them.
3. Print the skills grouped by category.
4. Preserve the names exactly as written in `.codex/INDEX.md`.
5. Do not invent skills that are not listed.
6. If `.codex/INDEX.md` is missing or incomplete, say so clearly.
7. Optionally highlight common starting points:
   - start
   - spec
   - issue
   - finish

Output Format
-------------

Available Skills
----------------

<category>
- <skill-name>
- <skill-name>

<category>
- <skill-name>
- <skill-name>

Suggested Starting Skills
-------------------------
- start
- spec
- issue
- finish

Rules
-----
- Treat `.codex/INDEX.md` as the source of truth.
- Do not scan the filesystem unless the index is missing.
- Keep output concise and readable.
- Preserve category structure from the index.
