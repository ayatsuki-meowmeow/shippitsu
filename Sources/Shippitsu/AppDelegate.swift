import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var mainWindow: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let appName: String = Self.resolveDisplayName()
    NSApp.mainMenu = MainMenu.make(appName: appName)

    let window: NSWindow = MainWindow.make(title: appName)
    window.makeKeyAndOrderFront(nil)
    mainWindow = window

    NSApp.activate()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  /// 表示名を Info.plist から解決する。単一情報源は project.yml の info.properties(2-1)。
  /// CFBundleDisplayName → CFBundleName → リテラルの順にフォールバックする。
  private static func resolveDisplayName() -> String {
    let bundle: Bundle = .main
    if let name = nonEmptyInfoString(bundle, forKey: "CFBundleDisplayName") {
      return name
    }
    if let name = nonEmptyInfoString(bundle, forKey: "CFBundleName") {
      return name
    }
    return "執筆"  // 最終フォールバック(D-3 の表示名)
  }

  /// Info.plist のキーから空文字ではない文字列値を取り出す。
  private static func nonEmptyInfoString(_ bundle: Bundle, forKey key: String) -> String? {
    guard let name = bundle.object(forInfoDictionaryKey: key) as? String, !name.isEmpty else {
      return nil
    }
    return name
  }
}
