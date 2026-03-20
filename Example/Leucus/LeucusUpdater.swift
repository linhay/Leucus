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

        self.feedURL = feedURL
        isConfigured = true

        if !LeucusUpdateConfiguration.hasPublicKey(in: infoDictionary) {
            NSLog("Leucus auto-update warning: SUPublicEDKey is empty, update verification may fail.")
        }

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
