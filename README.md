# BiscuitAI

**BiscuitAI** is a native macOS chat app built with SwiftUI. It connects directly to OpenRouter, stores saved keys in the local Mac Keychain, keeps conversations on the Mac, and uses the supplied BiscuitAI mascot throughout the welcome screen and chat interface.

Development status and upcoming work are tracked in [BUILD_PHASES.md](BUILD_PHASES.md). Agent handoff context is maintained in [CODEX_HANDOFF.md](CODEX_HANDOFF.md) and [ClaudeHandOff.md](ClaudeHandOff.md).

> **Biscuit’s greeting:** “What’s baking today?”

## Open the app

The ready-to-use app bundle is located at `Build/BiscuitAI.app`. Open it from Finder or run:

```bash
open "$HOME/Desktop/BiscuitAI/Build/BiscuitAI.app"
```

In **Settings**, choose a warm light or dark appearance, then save an OpenRouter key under **OpenRouter key profiles**. You can give profiles meaningful names such as *Personal credits* or *Work credits*, switch the active key, and select a model whose usage is charged against that key.

| Area | What it provides |
| --- | --- |
| **Mascot** | Your supplied, sunglasses-wearing biscuit character appears everywhere Biscuit represents itself. |
| **Appearance** | A softer parchment-toned warm-light interface and a low-glare dark interface, switchable in Settings. |
| **Key profiles** | Multiple named OpenRouter keys, each stored locally in Keychain and selectable for the next response. |
| **Model catalog** | Searchable current model list, optional free-only filter, manual model-ID input, and live refresh from OpenRouter. |
| **Chat** | Local history, streamed replies, selectable message text, copy action, baking-pun empty states, and a system prompt control. |

## Model catalog and credits

OpenRouter’s live catalog changes frequently, so BiscuitAI does not freeze a stale list of models in the app. After you save a key, use **Refresh catalog** to retrieve the models available to that key and search by provider, model name, or model ID. The starter list illustrates current examples across OpenAI, Google, SpaceXAI, DeepSeek, Qwen, and NVIDIA; the live catalog is the authoritative choice list. OpenRouter reports a catalog of 500+ models from providers such as OpenAI, Anthropic, Google, Meta, and more through one API. [1]

A saved OpenRouter key is a general key: it can call the models your account is authorized and funded to use. Select a different profile when you want a different key and credit pool; select a different model when you want a different model billed to the active key. OpenRouter authenticates these requests using a Bearer API key and supports optional per-key credit limits. [2]

## Rebuild after source changes

```bash
cd "$HOME/Desktop/BiscuitAI"
./Scripts/build_app.sh
```

This compiles the Swift package, embeds the current mascot resource, clears Finder metadata, applies a local ad-hoc signature, and writes the bundle to `Build/BiscuitAI.app`.

The source-controlled defaults are in `Config/build-version.env`. Override them for a local build when needed:

```bash
BISCUIT_VERSION=1.1.0 BISCUIT_BUILD_NUMBER=2 ./Scripts/build_app.sh
```

Run the automated checks before packaging:

```bash
swift test
swift build -c release
```

## Project map

| Path | Purpose |
| --- | --- |
| `Sources/BiscuitAI/BiscuitAIApp.swift` | Adaptive SwiftUI interface, light/dark themes, chat layout, and Settings controls. |
| `Sources/BiscuitAI/SettingsStore.swift` | Secure key profiles, appearance, prompt, temperature, and live model refresh state. |
| `Sources/BiscuitAI/ChatStore.swift` | Local conversations, streaming lifecycle, buffering, cancellation, retry, and reply states. |
| `Sources/BiscuitAI/OpenRouterClient.swift` | Injectable OpenRouter model-catalog and streaming client. |
| `Sources/BiscuitAI/ConversationStore.swift` | Atomic Application Support conversation persistence and migration support. |
| `Sources/BiscuitAI/RequestContextBuilder.swift` | Model-aware bounded request context construction. |
| `Sources/BiscuitAI/Models.swift` | Profile, theme, model catalog, and API response definitions. |
| `Sources/BiscuitAI/BiscuitMascot.swift` | Animated presentation of the user-supplied mascot. |
| `Sources/BiscuitAI/BiscuitResources.swift` | Resolves Swift Package resources in development and packaged app bundles. |
| `Tests/BiscuitAITests/BiscuitAITests.swift` | Persistence, context, and OpenRouter decoding tests. |
| `Resources/BiscuitMascot.png` | Source copy of the user-supplied mascot image. |
| `Sources/BiscuitAI/Resources/BiscuitMascot.png` | Mascot copy bundled with the Swift package. |
| `Sources/BiscuitAI/Resources/BiscuitNewChatCircle.png` | New-chat hero artwork. |
| `Sources/BiscuitAI/Resources/BiscuitChatBubble.png` | Active assistant/chat artwork. |
| `Design Assets/AppIcon.png` | Source artwork used to generate the packaged macOS app icon. |
| `Scripts/build_app.sh` | Repeatable macOS build and packaging script. |

## OpenRouter connection

BiscuitAI uses OpenRouter’s `POST /api/v1/chat/completions` endpoint with `stream: true` for token-by-token replies. The app reads model metadata from `GET /api/v1/models` when you refresh the catalog. [2] [3]

Conversation history is stored atomically as JSON under the user’s Application Support directory. Existing history from the legacy `biscuitai-conversations-v1` `UserDefaults` key is migrated when the new store is first created. API keys remain in macOS Keychain.

Do not put an API key in source code, screenshots, or version control. Enter it locally in Settings instead.

## References

[1]: https://openrouter.ai/models "OpenRouter model catalog"
[2]: https://openrouter.ai/docs/api_reference/authentication "OpenRouter authentication"
[3]: https://openrouter.ai/docs/api_reference/streaming "OpenRouter streaming"
