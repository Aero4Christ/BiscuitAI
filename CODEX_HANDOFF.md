# BiscuitAI — Codex Handoff

## 1. Project identity and current status

BiscuitAI is a native macOS desktop chatbot built with SwiftUI and Swift Package Manager. Its purpose is to provide a polished, animated chat interface backed by OpenRouter’s API. The project was created for a Mac user who wants a colorful but comfortable interface, local conversation history, secure local API-key storage, selectable OpenRouter models, and a distinctive biscuit mascot.

The active project folder on the user’s Mac is:

```text
/Users/inline.graphics/Desktop/BiscuitAI
```

The latest packaged application is:

```text
/Users/inline.graphics/Desktop/BiscuitAI/Build/BiscuitAI.app
```

The latest release was compiled, packaged, strict-signature-validated, and launched successfully on the connected Mac. A live OpenRouter request was not performed because the user did not provide a personal API key during development.

## 2. Product and visual direction

The product voice is warm, capable, and playful without letting puns get in the way of useful answers. The mascot’s welcome copy includes the following lines:

| Situation | Copy |
| --- | --- |
| New chat | “What’s baking today?” |
| New-chat rotation | “Let’s get this dough rising!” |
| New-chat rotation | “Ready to whisk up something brilliant?” |
| While responding | “Biscuit is baking…” |
| Supporting copy | “Fresh from the oven,” “half-baked ideas worth finishing,” and similar restrained baking language |

The original palette was too bright, so it was replaced with two explicit application themes. The default warm-light theme uses a muted parchment background rather than bright white. The dark theme uses low-glare charcoal and cocoa surfaces. Both themes retain restrained aqua/teal accents that connect visually to the mascot’s blue jacket and cyan speech-bubble motif.

The theme is not delegated entirely to the system appearance. It is an application setting stored in `UserDefaults` and represented by `AppAppearance` in `Models.swift`. The app applies `.preferredColorScheme` to the window and passes a centralized `BiscuitTheme` object through the view tree.

## 3. Mascot implementation

The user supplied the definitive mascot image. It is a 1920×1920 RGB PNG showing a confident biscuit character with sunglasses, a blue technology-style jacket, dark pants, black-and-white sneakers, and a cyan speech bubble. This image is now the source of truth for every Biscuit visual in the application.

The mascot files are:

```text
Resources/BiscuitMascot.png
Sources/BiscuitAI/Resources/BiscuitMascot.png
```

The first copy is the project-level source copy. The second copy is processed as a Swift Package resource and is the copy loaded at runtime through:

```swift
Image("BiscuitMascot", bundle: .module)
```

The old Recraft-generated SVG, old generated PNG, and `RecraftBiscuitMark.swift` wrapper were removed from the connected Mac project. Do not reintroduce the former mascot or generate a replacement character. If additional visual assets are needed, use the supplied mascot as the exact reference and preserve its face, sunglasses, jacket, colors, and proportions.

`BiscuitMascot.swift` contains the reusable animated wrapper. It uses the supplied image with `scaledToFill`, clips it into a rounded square, adds a subtle white edge and shadow, and supports three presentation moods:

| Mood | Use |
| --- | --- |
| `.welcoming` | Sidebar, assistant messages, and general idle states |
| `.thinking` | Assistant response state, with a small three-dot overlay |
| `.celebrating` | Reserved for success or celebratory moments, with a sparkle overlay |

The breathing and tilt animations use approximately 1.2-second easing cycles. Keep future mascot animation subtle because the supplied artwork already contains a strong pose and visual identity.

The large new-chat hero uses the supplied image directly with `scaledToFit`, so the entire character and speech bubble remain visible. Small avatars use the reusable `BiscuitMascot` wrapper and intentionally crop the source to keep the face and upper body legible.

## 4. Source tree

The important source tree is:

```text
BiscuitAI/
├── Package.swift
├── README.md
├── CODEX_HANDOFF.md
├── Resources/
│   ├── BiscuitMascot.png
│   └── Info.plist
├── Scripts/
│   └── build_app.sh
└── Sources/
    └── BiscuitAI/
        ├── BiscuitAIApp.swift
        ├── BiscuitMascot.swift
        ├── ChatStore.swift
        ├── ConversationStore.swift
        ├── Keychain.swift
        ├── Models.swift
        ├── OpenRouterClient.swift
        ├── RequestContextBuilder.swift
        ├── SettingsStore.swift
        └── Resources/
            └── BiscuitMascot.png
Tests/
└── BiscuitAITests/
    └── BiscuitAITests.swift
```

`Package.swift` defines an executable Swift package targeting macOS. The executable target processes the local `Resources` directory under `Sources/BiscuitAI`, which is why the mascot is available through `Bundle.module`.

`BiscuitAIApp.swift` contains the main SwiftUI application, split view, sidebar, header, new-chat welcome screen, conversation view, chat bubbles, composer, settings sheet, appearance palette, and reusable button/card/background styling.

`SettingsStore.swift` owns appearance, system prompt, temperature, API-key profiles, selected model, model refresh state, and Keychain interaction. `ChatStore.swift` owns local conversation history, streaming state, buffering, cancellation, retry, and user-facing notices. `OpenRouterClient.swift` owns the injectable model-catalog request and streaming chat request. `ConversationStore.swift` owns atomic local JSON persistence, and `RequestContextBuilder.swift` bounds the request context for long conversations.

`Models.swift` defines chat roles, conversations, messages, `AppAppearance`, `APIKeyProfile`, `ModelOption`, OpenRouter request structures, streaming chunks, and the live model-catalog response structures.

`Keychain.swift` provides a small wrapper around macOS Security framework generic-password items. Each profile has its own Keychain account identifier. The API key is never written into source files or the conversation store.

## 5. OpenRouter architecture

BiscuitAI connects directly to OpenRouter from the native app. There is no hosted backend, proxy server, or database in this project.

The model catalog request is:

```text
GET https://openrouter.ai/api/v1/models
Authorization: Bearer <active OpenRouter key>
```

The chat request is:

```text
POST https://openrouter.ai/api/v1/chat/completions
Authorization: Bearer <active OpenRouter key>
Content-Type: application/json
Accept: text/event-stream
```

The request body contains the selected model, a system message, the local conversation messages, `stream: true`, temperature, and a `max_tokens` value of 4096.

The current streaming parser reads `URLSession.shared.bytes(for:)`, iterates through `bytes.lines`, ignores non-`data:` lines, handles `[DONE]`, decodes JSON chunks, appends `choices[].delta.content`, and surfaces mid-stream error payloads when an `error` field is present. This is consistent with OpenRouter’s current streaming guidance, which notes that SSE comments such as `: OPENROUTER PROCESSING` should be ignored and that mid-stream errors can arrive inside a `data:` event. The client is exposed through `OpenRouterServicing` so tests can inject a fake service.

The app sends the optional `X-OpenRouter-Title: BiscuitAI` header. It does not currently send a site URL because this is a native desktop app rather than a public website.

Important product interpretation: an OpenRouter key is a general key that can call whatever models the key’s account, credits, limits, and permissions allow. Selecting a model does not transform the key into a provider-native key. The interface therefore uses the wording “active OpenRouter key” and “model billed to this key.”

The current starter model examples are only fallbacks for an empty or not-yet-refreshed catalog. They include:

| Provider/family | Starter model ID |
| --- | --- |
| OpenAI | `openai/gpt-5.2` |
| Google | `google/gemini-3.7-flash` |
| SpaceXAI/xAI | `x-ai/grok-4.6` |
| DeepSeek | `deepseek/deepseek-v4-pro-0813` |
| Qwen | `qwen/qwen3.8-27b` |
| NVIDIA | `nvidia/nemotron-3.5-lightning:free` |

The live refresh is the authoritative catalog. The user asked for a sweep of available AIs, but hard-coding the entire catalog would become stale quickly. The current implementation uses the live response and supports search, a free-only filter, visible model descriptions, model IDs, modality metadata, and manual model-ID entry. OpenRouter’s current public model page describes a catalog of 500+ models across providers including OpenAI, Anthropic, Google, and Meta.

## 6. API-key profiles and settings behavior

`SettingsStore` persists non-secret profile metadata as JSON in `UserDefaults`. System-prompt and temperature writes are debounced. It stores the corresponding secret value in Keychain. The stored profile metadata includes:

```swift
struct APIKeyProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String
    let keychainAccount: String
    var selectedModel: String
    let createdAt: Date
}
```

The Settings screen supports the following workflows:

1. Choose the active named OpenRouter profile.
2. Rename the active profile.
3. Save or clear the active profile’s general OpenRouter API key.
4. Add another named profile with an optional initial model ID.
5. Remove the selected profile, while preserving a replacement profile if it is the last one.
6. Refresh the model catalog using the active profile’s key.
7. Search catalog entries by model name or model ID.
8. Filter to models whose prompt and completion pricing are both reported as zero.
9. Paste or type a model ID manually.
10. Select the active model that will be used on the next reply.
11. Edit the system prompt and temperature.
12. Switch between warm light and dark appearance.

The existing legacy Keychain account `openrouter-api-key` is migrated into the first new profile when possible. Preserve this migration behavior if the profile format is changed.

## 7. Local persistence

Conversations are encoded atomically to `Application Support/BiscuitAI/conversations.json`. Existing data under the legacy `UserDefaults` key `biscuitai-conversations-v1` is migrated when the new store is first created. They are local to the Mac and are not uploaded by BiscuitAI except for the messages included in an OpenRouter request when the user sends a prompt.

Settings metadata is stored under versioned `UserDefaults` keys, including the profile list, active profile ID, appearance, system prompt, and temperature. API-key values are stored separately in Keychain accounts beginning with `openrouter-profile-`.

Do not move API keys into `UserDefaults`, plain JSON, the source tree, the README, or the conversation archive.

## 8. Build and package workflow

From Terminal on the user’s Mac:

```bash
cd "/Users/inline.graphics/Desktop/BiscuitAI"
swift test
swift build
```

For a release build and app bundle:

```bash
cd "/Users/inline.graphics/Desktop/BiscuitAI"
./Scripts/build_app.sh
open "Build/BiscuitAI.app"
```

`Scripts/build_app.sh` performs the following steps:

1. Builds the release executable.
2. Creates `Build/BiscuitAI.app/Contents/MacOS` and `Contents/Resources`.
3. Copies the executable and `Info.plist`.
4. Copies `BiscuitAI_BiscuitAI.bundle` so the mascot resource is available at runtime.
5. Runs `xattr -cr` to remove Finder metadata that can cause strict code-signature validation failures.
6. Applies an ad-hoc local signature with `codesign --force --deep --sign -`.

This is a local-development app. It is not notarized or distributed through the Mac App Store. If Codex later prepares a distributable build, it will need a proper Developer ID signing and notarization workflow.

## 9. Validation already completed

The following checks were completed on the connected Mac after the refresh:

| Check | Result |
| --- | --- |
| Swift debug build | Passed |
| XCTest suite | Passed |
| Swift release build | Passed |
| App-bundle packaging | Passed |
| Strict deep code-signature verification | Passed |
| `Info.plist` validation | Passed |
| Mascot resource present inside the app bundle | Passed |
| Direct launch of the refreshed executable | Passed |
| No previous Recraft asset or old SVG in the project resources | Passed |
| Live OpenRouter chat request | Manually tested by the user |

## 10. Recommended next steps for Codex

Codex should first inspect `Package.swift`, `README.md`, this handoff, and every file under `Sources/BiscuitAI`. It should also check for any local `AGENTS.md` instructions before editing.

The Phase 1–4 settings, profile, model, streaming, retry, and cancellation flows have been manually tested by the user. Do not log or print the key during any future testing.

The next UI validation should inspect both appearance modes at the minimum window size and at a wide window size. Confirm that the user-supplied mascot remains legible in the hero, sidebar, settings, and assistant-message avatar. Confirm that the hero image is not unintentionally cropped and that text maintains sufficient contrast against both themes.

The OpenRouter parser has structured handling for normal streaming chunks, SSE comments, `[DONE]`, pre-stream HTTP errors, and mid-stream error events. Add fixture-based tests for those paths in the next quality phase.

The model refresh should be tested with an invalid key, a key with no credits, and a successful key. The UI should remain usable with the starter catalog when refresh is unavailable. Do not assume that every model in the starter list remains available forever; keep the live refresh and manual model-ID entry.

Next work should proceed through repository hygiene, privacy/data controls, fixture-based quality tests, and optional product polish. Developer ID signing and notarization are intentionally excluded from the current handoff plan.

## 11. External references

[1]: https://openrouter.ai/models "OpenRouter model catalog"
[2]: https://openrouter.ai/docs/api_reference/authentication "OpenRouter authentication"
[3]: https://openrouter.ai/docs/api_reference/streaming "OpenRouter streaming"
[4]: https://openrouter.ai/docs/api_reference/overview "OpenRouter API reference overview"
