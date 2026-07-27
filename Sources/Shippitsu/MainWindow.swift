import AppKit

@MainActor
enum MainWindow {
  static func make(title: String) -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = title
    window.isReleasedWhenClosed = false  // ARC 下で二重解放を避けるため必須
    window.center()
    return window
  }
}
