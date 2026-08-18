import AppKit
import Foundation
import SwiftUI

enum BiscuitResources {
    private static let resourceBundleURL: URL = {
        let packagedURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("BiscuitAI_BiscuitAI.bundle", isDirectory: true)

        if FileManager.default.fileExists(atPath: packagedURL.path) {
            return packagedURL
        }

        return Bundle.module.bundleURL
    }()

    static let bundle: Bundle = Bundle(url: resourceBundleURL) ?? .module

    static func image(named name: String) -> Image {
        let imageURL = resourceBundleURL.appendingPathComponent("\(name).png")
        if let image = NSImage(contentsOf: imageURL) {
            return Image(nsImage: image)
        }
        return Image(name, bundle: .module)
    }

    static var appIcon: Image {
        if let image = NSImage(named: NSImage.applicationIconName) {
            return Image(nsImage: image)
        }
        return image(named: "AppIcon")
    }
}
