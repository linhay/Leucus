import Foundation
import CanvasKit
import Sparkle

@MainActor
final class LeucusUpdater: NSObject {
    private var controller: SPUStandardUpdaterController?
    private var feedURL: URL?
    private(set) var isConfigured = false

    func startIfConfigured(infoDictionary: [String: Any]) {
        guard controller == nil else { return }
        guard let feedURL = LeucusUpdateConfiguration.resolvedFeedURL(from: infoDictionary) else {
            isConfigured = false
            return
        }
        guard let _ = LeucusUpdateConfiguration.validatedPublicKey(in: infoDictionary) else {
            isConfigured = false
            NSLog("Leucus auto-update warning: SUPublicEDKey is missing or invalid; updater disabled.")
            return
        }

        self.feedURL = feedURL
        isConfigured = true

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        controller.updater.automaticallyChecksForUpdates = true
        self.controller = controller
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}

extension LeucusUpdater: SPUUpdaterDelegate {
    nonisolated func feedURLString(for _: SPUUpdater) -> String? {
        MainActor.assumeIsolated { feedURL?.absoluteString }
    }
}
