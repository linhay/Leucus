import AppKit
import GhosttyKit

@MainActor
final class ViewController: NSViewController {
    private lazy var runtime = GhosttyRuntime()
    private lazy var terminalView = GhosttySurfaceView(
        runtime: runtime,
        workingDirectory: FileManager.default.homeDirectoryForCurrentUser,
        initialInput: nil,
        fontSize: 14,
        context: GHOSTTY_SURFACE_CONTEXT_WINDOW
    )
    private lazy var terminalContainer = GhosttySurfaceScrollView(surfaceView: terminalView)

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureTerminalView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        activateTerminal()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        terminalView.updateSurfaceSize()
    }

    private func configureView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    private func configureTerminalView() {
        terminalContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(terminalContainer)

        NSLayoutConstraint.activate([
            terminalContainer.topAnchor.constraint(equalTo: view.topAnchor),
            terminalContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            terminalContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            terminalContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        terminalView.bridge.onTitleChange = { [weak self] title in
            self?.view.window?.title = title.isEmpty ? "CanvasTerminal Example" : title
        }
    }

    private func activateTerminal() {
        view.window?.makeFirstResponder(terminalView)
        terminalView.updateSurfaceSize()
    }
}
