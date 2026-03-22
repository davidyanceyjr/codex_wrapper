# api-surface-review

Purpose
-------
Inspect the public interface for clarity, cohesion, and breakage risk.

Procedure
---------
1. Identify the public surface: headers, exported functions, CLI commands/options.
2. Check for naming consistency, unnecessary exposure, ambiguous contracts, and accidental breaking changes.
3. Recommend simplification where possible.
4. Separate internal convenience from public obligations.
