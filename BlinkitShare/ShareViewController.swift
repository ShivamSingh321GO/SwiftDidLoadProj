import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        processAttachments()
    }

    // MARK: - Extract shared URL from attachments

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

    // MARK: - Save URL to App Group and launch main app

    private func saveAndFinish(url: String) {
        // 1. Save the URL to App Group so the main app can read it
        let appGroupName = "group.galgotiasUni.SwiftDidLoadProj.share"
        if let sharedDefaults = UserDefaults(suiteName: appGroupName) {
            sharedDefaults.set(url, forKey: "sharedRecipeURL")
            sharedDefaults.synchronize()
        }

        // 2. Open the main app via custom URL scheme
        let deepLink = URL(string: "blinkit://recipe")!

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.openURLViaResponderChain(deepLink)

            // Complete extension after a short delay so the open request fires
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
        }
    }

    // MARK: - Open Containing App via Responder Chain
    // Walking the responder chain searches for the UI host application
    // without invoking [UIApplication sharedApplication] (which triggers runtime assertion/SIGTERM in extensions).

    @discardableResult
    private func openURLViaResponderChain(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let r = responder {
            if r.responds(to: selector) {
                r.perform(selector, with: url as NSURL)
                return true
            }
            responder = r.next
        }
        return false
    }
}
