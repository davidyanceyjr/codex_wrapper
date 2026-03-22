# preflight

Purpose: Verify repository state before committing.

Procedure:
1. Ensure build succeeds.
2. Ensure all tests pass.
3. Confirm the active issue, branch, and diff still match one coherent scope.
4. Check documentation updates.
5. Review staged changes for scope.
6. Confirm no debug artifacts remain.
7. Confirm the change is ready for commit and push.

Output:
- Build status
- Test status
- Issue / branch alignment
- Documentation status
- Commit readiness
