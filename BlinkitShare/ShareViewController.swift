import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        // Immediately process — no UI shown, redirect happens fast
        processAttachments()
    }

    private func processAttachments() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            openMainApp(url: "no-url")
            return
        }

        var found = false

        for attachment in extensionItem.attachments ?? [] {
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                found = true
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                    let urlString = (item as? URL)?.absoluteString ?? "no-url"
                    self?.openMainApp(url: urlString)
                }
                break
            } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                found = true
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                    let urlString = (item as? String) ?? "no-url"
                    self?.openMainApp(url: urlString)
                }
                break
            }
        }

        if !found {
            openMainApp(url: "no-url")
        }
    }

    private func openMainApp(url: String) {
        // Save URL so main app can read it
        let appGroupName = "group.galgotiasUni.SwiftDidLoadProj.share"
        if let sharedDefaults = UserDefaults(suiteName: appGroupName) {
            sharedDefaults.set(url, forKey: "sharedRecipeURL")
            sharedDefaults.synchronize()
        }

        // The ONLY reliable way to open the main app from an extension on modern iOS:
        // Complete the extension request and let the system open our custom URL scheme.
        guard let deepLinkURL = URL(string: "blinkit://recipe") else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        // Use extensionContext openURL (iOS 17+ compatible)
        extensionContext?.completeRequest(returningItems: []) { [weak self] _ in
            // After extension finishes, open the main app via openURL
            _ = self // keep self alive
        }

        // Walk the responder chain to find UIApplication and call open
        DispatchQueue.main.async {
            var responder: UIResponder? = self
            while let r = responder {
                if let app = r as? UIApplication {
                    app.open(deepLinkURL)
                    break
                }
                responder = r.next
            }
        }
    }
}
