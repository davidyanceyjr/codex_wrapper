# c-triage

Purpose
-------
Classify and attack failures in C code with the right debugging approach.

Procedure
---------
1. Classify the failure: compile, link, crash, sanitizer, logic, performance.
2. Reproduce reliably.
3. Recommend flags such as `-Wall -Wextra -g -fsanitize=address,undefined`.
4. Pick the right tool: compiler diagnostics, sanitizers, gdb, or logging.
5. Narrow the failing region and identify likely root cause.
6. Remove temporary instrumentation after the fix and recommend regression tests.
