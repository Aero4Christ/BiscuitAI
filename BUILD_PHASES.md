# BiscuitAI — Next Build Phases

This roadmap covers the remaining recommended work. Developer ID signing and notarization are intentionally out of scope here.

Each phase ends with a review gate. Do not begin the next phase until the current gate passes.

## Phase 5 — Repository and release hygiene

Scope:

- Connect the local project to `https://github.com/Aero4Christ/BiscuitAI.git` after user approval.
- Add `.gitignore` for `.build`, `Build`, `.DS_Store`, and local artifacts.
- Establish phase commits and tags.
- Add reproducible app version/build-number configuration.
- Keep README and handoff documents synchronized.

Review gate:

- A clean clone builds and tests successfully.
- No keys, local history, or generated bundles are tracked.
- Version and build number are visible in the packaged app.

## Phase 6 — Privacy and local-data controls

Scope:

- Add delete-all-conversations with confirmation.
- Add conversation export/import with a versioned format.
- Add a privacy explanation in Settings or Help.
- Decide whether local conversation encryption is necessary before implementing it.
- Add tests for export/import and destructive-action safeguards.

Review gate:

- Users can inspect, export, and delete their local data.
- Existing history remains migratable.
- Destructive actions are explicit and recoverability is clear.

## Phase 7 — Quality and diagnostics

Scope:

- Add fixture-based OpenRouter stream tests.
- Cover success, comments, `[DONE]`, 401, 402, 429, 502/503, and mid-stream errors.
- Test retry, cancellation, partial responses, and persistence migration.
- Add optional redacted diagnostics without keys or chat contents.
- Document a clean-machine smoke test.

Review gate:

- Network behavior is testable without live credentials.
- Reply lifecycle regressions fail automatically.
- Diagnostic output is safe to share.

## Phase 8 — Product polish

Prioritize with the user before implementation:

- Markdown and code rendering.
- Usage/cost display.
- Per-conversation model metadata.
- Improved keyboard submission and focus behavior.
- Image/file attachments for supported models.
- Conversation search and pinning.

Review gate:

- Each feature has a clear UX goal.
- The warm, restrained BiscuitAI visual language remains intact.
- Every feature has tests or a documented manual validation path.

## Standard phase review

At the end of each phase, report:

- Changed files.
- Tests and builds run.
- Manual checks completed.
- Remaining risks.
- Any decision requiring user input.
