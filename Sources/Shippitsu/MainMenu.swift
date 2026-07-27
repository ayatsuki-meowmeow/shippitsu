import AppKit

@MainActor
enum MainMenu {
  static func make(appName: String) -> NSMenu {
    // AppKit のメニューバーは 2 階層構造:
    //   NSApp.mainMenu(＝この NSMenu)
    //     └─ [0] NSMenuItem  ← この「先頭項目」の submenu がアプリメニューになる
    //          └─ NSMenu     ← 「執筆を終了」などが並ぶのはこちら
    // 終了項目を mainMenu へ直接 addItem するとメニューバーに裸で並び、S-3.3 を満たせない。
    let mainMenu = NSMenu()

    // 先頭項目そのものの title は表示に使われない(macOS が Info.plist の
    // CFBundleName / CFBundleDisplayName で差し替える)。空文字で構わない。
    let appMenuItem = NSMenuItem()
    mainMenu.addItem(appMenuItem)

    let appMenu = NSMenu(title: appName)
    appMenuItem.submenu = appMenu

    let quitItem = NSMenuItem(
      title: "\(appName)を終了",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"  // 修飾キーの既定が Command なので ⌘Q になる
    )
    quitItem.target = nil  // レスポンダチェーン経由で NSApp.terminate(_:) に届く
    appMenu.addItem(quitItem)

    return mainMenu
  }
}
