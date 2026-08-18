import Foundation

enum BiscuitResources {
    static let bundle: Bundle = {
        let mainResourcesBundle = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("BiscuitAI_BiscuitAI.bundle", isDirectory: true)

        if let bundle = Bundle(url: mainResourcesBundle) {
            return bundle
        }

        return .module
    }()
}
