import AppKit
import CanvasKit

@MainActor
final class ViewController: NSViewController {
    private var workspaceView: CanvasWorkspaceView?
    private var terminateObserver: NSObjectProtocol?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureCanvasView()
        observeApplicationTermination()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        activateCanvas()
    }

    private func configureView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedWhite: 0.09, alpha: 1).cgColor
    }

    private func configureCanvasView() {
        guard #available(macOS 14.0, *) else { return }
        let workspaceView = CanvasWorkspaceView()
        self.workspaceView = workspaceView
        let canvasView = workspaceView.canvasView
        workspaceView.translatesAutoresizingMaskIntoConstraints = false
        let restored = canvasView.configurePersistence(
            key: "canvas-terminal-example-main",
            restoreOnConfigure: true
        )
        if !restored {
            canvasView.nodes = [
                CanvasNodeCard.terminal(
                    at: CGPoint(x: -220, y: -120),
                    workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
                    title: "Main"
                ),
                CanvasNodeCard(title: "Node B", position: CGPoint(x: 140, y: -30)),
                CanvasNodeCard.terminal(
                    at: CGPoint(x: -10, y: 180),
                    workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
                    title: "Shell"
                ),
            ]
        }
        view.addSubview(workspaceView)

        NSLayoutConstraint.activate([
            workspaceView.topAnchor.constraint(equalTo: view.topAnchor),
            workspaceView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            workspaceView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            workspaceView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func activateCanvas() {
        view.window?.title = "Infinite Canvas Example"
        guard #available(macOS 14.0, *), let workspaceView else { return }
        view.window?.makeFirstResponder(workspaceView.canvasView)
    }

    private func observeApplicationTermination() {
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard #available(macOS 14.0, *), let workspaceView = self?.workspaceView else { return }
            workspaceView.canvasView.persistNow()
        }
    }

    deinit {
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
        }
    }
}
