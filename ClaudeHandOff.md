# BiscuitAI — Claude Handoff

## Handoff purpose

This document is for continuing BiscuitAI development in Claude. It records the current implementation, completed build phases, verified behavior, known documentation corrections, and the next phased work. Treat the source code as authoritative if this document and an older note disagree.

Project path:

```text
/Users/inline.graphics/Desktop/BiscuitAI
```

The local project is currently a Swift Package Manager macOS executable. The folder is not presently a local Git working tree; the intended upstream repository is:

```text
https://github.com/Aero4Christ/BiscuitAI.git
```

Do not push, rewrite history, or change remotes without explicit user approval.

## Current product

BiscuitAI is a native SwiftUI macOS chatbot using OpenRouter directly. It provides:

- Warm-light and dark application themes.
- Multiple named OpenRouter API-key profiles stored in Keychain.
- Live model catalog refresh, search, free-only filtering, and manual model IDs.
- Local conversation history.
- Streaming replies with buffered UI updates.
- Stop, retry, failed, cancelled, and partial-response states.
- Model-aware context trimming and dynamic output-token limits.
- Selectable response text and copy controls.
- Animated supplied Biscuit mascot artwork.

The app does not use a hosted backend. API keys and conversation history remain local except for messages included in a request sent to OpenRouter.

## Current source structure

```text
Package.swift
README.md
CODEX_HANDOFF.md
ClaudeHandOff.md
Resources/
  BiscuitMascot.png
  Info.plist
Scripts/
  build_app.sh
Sources/BiscuitAI/
  BiscuitAIApp.swift
  BiscuitMascot.swift
  ChatStore.swift
  ConversationStore.swift
  Keychain.swift
  Models.swift
  OpenRouterClient.swift
  RequestContextBuilder.swift
  SettingsStore.swift
  Resources/BiscuitMascot.png
Tests/BiscuitAITests/
  BiscuitAITests.swift
```

Important ownership boundaries:

- `BiscuitAIApp.swift`: SwiftUI views and app composition.
- `SettingsStore.swift`: profiles, appearance, prompt, temperature, Keychain access, and model refresh state.
- `ChatStore.swift`: conversations, streaming lifecycle, buffering, reply states, retry, cancellation, and persistence orchestration.
- `OpenRouterClient.swift`: injected OpenRouter service and SSE client.
- `ConversationStore.swift`: injected atomic JSON persistence under Application Support.
- `RequestContextBuilder.swift`: bounded prompt construction.
- `Keychain.swift`: generic-password Keychain wrapper.
- `Models.swift`: domain and OpenRouter Codable types.

## Completed phases

### Phase 1 — Request reliability

Completed:

- Structured HTTP and mid-stream OpenRouter errors.
- SSE `[DONE]`, comments, cancellation, and finish-error handling.
- Request timeouts.
- Active conversation tracking.
- Tracked reply task and Stop control.
- Safe Keychain update behavior.

### Phase 2 — Performance and persistence

Completed:

- Token buffering at approximately 60 ms intervals.
- Reduced SwiftUI and persistence churn during streaming.
- Atomic conversation JSON storage in Application Support.
- Migration from `biscuitai-conversations-v1` in `UserDefaults`.
- Model-aware context trimming and dynamic `max_tokens`.

### Phase 3 — Architecture and tests

Completed:

- State and networking split out of the former monolithic `AppState.swift`.
- `ConversationPersisting` and `OpenRouterServicing` injection seams.
- Four XCTest cases covering persistence, missing stores, context trimming, and error-code decoding.

### Phase 4 — UX resilience

Completed:

- Explicit idle, streaming, failed, and cancelled reply states.
- Retry for failed and cancelled responses.
- Partial response preservation after a provider error.
- Debounced system-prompt and temperature persistence.
- Clearer empty model-catalog feedback.

## Verification status

The following currently pass:

```bash
swift build
swift test
swift build -c release
./Scripts/build_app.sh
```

The packaged application is written to:

```text
Build/BiscuitAI.app
```

Manual testing has also been completed by the user, including the Phase 4 workflows.

## Data and security rules

- Never print, log, commit, or place an API key in documentation.
- API keys belong in macOS Keychain accounts beginning with `openrouter-profile-`.
- Profile metadata belongs in versioned `UserDefaults` keys.
- Conversations belong in the Application Support JSON store, not new `UserDefaults` keys.
- Do not silently remove existing history or Keychain migration paths.
- Any future diagnostics must redact keys, authorization headers, prompts, and chat contents.

## Remaining build phases

These phases intentionally exclude Developer ID signing and notarization.

### Phase 5 — Repository and release hygiene

Scope:

- Connect the local project to the supplied GitHub remote after user approval.
- Add `.gitignore` for `.build`, `Build`, `.DS_Store`, and local artifacts.
- Add a clean repository status/check script.
- Establish meaningful commits and tags for completed phases.
- Add version/build-number configuration to `Info.plist` and the build script.
- Keep `README.md`, `CODEX_HANDOFF.md`, and this document synchronized.

Review gate:

- Clean clone builds successfully.
- No API keys or generated app artifacts appear in Git.
- The app version and build number are visible and reproducible.

### Phase 6 — Privacy and local-data controls

Scope:

- Add “Delete all conversations” with confirmation.
- Add conversation export/import with an explicit format and migration version.
- Add a privacy/settings explanation of Keychain, local storage, and OpenRouter transmission.
- Decide whether local conversation encryption is required; document the tradeoff before implementing it.
- Add tests for export/import and destructive-action safeguards.

Review gate:

- Users can inspect, export, and delete their data.
- Existing history remains migratable.
- Destructive actions require confirmation and have clear scope.

### Phase 7 — Quality and diagnostics

Scope:

- Add API fixture tests for successful streams, SSE comments, `[DONE]`, 401, 402, 429, 502/503, and mid-stream errors.
- Add tests for retry, cancellation, and partial responses.
- Add persistence migration tests using an isolated defaults suite.
- Add optional redacted diagnostic logging with no keys or message contents.
- Add a clean-machine smoke-test checklist.

Review gate:

- Network behavior is tested without live credentials.
- Cancellation and retry regressions are caught automatically.
- Diagnostics are safe to share.

### Phase 8 — Product polish

Potential scope, prioritize with the user:

- Markdown/code rendering.
- Usage and cost display from OpenRouter usage/generation data.
- Per-conversation model metadata.
- Better keyboard submission and focus behavior.
- Image/file attachments for supported input modalities.
- Conversation search and pinning.

Review gate:

- Each feature has a documented UX goal and does not compromise the current warm, restrained interface.

## Build commands

```bash
cd "/Users/inline.graphics/Desktop/BiscuitAI"
swift test
swift build -c release
./Scripts/build_app.sh
open "Build/BiscuitAI.app"
```

## Working style for the next agent

Work one phase at a time. Review the relevant source and this handoff before editing. Preserve the existing mascot, Keychain migration, conversation migration, dependency-injection seams, and local-only secret handling. At the end of each phase, report changed files, tests, build results, manual checks still required, and any decision that needs user input.
