import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        processAttachments()
    }

    private func processAttachments() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            saveAndFinish(url: "no-url")
            return
        }

        var found = false
        for attachment in extensionItem.attachments ?? [] {
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                found = true
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                    let urlString = (item as? URL)?.absoluteString ?? "no-url"
                    self?.saveAndFinish(url: urlString)
                }
                break
            } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                found = true
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                    let rawString = (item as? String) ?? ""
                    let urlString = self?.extractURL(from: rawString) ?? "no-url"
                    self?.saveAndFinish(url: urlString)
                }
                break
            }
        }
        if !found {
            saveAndFinish(url: "no-url")
        }
    }

    private func extractURL(from text: String) -> String {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        if let match = matches?.first, let range = Range(match.range, in: text) {
            return String(text[range])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveAndFinish(url: String) {
        // 1. Save the URL to App Group so the main app can read it
        let appGroupName = "group.galgotiasUni.SwiftDidLoadProj.share"
        if let sharedDefaults = UserDefaults(suiteName: appGroupName) {
            sharedDefaults.set(url, forKey: "sharedRecipeURL")
            sharedDefaults.synchronize()
        }

        // 2. Open the main app via custom URL scheme
        //    The ONLY working approach in a Share Extension is openURL on extensionContext
        let deepLink = URL(string: "blinkit://recipe")!

        DispatchQueue.main.async { [weak self] in
            // Use the private but widely-used selector to open a URL from an extension
            self?.openURL(deepLink)

            // Complete after a tiny delay to let the openURL fire
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    // This is the documented way to open a URL from an extension
    // It walks the responder chain to find an object that can handle openURL
    @objc func openURL(_ url: URL) {
        var responder: UIResponder? = self
        while let r = responder {
            if r.responds(to: #selector(openURL(_:))) && r !== self {
                r.perform(#selector(openURL(_:)), with: url)
                return
            }
            responder = r.next
        }
        // Fallback: use the extensionContext.open API (iOS 16+)
        extensionContext?.open(url)
    }
}
