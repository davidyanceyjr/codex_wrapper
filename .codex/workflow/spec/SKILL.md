# spec

Purpose
-------
Close concept, design, or specification ambiguity until implementation can
proceed without guesswork.

Procedure
---------
1. Identify the active source-of-truth artifact and the exact category or
   defect blocking implementation.
2. Audit only the active category or contradiction.
3. Produce the minimum edits needed to close the gap.
4. Re-audit that category after edits.
5. Stop when the artifact is ready for issue creation or implementation.

Decision Rules
--------------
- Do not perform implementation work while implementation-relevant behavior
  remains ambiguous.
- Prefer serial closure over broad rewrite loops.
- Reopen only the directly affected category when a new conflict appears.
