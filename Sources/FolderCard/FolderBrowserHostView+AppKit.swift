#if canImport(AppKit) && !canImport(UIKit)
import AppKit
import InfiniteCanvasKit

@MainActor
public final class FolderBrowserHostView: NSView {
  public var onInteraction: (() -> Void)?
  public var onDirectoryChanged: ((String, String) -> Void)?
  public var onScrollWheelPassthrough: ((NSEvent) -> Void)?
  public var onMagnifyPassthrough: ((NSEvent) -> Void)?

  private let toolbar = NSView()
  private let upButton = NSButton(title: "上级", target: nil, action: nil)
  private let pathLabel = NSTextField(labelWithString: "")
  private let scrollView = NSScrollView()
  private let tableView = NSTableView()

  private var entries: [FolderBrowserEntry] = []
  public private(set) var currentPath: String

  public override init(frame frameRect: NSRect) {
    currentPath = FolderBrowserModel.resolvedDirectoryPath(preferred: nil)
    super.init(frame: frameRect)
    setup()
    setDirectoryPath(nil, notifyChange: false)
  }

  public convenience init(directoryPath: String?) {
    self.init(frame: .zero)
    setDirectoryPath(directoryPath, notifyChange: false)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  public override func layout() {
    super.layout()
    let toolbarHeight: CGFloat = 30
    toolbar.frame = CGRect(x: 0, y: bounds.height - toolbarHeight, width: bounds.width, height: toolbarHeight)
    upButton.frame = CGRect(x: 6, y: 4, width: 52, height: toolbarHeight - 8)
    pathLabel.frame = CGRect(x: upButton.frame.maxX + 6, y: 4, width: max(0, bounds.width - upButton.frame.maxX - 12), height: toolbarHeight - 8)
    scrollView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - toolbarHeight))
    tableView.frame = CGRect(origin: .zero, size: scrollView.contentSize)
    if let column = tableView.tableColumns.first {
      column.width = scrollView.contentSize.width
    }
  }

  public override func mouseDown(with event: NSEvent) {
    onInteraction?()
    super.mouseDown(with: event)
  }

  public override func rightMouseDown(with event: NSEvent) {
    onInteraction?()
    super.rightMouseDown(with: event)
  }

  public override func scrollWheel(with event: NSEvent) {
    if event.modifierFlags.contains(.command), let onScrollWheelPassthrough {
      onScrollWheelPassthrough(event)
      return
    }
    super.scrollWheel(with: event)
  }

  public override func magnify(with event: NSEvent) {
    if let onMagnifyPassthrough {
      onMagnifyPassthrough(event)
      return
    }
    super.magnify(with: event)
  }

  public func setDirectoryPath(_ path: String?, notifyChange: Bool) {
    let resolved = FolderBrowserModel.resolvedDirectoryPath(preferred: path)
    guard resolved != currentPath || entries.isEmpty else { return }

    currentPath = resolved
    pathLabel.stringValue = resolved
    upButton.isEnabled = FolderBrowserModel.parentPath(of: resolved) != nil
    entries = FolderBrowserModel.entries(at: resolved)
    tableView.reloadData()

    if notifyChange {
      onDirectoryChanged?(resolved, FolderBrowserModel.directoryTitle(for: resolved))
    }
  }

  private func setup() {
    wantsLayer = true
    layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 0.94).cgColor
    layer?.cornerRadius = 8
    layer?.masksToBounds = true

    toolbar.wantsLayer = true
    toolbar.layer?.backgroundColor = NSColor(calibratedWhite: 0.17, alpha: 0.98).cgColor
    addSubview(toolbar)

    upButton.target = self
    upButton.action = #selector(goUp)
    upButton.bezelStyle = .texturedRounded
    upButton.controlSize = .small
    upButton.contentTintColor = NSColor(calibratedWhite: 0.92, alpha: 1)
    toolbar.addSubview(upButton)

    pathLabel.lineBreakMode = .byTruncatingMiddle
    pathLabel.font = .systemFont(ofSize: 11, weight: .medium)
    pathLabel.textColor = NSColor(calibratedWhite: 0.82, alpha: 1)
    toolbar.addSubview(pathLabel)

    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.resizingMask = .autoresizingMask
    tableView.addTableColumn(column)
    tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
    tableView.headerView = nil
    tableView.rowHeight = 24
    tableView.intercellSpacing = NSSize(width: 0, height: 2)
    tableView.usesAlternatingRowBackgroundColors = false
    tableView.backgroundColor = .clear
    tableView.style = .sourceList
    tableView.selectionHighlightStyle = .regular
    tableView.delegate = self
    tableView.dataSource = self
    tableView.target = self
    tableView.action = #selector(handleTableAction)
    tableView.doubleAction = #selector(openSelection)

    scrollView.borderType = .noBorder
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.documentView = tableView
    addSubview(scrollView)
  }

  @objc
  private func goUp() {
    guard let parent = FolderBrowserModel.parentPath(of: currentPath) else { return }
    onInteraction?()
    setDirectoryPath(parent, notifyChange: true)
  }

  @objc
  private func handleTableAction() {
    onInteraction?()
  }

  @objc
  private func openSelection() {
    onInteraction?()
    let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
    guard row >= 0, row < entries.count else { return }
    let entry = entries[row]
    switch entry.kind {
    case .folder:
      setDirectoryPath(entry.path, notifyChange: true)
    case .file, .other:
      NSWorkspace.shared.open(URL(fileURLWithPath: entry.path))
    }
  }
}

extension FolderBrowserHostView: NSTableViewDataSource, NSTableViewDelegate {
  public func numberOfRows(in _: NSTableView) -> Int {
    entries.count
  }

  public func tableView(
    _: NSTableView,
    viewFor _: NSTableColumn?,
    row: Int
  ) -> NSView? {
    let identifier = NSUserInterfaceItemIdentifier("folder-browser-cell")
    let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? {
      let cell = NSTableCellView()
      cell.identifier = identifier
      let iconView = NSImageView()
      iconView.translatesAutoresizingMaskIntoConstraints = false
      iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
      iconView.contentTintColor = NSColor(calibratedWhite: 0.82, alpha: 1)
      let textField = NSTextField(labelWithString: "")
      textField.translatesAutoresizingMaskIntoConstraints = false
      textField.lineBreakMode = .byTruncatingMiddle
      textField.font = .systemFont(ofSize: 12)
      textField.textColor = NSColor(calibratedWhite: 0.88, alpha: 1)
      cell.addSubview(iconView)
      cell.addSubview(textField)
      NSLayoutConstraint.activate([
        iconView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
        iconView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        iconView.widthAnchor.constraint(equalToConstant: 14),
        iconView.heightAnchor.constraint(equalToConstant: 14),
        textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
        textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
        textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
      ])
      cell.imageView = iconView
      cell.textField = textField
      return cell
    }()

    let entry = entries[row]
    let symbolName: String
    switch entry.kind {
    case .folder:
      symbolName = "folder.fill"
    case .file:
      symbolName = "doc.text.fill"
    case .other:
      symbolName = "questionmark.square.dashed"
    }
    cell.imageView?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    cell.textField?.stringValue = entry.name
    return cell
  }

  public func tableViewSelectionDidChange(_: Notification) {
    onInteraction?()
  }
}
#endif
