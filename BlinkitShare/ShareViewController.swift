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
            self?.openContainingApp(deepLink)

            // Complete extension after a delay so the open request fires first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    // MARK: - Open Containing App
    //
    // Share Extensions CANNOT use extensionContext?.open() — that API only works
    // for Today/Widget extensions. The proven workaround used by production apps
    // is to access UIApplication.shared through the Objective-C runtime, bypassing
    // the compile-time restriction.
    //
    // Three strategies tried in order:
    //   1. UIApplication via ObjC runtime (most reliable)
    //   2. Responder chain walk
    //   3. extensionContext?.open (rarely works for Share Extensions but try anyway)

    private func openContainingApp(_ url: URL) {
        // Strategy 1: Access UIApplication.shared via ObjC runtime
        // UIApplication.shared is blocked at compile-time in extensions, but exists at runtime
        if openURLViaRuntime(url) {
            return
        }

        // Strategy 2: Walk the responder chain to find any object that handles openURL:
        if openURLViaResponderChain(url) {
            return
        }

        // Strategy 3: Last resort — extensionContext.open (officially only for Today widgets)
        extensionContext?.open(url, completionHandler: nil)
    }

    /// Access UIApplication.shared through NSClassFromString + performSelector
    @discardableResult
    private func openURLViaRuntime(_ url: URL) -> Bool {
        // Get the UIApplication class at runtime
        guard let appClass = NSClassFromString("UIApplication") as? NSObjectProtocol else {
            return false
        }

        // Call UIApplication.shared (the class method "sharedApplication")
        let sharedSelector = NSSelectorFromString("sharedApplication")
        guard appClass.responds(to: sharedSelector),
              let shared = appClass.perform(sharedSelector)?.takeUnretainedValue() else {
            return false
        }

        // Call open(_:options:completionHandler:) — the modern, non-deprecated API
        let openSelector = NSSelectorFromString("openURL:")
        guard shared.responds(to: openSelector) else {
            return false
        }
        shared.perform(openSelector, with: url as NSURL)
        return true
    }

    /// Walk the responder chain looking for UIApplication
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
