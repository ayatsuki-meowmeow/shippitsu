import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var mainWindow: NSWindow?

  /// エントリポイント。`@main` は型が独自の `static func main()` を持つ場合そちらを呼び、
  /// AppKit 既定の `NSApplicationMain` ベースの実装(nib 経由でデリゲートを生成する)を使わない。
  /// 本プロジェクトは Storyboard / XIB を使わない方針(2-2)であり `NSMainNibFile` を
  /// Info.plist に設定していないため、既定実装では `NSApp.delegate` が nil のままになり、
  /// `applicationDidFinishLaunching` が一度も呼ばれずウィンドウもメニューも生成されない。
  /// そのため `NSApplication` の初期化とデリゲート設定をここで明示的に行う。
  static func main() {
    let app = NSApplication.shared
    // NSApplication.delegate は weak 参照。ここでローカル変数として保持することで、
    // 直後の代入直後に解放されるのを防ぐ。app.run() はアプリ終了まで返らないため、
    // このローカル変数のスコープがアプリの生存期間全体をカバーする。
    let delegate = AppDelegate()
    app.delegate = delegate
    // Dock とメニューバーに出る通常のアプリとして扱う。
    app.setActivationPolicy(.regular)
    app.run()
  }

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
