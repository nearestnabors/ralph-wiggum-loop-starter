## Instructions

1. Study `spec.md` thoroughly. Understand the full architecture and conventions.
2. Study `implementation-plan.md` thoroughly. Understand all tasks and their status.
3. Pick the highest-leverage **unchecked** task from the implementation plan.
4. **Red phase:** Write a test for the task. Run it. **Confirm it fails.** If the test already passes, your test isn't exercising new behaviour. Rewrite it until it genuinely fails.
5. **Green phase:** Implement the task until the failing test passes.
6. Run the **full test suite** to confirm nothing else broke. If something is broken, fix it and rerun the test suite until it passes.
7. If everything passes, update `implementation-plan.md` to mark the task as `[x]`.
8. If all tasks are checked, create a file called `DONE` in the project root.

## Project Context

(Please update this to reflect your spec.md)

- Language: TypeScript
- Test framework: vitest
- Key conventions: use functional components, no ORMs, prefer explicit over implicit
- Directory structure:
  ```
  src/
  tests/
  spec.md
  implementation-plan.md
  ```
- Tools available: (list any MCP tools CLI commands)
- Resources available: (link to files or sites)

## Rules
- Only work on ONE task per session.
- Do NOT modify the spec unless something is genuinely wrong (document why).
- Keep changes focused and minimal.
- **Use red/green TDD.** Always write the test first, confirm it fails (red), then implement until it passes (green). Never mark a task done on a test that was already passing.
- **Run the full test suite** after implementation to catch regressions before marking a task done.
- If your test still fails after two implementation attempts, or if your implementation breaks existing tests that you can't fix, use `git checkout` to revert your changes to the affected files. Do NOT mark the task as complete — leave it unchecked for the next iteration. Add a single-line note below the task describing what failed, prefixed with `  ⚠️`. Example:
  ```
  - [ ] Implement user registration endpoint
    ⚠️ bcrypt import failed — may need native dependency installed
  ```
- If a task already has 3 failure notes, skip it entirely and move to the next unchecked task. Tasks with 3 failures likely need human intervention.
- You can use `git diff`, `git status`, and `git log` to understand the current state of the codebase.
- You do NOT have permission to `git commit`. The outer script handles commits.
