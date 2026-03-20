import AppKit
import CanvasTerminalKit
import InfiniteCanvasKit

@MainActor
final class ViewController: NSViewController {
    private lazy var canvasView = InfiniteCanvasView()
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
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        let restored = canvasView.configurePersistence(
            key: "canvas-terminal-example-main",
            restoreOnConfigure: true
        )
        if !restored {
            canvasView.nodes = [
                CanvasNodeCard(title: "Node A", position: CGPoint(x: -220, y: -120)),
                CanvasNodeCard(title: "Node B", position: CGPoint(x: 140, y: -30)),
                CanvasNodeCard(title: "Node C", position: CGPoint(x: -10, y: 180)),
            ]
        }
        view.addSubview(canvasView)

        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: view.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func activateCanvas() {
        view.window?.title = "Infinite Canvas Example"
        view.window?.makeFirstResponder(canvasView)
    }

    private func observeApplicationTermination() {
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.canvasView.persistNow()
        }
    }

    deinit {
        if let terminateObserver {
            NotificationCenter.default.removeObserver(terminateObserver)
        }
    }
}
