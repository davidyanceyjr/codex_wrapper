# portability-review

Purpose
-------
Identify platform assumptions and accidental non-portability.

Procedure
---------
1. Inspect code and build scripts for GNU-specific flags, shell-specific constructs, OS-specific syscalls, UB, and compiler assumptions.
2. Distinguish intentional platform targeting from accidental non-portability.
3. Recommend documenting Linux-only intent or removing accidental assumptions.
4. Note testing gaps across environments.
