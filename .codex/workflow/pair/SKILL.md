# pair

Purpose
-------
Run one human+AI implementation slice with explicit decision boundaries.

This is the collaboration-centered workflow step. The human should stay focused
on decisions, scope, and review, while the AI performs the bounded execution
work.

The AI is not meant to replace human judgment here. It is meant to carry the
execution work inside a clearly approved slice.

Procedure
---------
1. Restate the current slice and the files in scope.
2. Make explicit:

   - what the AI will do now
   - which lane owns the work: `docs`, `src`, `test`, or `debug` when useful
   - what the human must decide, if anything
   - what validation closes the slice
   - what conditions would cause the AI to stop and escalate

3. Confirm the collaboration split:

   - the human owns direction, scope approval, and decision-making
   - the AI owns bounded execution, status reporting, explicit escalation, and
     repetitive git/GitHub commands after approval

4. Implement only the controlled behavior for the current slice.
5. If an uncontrolled decision appears, stop and escalate it clearly instead of
   filling the gap by assumption.
6. Before ending the slice, state:

   - what changed
   - what remains open
   - whether the slice stayed in scope
   - whether the next step is `test` or `review`
   - what that next step will do
