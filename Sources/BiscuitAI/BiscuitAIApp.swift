import SwiftUI

@main
struct BiscuitAIApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var chat = ChatStore()

    var body: some Scene {
        WindowGroup {
            BiscuitAIContentView()
                .environmentObject(settings)
                .environmentObject(chat)
                .preferredColorScheme(settings.appearance == .dark ? .dark : .light)
                .frame(minWidth: 980, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Biscuit Chat") { chat.startNewChat() }
                    .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}

struct BiscuitAIContentView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var chat: ChatStore
    @State private var showingSettings = false
    @State private var draft = ""

    private var theme: BiscuitTheme { BiscuitTheme.make(settings.appearance) }

    var body: some View {
        NavigationSplitView {
            BiscuitSidebar(showingSettings: $showingSettings, theme: theme)
                .navigationSplitViewColumnWidth(min: 244, ideal: 278, max: 320)
        } detail: {
            ZStack {
                BiscuitBackground(theme: theme)
                VStack(spacing: 0) {
                    ChatHeader(showingSettings: $showingSettings, theme: theme)
                    Rectangle().fill(theme.separator).frame(height: 1)
                    if chat.currentMessages.isEmpty {
                        WelcomePane(theme: theme) { prompt in draft = prompt }
                    } else {
                        ConversationView(theme: theme)
                    }
                    ChatComposer(
                        draft: $draft,
                        isSending: chat.isReplying,
                        theme: theme,
                        onSend: sendDraft,
                        onCancel: chat.cancelReply
                    )
                }
            }
            .toolbar(.hidden, for: .windowToolbar)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingSettings) {
            SettingsView(theme: theme)
                .environmentObject(settings)
                .frame(width: 680, height: 760)
        }
        .alert(item: $chat.notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("Got it")))
        }
    }

    private func sendDraft() {
        let outbound = draft
        draft = ""
        chat.send(outbound, settings: settings)
    }
}

private struct BiscuitSidebar: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var chat: ChatStore
    @Binding var showingSettings: Bool
    let theme: BiscuitTheme

    var body: some View {
        ZStack {
            theme.sidebar
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 11) {
                    BiscuitMascot(size: 44, mood: .welcoming)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BiscuitAI")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(theme.sidebarText)
                        Text("cool ideas, freshly baked")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(theme.sidebarText.opacity(0.62))
                    }
                }
                .padding(.top, 12)

                Button { chat.startNewChat() } label: {
                    Label("New chat", systemImage: "plus")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(theme.sidebarButtonText)
                        .background(theme.accent, in: Capsule())
                }
                .buttonStyle(BiscuitPressStyle())

                Text("RECENTLY BAKED")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(theme.sidebarText.opacity(0.45))
                    .padding(.top, 8)

                if chat.conversations.isEmpty {
                    Text("Fresh conversations will rise here.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.sidebarText.opacity(0.56))
                        .lineSpacing(3)
                        .padding(.horizontal, 4)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 5) {
                            ForEach(chat.conversations) { conversation in
                                Button {
                                    chat.select(conversation)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "bubble.left.and.bubble.right.fill")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(conversation.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        Spacer(minLength: 0)
                                    }
                                    .foregroundStyle(theme.sidebarText.opacity(chat.selectedConversationID == conversation.id ? 1 : 0.7))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(chat.selectedConversationID == conversation.id ? theme.sidebarSelection : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) { chat.delete(conversation) } label: {
                                        Label("Discard chat", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Image(systemName: settings.hasAPIKey ? "checkmark.seal.fill" : "key.fill")
                        .foregroundStyle(settings.hasAPIKey ? theme.success : theme.accent)
                    Text(settings.hasAPIKey ? "\(settings.activeProfileName) ready" : "Add an OpenRouter key")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(theme.sidebarText.opacity(0.82))
                    Spacer()
                }
                .padding(12)
                .background(theme.sidebarCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button { showingSettings = true } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.sidebarText.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 10)
                        .background(theme.sidebarCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
    }
}

private struct ChatHeader: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var chat: ChatStore
    @Binding var showingSettings: Bool
    let theme: BiscuitTheme

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(chat.currentConversationTitle ?? "Fresh from the oven")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                HStack(spacing: 6) {
                    Circle().fill(theme.success).frame(width: 7, height: 7)
                    Text("\(settings.activeProfileName) · \(settings.selectedModel)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                }
                .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            if chat.isReplying && chat.activeConversationID == chat.selectedConversationID {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small).tint(theme.accent)
                    Text("Biscuit is baking…")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.accentSoft, in: Capsule())
            }
            Button {
                showingSettings = true
            } label: {
                Image(systemName: settings.appearance == .dark ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(theme.controlFill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open settings")
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 18)
    }
}

private struct WelcomePane: View {
    @State private var headlineIndex = 0
    let theme: BiscuitTheme
    let onPrompt: (String) -> Void

    private let greetings = [
        "What’s baking today?",
        "Let’s get this dough rising!",
        "Ready to whisk up something brilliant?"
    ]

    private let suggestions = [
        ("Whisk up a plan", "Help me make a focused plan for my next big idea.", "wand.and.stars"),
        ("Crumb through some code", "Help me think through a coding problem step by step.", "chevron.left.forwardslash.chevron.right"),
        ("Bake a brilliant note", "Draft a thoughtful, clear message for me.", "pencil.and.scribble")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 26)
                ZStack {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(theme.heroGlow)
                        .frame(width: 270, height: 270)
                    Image("BiscuitNewChatCircle", bundle: BiscuitResources.bundle)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 242, height: 242)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(theme.accent)
                        .offset(x: 16, y: -10)
                }

                VStack(spacing: 8) {
                    Text("BISCUITAI")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(2.1)
                        .foregroundStyle(theme.accent)
                    Text(greetings[headlineIndex])
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .contentTransition(.opacity)
                        .id(headlineIndex)
                    Text("I’m Biscuit—your sharp sidekick for questions, sparks, and half-baked ideas worth finishing.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 540)
                        .lineSpacing(3)
                }

                HStack(spacing: 12) {
                    ForEach(suggestions, id: \.0) { title, prompt, icon in
                        Button { onPrompt(prompt) } label: {
                            VStack(alignment: .leading, spacing: 11) {
                                Image(systemName: icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(theme.accent)
                                Text(title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(theme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Text("Start here")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                            .padding(16)
                            .background(theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(theme.cardBorder, lineWidth: 1)
                            }
                        }
                        .buttonStyle(BiscuitPressStyle())
                    }
                }
                .frame(maxWidth: 690)
                .padding(.horizontal, 28)

                Text("Your conversations stay on this Mac. Add an OpenRouter key in Settings to start baking.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Spacer(minLength: 28)
            }
            .frame(maxWidth: .infinity)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    headlineIndex = (headlineIndex + 1) % greetings.count
                }
            }
        }
    }
}

private struct ConversationView: View {
    @EnvironmentObject private var chat: ChatStore
    @EnvironmentObject private var settings: SettingsStore
    let theme: BiscuitTheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(chat.currentMessages) { message in
                        let isLatest = message.id == chat.currentMessages.last?.id
                        ChatBubble(
                            message: message,
                            isReplying: chat.isReplying && chat.activeConversationID == chat.selectedConversationID,
                            responseState: isLatest ? chat.responseState(for: chat.selectedConversationID) : .idle,
                            theme: theme,
                            onRetry: { chat.retry(settings: settings) }
                        )
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 26)
            }
            .onChange(of: chat.currentMessages.count) { _, _ in
                if let last = chat.currentMessages.last {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    let isReplying: Bool
    let responseState: ReplyState
    let theme: BiscuitTheme
    let onRetry: () -> Void
    @State private var copied = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.role == .assistant {
                BiscuitMascot(
                    size: 38,
                    mood: isReplying && message.content.isEmpty ? .thinking : .welcoming,
                    assetName: "BiscuitChatBubble"
                )
            } else {
                Spacer(minLength: 62)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                if message.role == .assistant && message.content.isEmpty && isReplying {
                    TypingBubble(theme: theme)
                } else if message.role == .assistant && message.content.isEmpty {
                    Text(responseLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 13)
                        .background(theme.assistantBubble, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    Text(message.content)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(message.role == .user ? .white : theme.textPrimary)
                        .textSelection(.enabled)
                        .lineSpacing(4)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 13)
                        .background(message.role == .user ? AnyShapeStyle(theme.userBubble) : AnyShapeStyle(theme.assistantBubble), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                if message.role == .assistant, case .failed(let error) = responseState {
                    HStack(spacing: 9) {
                        Text(error)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.warning)
                            .lineLimit(2)
                        Button("Retry", action: onRetry)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .buttonStyle(.borderedProminent)
                            .tint(theme.accent)
                    }
                    .padding(.leading, 4)
                } else if message.role == .assistant, responseState == .cancelled {
                    HStack(spacing: 7) {
                        Text("Response stopped before it finished.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        Button("Retry", action: onRetry)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .buttonStyle(.bordered)
                    }
                    .padding(.leading, 4)
                }
                if message.role == .assistant && !message.content.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { copied = false }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
            }
            .frame(maxWidth: 680, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer(minLength: 62)
            } else {
                Circle()
                    .fill(theme.userBubble)
                    .frame(width: 38, height: 38)
                    .overlay { Image(systemName: "person.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white) }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var responseLabel: String {
        switch responseState {
        case .failed:
            return "Biscuit couldn’t finish this reply."
        case .cancelled:
            return "Response stopped."
        case .idle, .streaming:
            return message.content
        }
    }
}

private struct TypingBubble: View {
    let theme: BiscuitTheme
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(theme.accent)
                    .frame(width: 7, height: 7)
                    .offset(y: bounce ? -4 : 2)
                    .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true).delay(Double(index) * 0.12), value: bounce)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(theme.assistantBubble, in: Capsule())
        .onAppear { bounce = true }
    }
}

private struct ChatComposer: View {
    @Binding var draft: String
    let isSending: Bool
    let theme: BiscuitTheme
    let onSend: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text("Ask Biscuit anything…")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $draft)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .frame(minHeight: 50, maxHeight: 112)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
            }
            .background(theme.controlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isFocused ? theme.accent : theme.cardBorder, lineWidth: isFocused ? 2 : 1)
            }

            Button(action: isSending ? onCancel : onSend) {
                Image(systemName: isSending ? "stop.fill" : "arrow.up")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(isSending ? theme.accent : (draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.disabled : theme.accent), in: Circle())
            }
            .buttonStyle(BiscuitPressStyle())
            .disabled(!isSending && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(isSending ? "Stop response" : "Send message")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(theme.composerBackground)
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    let theme: BiscuitTheme
    @State private var keyDraft = ""
    @State private var profileNameDraft = ""
    @State private var newProfileName = ""
    @State private var newProfileKey = ""
    @State private var newProfileModel = ""
    @State private var modelSearch = ""
    @State private var showFreeOnly = false
    @State private var saveError: String?

    private var filteredModels: [ModelOption] {
        let query = modelSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return settings.availableModels.filter { model in
            let searchMatches = query.isEmpty || model.name.lowercased().contains(query) || model.id.lowercased().contains(query)
            return searchMatches && (!showFreeOnly || model.isFree)
        }
    }

    var body: some View {
        ZStack {
            BiscuitBackground(theme: theme)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        HStack(spacing: 12) {
                            BiscuitMascot(size: 58, mood: .thinking)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Biscuit’s pantry")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundStyle(theme.textPrimary)
                                Text("Control your look, keys, models, and creative heat.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        Spacer()
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .tint(theme.accent)
                    }

                    SettingsCard(theme: theme) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Appearance", systemImage: "circle.lefthalf.filled")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Picker("Appearance", selection: $settings.appearance) {
                                ForEach(AppAppearance.allCases) { appearance in
                                    Label(appearance.title, systemImage: appearance.symbolName).tag(appearance)
                                }
                            }
                            .pickerStyle(.segmented)
                            Text("Warm light uses a softer parchment background; dark shifts the whole workspace to low-glare charcoal and cocoa tones.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }

                    SettingsCard(theme: theme) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("OpenRouter key profiles", systemImage: "key.fill")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Picker("Using key", selection: $settings.activeProfileID) {
                                ForEach(settings.profiles) { profile in
                                    Text(profile.label).tag(Optional(profile.id))
                                }
                            }
                            .pickerStyle(.menu)

                            HStack {
                                TextField("Profile name", text: $profileNameDraft)
                                    .textFieldStyle(.roundedBorder)
                                Button("Rename") { settings.renameActiveProfile(profileNameDraft) }
                                    .buttonStyle(.bordered)
                            }

                            HStack {
                                SecureField("General OpenRouter API key", text: $keyDraft)
                                    .textFieldStyle(.roundedBorder)
                                Button("Save key") {
                                    do {
                                        try settings.saveGeneralKey(keyDraft)
                                        saveError = nil
                                    } catch { saveError = error.localizedDescription }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(theme.accent)
                            }
                            Text("A general OpenRouter key can call every model that its credits and permissions allow. BiscuitAI keeps each saved key in your Mac’s Keychain and uses the selected profile for the next reply.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.textSecondary)

                            DisclosureGroup("Add another key and model profile") {
                                VStack(alignment: .leading, spacing: 9) {
                                    TextField("Profile name, e.g. Work credits", text: $newProfileName)
                                        .textFieldStyle(.roundedBorder)
                                    SecureField("OpenRouter API key", text: $newProfileKey)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("Initial model ID (optional)", text: $newProfileModel)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Add profile") {
                                        do {
                                            try settings.addProfile(label: newProfileName, key: newProfileKey, model: newProfileModel)
                                            newProfileName = ""
                                            newProfileKey = ""
                                            newProfileModel = ""
                                            keyDraft = settings.apiKey
                                            profileNameDraft = settings.activeProfileName
                                            saveError = nil
                                        } catch { saveError = error.localizedDescription }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.top, 8)
                            }
                            if settings.profiles.count > 1 {
                                Button(role: .destructive) {
                                    do {
                                        try settings.removeActiveProfile()
                                        keyDraft = settings.apiKey
                                        profileNameDraft = settings.activeProfileName
                                    } catch { saveError = error.localizedDescription }
                                } label: {
                                    Label("Remove selected profile", systemImage: "trash")
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .bold))
                            }
                            if let saveError {
                                Text(saveError).font(.caption).foregroundStyle(.red)
                            }
                        }
                    }

                    SettingsCard(theme: theme) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("AI model and credits", systemImage: "sparkles")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Spacer()
                                Button {
                                    Task { await settings.loadModels() }
                                } label: {
                                    if settings.isLoadingModels { ProgressView().controlSize(.small) }
                                    else { Label("Refresh catalog", systemImage: "arrow.clockwise") }
                                }
                                .disabled(!settings.hasAPIKey || settings.isLoadingModels)
                            }
                            Text("The selected model uses the credits attached to the active OpenRouter key: \(settings.activeProfileName). Refresh to load the live catalog, then search or paste any supported model ID.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.textSecondary)

                            TextField("Search current models", text: $modelSearch)
                                .textFieldStyle(.roundedBorder)
                            Toggle("Only show models marked free", isOn: $showFreeOnly)
                                .font(.system(size: 12, weight: .semibold))
                            TextField("Selected model ID", text: $settings.selectedModel)
                                .textFieldStyle(.roundedBorder)

                            ScrollView {
                                LazyVStack(spacing: 6) {
                                    ForEach(Array(filteredModels.prefix(14))) { model in
                                        Button {
                                            settings.selectedModel = model.id
                                        } label: {
                                            HStack(alignment: .top, spacing: 10) {
                                                Image(systemName: settings.selectedModel == model.id ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(settings.selectedModel == model.id ? theme.accent : theme.textSecondary)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    HStack(spacing: 6) {
                                                        Text(model.name).font(.system(size: 12, weight: .bold))
                                                        if model.isFree {
                                                            Text("FREE").font(.system(size: 9, weight: .heavy, design: .rounded)).foregroundStyle(theme.success)
                                                        }
                                                    }
                                                    Text(model.id).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(theme.textSecondary)
                                                    if let description = model.description {
                                                        Text(description).font(.system(size: 10)).foregroundStyle(theme.textSecondary).lineLimit(2)
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .foregroundStyle(theme.textPrimary)
                                            .padding(10)
                                            .background(settings.selectedModel == model.id ? theme.accentSoft : theme.controlFill.opacity(0.54), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(height: 210)
                            if let error = settings.modelLoadError {
                                Text(error).font(.caption).foregroundStyle(theme.warning)
                            }
                        }
                    }

                    SettingsCard(theme: theme) {
                        VStack(alignment: .leading, spacing: 11) {
                            Label("Biscuit’s instructions", systemImage: "text.quote")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            TextEditor(text: $settings.systemPrompt)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.textPrimary)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(height: 94)
                                .background(theme.controlFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            HStack {
                                Text("Creativity").font(.system(size: 12, weight: .bold))
                                Slider(value: $settings.temperature, in: 0...1.2, step: 0.1).tint(theme.accent)
                                Text(settings.temperature.formatted(.number.precision(.fractionLength(1))))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                    }
                }
                .padding(28)
            }
        }
        .onAppear(perform: syncDrafts)
        .onChange(of: settings.activeProfileID) { _, _ in syncDrafts() }
    }

    private func syncDrafts() {
        keyDraft = settings.apiKey
        profileNameDraft = settings.activeProfileName
    }
}

private struct SettingsCard<Content: View>: View {
    let theme: BiscuitTheme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.cardBorder, lineWidth: 1) }
    }
}

private struct BiscuitBackground: View {
    let theme: BiscuitTheme

    var body: some View {
        ZStack {
            theme.background
            Circle().fill(theme.ambientGold).frame(width: 440, height: 440).blur(radius: 58).offset(x: -380, y: -270)
            Circle().fill(theme.ambientBlue).frame(width: 460, height: 460).blur(radius: 64).offset(x: 400, y: -210)
            Circle().fill(theme.ambientRose).frame(width: 390, height: 390).blur(radius: 62).offset(x: 360, y: 360)
        }
        .ignoresSafeArea()
    }
}

private struct BiscuitPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct BiscuitTheme {
    let background: Color
    let sidebar: Color
    let sidebarText: Color
    let sidebarButtonText: Color
    let sidebarSelection: Color
    let sidebarCard: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color
    let accentSoft: Color
    let success: Color
    let warning: Color
    let card: Color
    let cardBorder: Color
    let controlFill: Color
    let assistantBubble: Color
    let userBubble: LinearGradient
    let composerBackground: Color
    let disabled: Color
    let separator: Color
    let heroGlow: LinearGradient
    let ambientGold: Color
    let ambientBlue: Color
    let ambientRose: Color

    static func make(_ appearance: AppAppearance) -> BiscuitTheme {
        switch appearance {
        case .warmLight:
            return BiscuitTheme(
                background: Color(hex: 0xEEE5DA),
                sidebar: Color(hex: 0x302C2A),
                sidebarText: Color(hex: 0xF5EEE5),
                sidebarButtonText: Color(hex: 0x102B36),
                sidebarSelection: Color.white.opacity(0.12),
                sidebarCard: Color.white.opacity(0.09),
                textPrimary: Color(hex: 0x372D29),
                textSecondary: Color(hex: 0x74645B),
                accent: Color(hex: 0x168EB4),
                accentSoft: Color(hex: 0xD6ECF0),
                success: Color(hex: 0x4B9B72),
                warning: Color(hex: 0xB46A35),
                card: Color(hex: 0xF8F2E9).opacity(0.93),
                cardBorder: Color(hex: 0xD6C8B9),
                controlFill: Color(hex: 0xFFFAF4).opacity(0.94),
                assistantBubble: Color(hex: 0xFAF4EB).opacity(0.97),
                userBubble: LinearGradient(colors: [Color(hex: 0x168EB4), Color(hex: 0x2576A4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                composerBackground: Color(hex: 0xE6DCD0).opacity(0.88),
                disabled: Color(hex: 0xB5AAA2),
                separator: Color(hex: 0xCFC1B2),
                heroGlow: LinearGradient(colors: [Color(hex: 0xD8EDF1), Color(hex: 0xF0DCC0)], startPoint: .topLeading, endPoint: .bottomTrailing),
                ambientGold: Color(hex: 0xD1A76B).opacity(0.16),
                ambientBlue: Color(hex: 0x70C4D3).opacity(0.13),
                ambientRose: Color(hex: 0xD1A19B).opacity(0.08)
            )
        case .dark:
            return BiscuitTheme(
                background: Color(hex: 0x171412),
                sidebar: Color(hex: 0x100F0E),
                sidebarText: Color(hex: 0xF4ECE2),
                sidebarButtonText: Color(hex: 0x102B36),
                sidebarSelection: Color.white.opacity(0.12),
                sidebarCard: Color.white.opacity(0.08),
                textPrimary: Color(hex: 0xF8F0E7),
                textSecondary: Color(hex: 0xB6A69B),
                accent: Color(hex: 0x4AD6EF),
                accentSoft: Color(hex: 0x153641),
                success: Color(hex: 0x78D9A0),
                warning: Color(hex: 0xE7A164),
                card: Color(hex: 0x26211E).opacity(0.97),
                cardBorder: Color(hex: 0x4B403A),
                controlFill: Color(hex: 0x322A26).opacity(0.96),
                assistantBubble: Color(hex: 0x2B2522).opacity(0.98),
                userBubble: LinearGradient(colors: [Color(hex: 0x188FAE), Color(hex: 0x2A5F8E)], startPoint: .topLeading, endPoint: .bottomTrailing),
                composerBackground: Color(hex: 0x211C19).opacity(0.94),
                disabled: Color(hex: 0x5D544E),
                separator: Color(hex: 0x493E37),
                heroGlow: LinearGradient(colors: [Color(hex: 0x163D4A), Color(hex: 0x523D2A)], startPoint: .topLeading, endPoint: .bottomTrailing),
                ambientGold: Color(hex: 0xA66E36).opacity(0.10),
                ambientBlue: Color(hex: 0x168EAE).opacity(0.13),
                ambientRose: Color(hex: 0x794D5D).opacity(0.08)
            )
        }
    }
}
