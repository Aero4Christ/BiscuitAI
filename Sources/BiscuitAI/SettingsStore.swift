import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var profiles: [APIKeyProfile]
    @Published var activeProfileID: UUID? {
        didSet {
            UserDefaults.standard.set(activeProfileID?.uuidString, forKey: Keys.activeProfileID)
            syncActiveProfile()
        }
    }
    @Published var selectedModel: String {
        didSet { updateSelectedModel() }
    }
    @Published var imageModel: String {
        didSet { UserDefaults.standard.set(imageModel, forKey: Keys.imageModel) }
    }
    @Published var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    @Published var systemPrompt: String {
        didSet { schedulePreferenceSave() }
    }
    @Published var temperature: Double {
        didSet { schedulePreferenceSave() }
    }
    @Published private(set) var apiKey: String = ""
    @Published private(set) var availableModels: [ModelOption]
    @Published private(set) var isLoadingModels = false
    @Published var modelLoadError: String?
    private let client: any OpenRouterServicing
    private var preferenceSaveTask: Task<Void, Never>?

    private enum Keys {
        static let profiles = "biscuit-openrouter-profiles-v2"
        static let activeProfileID = "biscuit-active-openrouter-profile-v2"
        static let appearance = "biscuit-appearance-v2"
        static let systemPrompt = "biscuit-system-prompt"
        static let temperature = "biscuit-temperature"
        static let imageModel = "biscuit-image-model"
        static let legacyAPIKeyAccount = "openrouter-api-key"
    }

    init(client: any OpenRouterServicing = OpenRouterClient()) {
        self.client = client
        let defaults = UserDefaults.standard
        let decodedProfiles = defaults.data(forKey: Keys.profiles).flatMap { try? JSONDecoder().decode([APIKeyProfile].self, from: $0) } ?? []
        let initialProfiles = decodedProfiles.isEmpty ? [Self.makeDefaultProfile()] : decodedProfiles
        self.profiles = initialProfiles
        let storedActiveID = defaults.string(forKey: Keys.activeProfileID).flatMap(UUID.init(uuidString:))
        self.activeProfileID = initialProfiles.contains(where: { $0.id == storedActiveID }) ? storedActiveID : initialProfiles.first?.id
        self.selectedModel = initialProfiles.first?.selectedModel ?? ModelOption.starterModels[0].id
        self.imageModel = defaults.string(forKey: Keys.imageModel) ?? "openai/gpt-5-image"
        self.appearance = AppAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .warmLight
        self.systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? "You are BiscuitAI: warm, capable, clear, and encouraging. Use a light baking pun only when it genuinely fits; never let a pun obscure the answer."
        self.temperature = (defaults.object(forKey: Keys.temperature) as? Double) ?? 0.7
        self.availableModels = ModelOption.starterModels

        migrateLegacyKeyIfNeeded()
        syncActiveProfile()
        persistProfiles()
    }

    var hasAPIKey: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var activeProfile: APIKeyProfile? {
        guard let activeProfileID else { return nil }
        return profiles.first(where: { $0.id == activeProfileID })
    }

    var activeProfileName: String {
        activeProfile?.label ?? "OpenRouter key"
    }

    func saveGeneralKey(_ value: String) throws {
        guard let profile = activeProfile else { return }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            try KeychainStore.delete(account: profile.keychainAccount)
        } else {
            try KeychainStore.save(cleaned, account: profile.keychainAccount)
        }
        apiKey = cleaned
    }

    func addProfile(label: String, key: String, model: String) throws {
        let cleanedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = UUID()
        let profile = APIKeyProfile(
            id: id,
            label: cleanedLabel.isEmpty ? "OpenRouter key \(profiles.count + 1)" : cleanedLabel,
            keychainAccount: "openrouter-profile-\(id.uuidString)",
            selectedModel: model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ModelOption.starterModels[0].id : model
        )
        if !cleanedKey.isEmpty {
            try KeychainStore.save(cleanedKey, account: profile.keychainAccount)
        }
        profiles.append(profile)
        persistProfiles()
        activeProfileID = profile.id
    }

    func removeActiveProfile() throws {
        guard let profile = activeProfile else { return }
        if profiles.count == 1 {
            try KeychainStore.delete(account: profile.keychainAccount)
            let replacement = Self.makeDefaultProfile()
            profiles = [replacement]
            activeProfileID = replacement.id
        } else {
            try KeychainStore.delete(account: profile.keychainAccount)
            profiles.removeAll { $0.id == profile.id }
            activeProfileID = profiles.first?.id
        }
        persistProfiles()
    }

    func renameActiveProfile(_ label: String) {
        guard let profileIndex = profiles.firstIndex(where: { $0.id == activeProfileID }) else { return }
        let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        profiles[profileIndex].label = cleaned
        persistProfiles()
    }

    func loadModels() async {
        guard hasAPIKey else {
            modelLoadError = "Add an OpenRouter API key first, then refresh the model catalog."
            return
        }

        isLoadingModels = true
        modelLoadError = nil
        defer { isLoadingModels = false }

        do {
            let models = try await client.fetchModels(apiKey: apiKey)
            guard !models.isEmpty else {
                modelLoadError = "OpenRouter returned no models for this key."
                return
            }
            availableModels = models
            if !models.contains(where: { $0.id == selectedModel }) {
                selectedModel = models[0].id
            }
        } catch {
            modelLoadError = error.localizedDescription
        }
    }

    private func syncActiveProfile() {
        guard let profile = activeProfile else {
            apiKey = ""
            return
        }
        apiKey = KeychainStore.read(account: profile.keychainAccount)
        if selectedModel != profile.selectedModel {
            selectedModel = profile.selectedModel
        }
    }

    private func updateSelectedModel() {
        guard let index = profiles.firstIndex(where: { $0.id == activeProfileID }) else { return }
        profiles[index].selectedModel = selectedModel
        persistProfiles()
    }

    private func persistProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: Keys.profiles)
        }
    }

    private func schedulePreferenceSave() {
        preferenceSaveTask?.cancel()
        preferenceSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            self?.persistPreferences()
        }
    }

    private func persistPreferences() {
        UserDefaults.standard.set(systemPrompt, forKey: Keys.systemPrompt)
        UserDefaults.standard.set(temperature, forKey: Keys.temperature)
    }

    private func migrateLegacyKeyIfNeeded() {
        guard let profile = activeProfile,
              KeychainStore.read(account: profile.keychainAccount).isEmpty else { return }
        let legacyKey = KeychainStore.read(account: Keys.legacyAPIKeyAccount)
        guard !legacyKey.isEmpty else { return }
        try? KeychainStore.save(legacyKey, account: profile.keychainAccount)
    }

    private static func makeDefaultProfile() -> APIKeyProfile {
        let id = UUID()
        return APIKeyProfile(
            id: id,
            label: "My OpenRouter key",
            keychainAccount: "openrouter-profile-\(id.uuidString)",
            selectedModel: ModelOption.starterModels[0].id
        )
    }
}
