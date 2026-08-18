---
type: session-snapshot
date: 2026-08-18
project: BiscuitAI
tags: [codex, handoff, save]
---

# Session Snapshot

## Summary

- BiscuitAI now supports OpenRouter image generation in addition to streamed text chat.
- Mascot assets, circular presentation, light-theme styling, and packaged resource loading were corrected.
- The completed image-generation phase is pushed to GitHub in commit `aa25bd9`.

## Work Completed

- Added an image-generation mode using the photo button beside the composer.
- Added OpenRouter `/api/v1/images` support with base64 image decoding.
- Added generated-image rendering inside assistant chat bubbles.
- Added “Save image” export through a macOS save panel.
- Persisted generated image data with conversation history.
- Added an editable image model ID in Settings, defaulting to `openai/gpt-5-image`.
- Added circular clipping for mascot/chat images and retained the rounded-square app icon in the sidebar.
- Changed the light appearance to a near-white biscuit/cream palette with subtle orange warmth.
- Changed appearance labels from “Warm light” / “Dark” to “Light” / “Dark”.
- Updated build signing to prefer a stable signing identity when available.

## Files Changed

- `Sources/BiscuitAI/OpenRouterClient.swift`: Added the dedicated OpenRouter image-generation request and response decoding.
- `Sources/BiscuitAI/Models.swift`: Added image fields to `ChatMessage`, image response models, output modalities, and `GeneratedImage`.
- `Sources/BiscuitAI/ChatStore.swift`: Added image-generation workflow, loading state, persistence, and failure handling.
- `Sources/BiscuitAI/BiscuitAIApp.swift`: Added image mode UI, image rendering, save action, image-model setting, circular mascot presentation, and updated light theme.
- `Sources/BiscuitAI/SettingsStore.swift`: Added persisted image-model preference.
- `Sources/BiscuitAI/BiscuitMascot.swift`: Changed mascot presentation from rounded square to circle.
- `Sources/BiscuitAI/BiscuitResources.swift`: Added direct packaged image loading and app-icon resolution.
- `Scripts/build_app.sh`: Prefers stable code signing and warns when falling back to ad-hoc signing.
- `Tests/BiscuitAITests/BiscuitAITests.swift`: Added image-message persistence and base64 response-decoding tests.

## Verification

- `swift test`: passed, 6 tests with 0 failures.
- `./Scripts/build_app.sh`: release app built successfully as `Build/BiscuitAI.app`.
- Packaged resources verified: app icon, mascot, new-chat circle, and chat-bubble images are present.
- `git diff --check`: passed.
- Git status: clean; branch `main` is synchronized with `origin/main`.

## Decisions

- Normal text chat remains on `/api/v1/chat/completions`.
- Image generation uses the dedicated `/api/v1/images` endpoint rather than making image generation implicit inside normal chat.
- Generated images are stored directly in conversation JSON as base64-backed `Data`; this is simple for the current phase but may need external file storage if conversations become large.
- The app currently uses ad-hoc signing because this Mac has no valid signing identity installed. A stable Apple Development or Developer ID identity is needed to prevent recurring Keychain authorization prompts across rebuilt versions.

## Risks / Open Questions

- The first live image-generation request has not been verified with the user’s private OpenRouter key and account credits.
- `openai/gpt-5-image` may need to be replaced with an image model available to the user’s OpenRouter account.
- Image generation pricing and model availability are controlled by OpenRouter and may change.
- Large generated images stored inline in conversation JSON could eventually increase file size and load time.
- The ad-hoc signature warning remains until a stable signing identity is installed.

## Next Steps

1. Open `/Users/inline.graphics/Desktop/BiscuitAI/Build/BiscuitAI.app`.
2. Confirm the OpenRouter key is present in Settings.
3. Confirm the Image model field contains `openai/gpt-5-image`, or replace it with an available OpenRouter image model.
4. Click the photo button, enter `A small golden retriever puppy sitting in a sunny meadow`, and send.
5. Confirm the image renders, persists after reopening the chat, and can be saved.
6. If Keychain prompts continue, install/configure a stable Apple signing identity.
