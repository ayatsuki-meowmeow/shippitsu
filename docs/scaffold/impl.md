# scaffold — 実装詳細

`docs/scaffold/design.md` の決定事項 **D-1〜D-15** を、どのファイル・どの実装で満たすかを実装着手前に固めた upfront ドキュメント。実装エージェントとコミットエージェントはこのドキュメントを読んで作業する。（D-12〜D-15 は Git / GitHub / コミット作成者 / PR の base に関する決定で、3 章の Step 11 と 4 章に効く。**`main` の用意方法と PR 作成手順の正は D-15**。）

**このドキュメントの位置づけ:** design.md が「何を作るか（仕様・要件）」、本ドキュメントが「どう作るか（実装詳細）」。あわせて、**本ドキュメントの 3 章が NFR-5（再現性のあるセットアップ手順の文書化）を満たす成果物である**（README 等は別途作らない。理由は 3 章冒頭）。したがって実装着手前の upfront ドキュメントであると同時に、実装完了後も維持される常設ドキュメントでもある。仕様の決定者はユーザーであり、本ドキュメントは design.md の決定に反する内容を含まない。design.md から答えが出ない仕様レベルの疑問は、本ドキュメントで補完せず design.md の未決事項へ差し戻す。

**環境（2026-07-27 時点で実測）:**

| 項目 | 値 |
|------|-----|
| macOS | 26.3（Build 25D125） |
| Xcode | 26.6（Build 17F113） |
| Swift | 6.3.3（swiftlang-6.3.3.1.3） |
| `swift-format` | `/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format`（`xcrun swift-format` で利用可。PATH には無い） |
| `xcodegen` | 未インストール（本タスクで導入） |
| `swiftlint` | 未インストール（本タスクで導入） |
| Homebrew | `/opt/homebrew/bin/brew`（導入済み） |
| Git | **【2026-08-24 時点】初期化済み。`feat/init-scaffold` に 6 コミットを作成し、`https://github.com/ayatsuki-meowmeow/shippitsu`（**public** / D-13）へ push 済み。** 残るは D-15 に従った `main` の空コミット作成 → push → PR 作成のみ（Step 11 の 6〜8） |

---

## 1. 構成

design.md S-1 は外形的な仕様のみを規定しているため、具体的なディレクトリ階層とファイル名を本セクションで確定させる。

```
/Users/konoreiji/shippitsu/
├── project.yml                          # XcodeGen のプロジェクト定義。人間・Claude が編集する唯一のプロジェクト定義ファイル（S-1 / NFR-1）
├── .gitignore                           # 生成物・ユーザー固有ファイルを Git 追跡から除外（D-8）
├── Sources/
│   └── Shippitsu/                       # アプリ本体ターゲットのソース。project.yml がこのディレクトリを丸ごとスキャンする（FR-4）
│       ├── AppDelegate.swift            # @main エントリポイント。ウィンドウ生成・メニュー設定・終了ポリシー・表示名の解決を担う（S-3 / D-3）
│       ├── MainMenu.swift               # メニューバー（アプリメニュー + 終了項目）の構築（S-3.3）
│       └── MainWindow.swift             # メインウィンドウ 1 枚の生成（S-3.1 / S-4 の空ウィンドウ）
├── Tests/
│   └── ShippitsuTests/                  # テストターゲットのソース。同じくディレクトリスキャン
│       └── ScaffoldPlaceholderTests.swift  # プレースホルダのテスト 1 件（D-9）
├── .claude/
│   └── skills/                          # 本リポジトリで従う開発規約（6 スキル）。Git 追跡対象（4 章コミット 2 / D-12）
├── docs/
│   └── scaffold/
│       ├── design.md                    # 仕様・要件（本タスクの単一情報源）
│       └── impl.md                      # 本ファイル
├── Generated/                           # ★生成物（Git 追跡対象外）
│   └── Info.plist                       # project.yml の info ブロックから xcodegen が生成する
├── Shippitsu.xcodeproj/                 # ★生成物（Git 追跡対象外、D-8）
└── DerivedData/                         # ★生成物（Git 追跡対象外、D-8）
```

★ = `xcodegen` / `xcodebuild` が生成するため `.gitignore` で除外する。手で編集しない。

**命名の根拠:**

- `Sources/<ターゲット名>/` `Tests/<ターゲット名>Tests/` は Swift Package Manager 由来の慣行であり、Swift エコシステムで最も予測しやすい配置。将来 SPM モジュールへ切り出す場合も移行が素直（NFR-4）。
- ターゲット名・ディレクトリ名は英字 `Shippitsu` に統一する（D-3）。日本語「執筆」はパス・ディレクトリ名には一切使わない。
- `Generated/` は「生成物置き場」であることを名前で示す。`Support/` のような曖昧な名前だと、`Info.plist` を手編集してよいファイルと誤認され、`xcodegen generate` で消える事故につながるため避けた。
- アプリ本体のソースは **3 ファイル**とする。当初案は `AppInfo.swift` を加えた 4 ファイルだったが見直した。分割の根拠と `AppInfo.swift` を落とした理由は **2-2「ファイル分割の方針」**に記録する。

**`.gitignore` の内容（D-8）:**

```gitignore
.DS_Store

# XcodeGen が生成するもの（project.yml から再生成できる）
/Shippitsu.xcodeproj/
/Generated/

# ビルド中間生成物
/DerivedData/
/.build/

# ユーザー固有の Xcode 設定
xcuserdata/
*.xcuserstate
*.xcscmblueprint
```

---

## 2. 技術的判断

### 2-1. `project.yml` の構成方針

**ターゲット構成:** アプリ本体 `Shippitsu`（`type: application`）+ テスト `ShippitsuTests`（`type: bundle.unit-test`）の 2 ターゲット（S-1 / D-7）。テストターゲットはアプリ本体へ `dependencies` を張る。

**`Info.plist` は YAML 内にインラインで書く（`info:` ブロック）。別ファイルを手書きしない。**

理由:

1. **NFR-1（Claude が安全に編集できるテキスト形式）に直結する。** `Info.plist` は XML であり、Claude が直接編集すると構造破壊のリスクがある。YAML に集約すれば編集対象は `project.yml` 1 ファイルだけになり、S-1 の「`project.yml` が唯一のプロジェクト定義ファイル」という仕様とも一致する。
2. **二重管理を避けられる。** Bundle ID や表示名を 2 箇所に書くと、片方だけ直す事故が起きる。
3. **生成された `Info.plist` は生成物として扱える。** `Generated/Info.plist` に出力し `.gitignore` で除外することで、D-8 の「生成物は追跡しない」方針と揃う。

トレードオフ: `xcodegen generate` を実行するまで `Info.plist` が存在しない。ビルド前に必ず `xcodegen generate` を通す運用（S-2 のセットアップ手順）なので実害はない。

**D-3（表示名 / 内部名 / Bundle ID）の割り当て — 取り違え禁止:**

| 対象 | 値 | 効果 |
|------|-----|------|
| XcodeGen のターゲット名 | `Shippitsu` | Xcode 上のターゲット名。生成される Swift モジュール名（`@testable import Shippitsu`）にもなる |
| `PRODUCT_NAME` | `Shippitsu` | 生成物 `Shippitsu.app` と実行ファイル名 |
| `CFBundleExecutable` | `$(EXECUTABLE_NAME)` → `Shippitsu` | 実行ファイル名。英字のまま |
| `CFBundleName` | **執筆** | メニューバーのアプリメニュー名。macOS はここ（または `CFBundleDisplayName`）を使う |
| `CFBundleDisplayName` | **執筆** | Finder / Dock の表示名 |
| `PRODUCT_BUNDLE_IDENTIFIER` / `CFBundleIdentifier` | **`com.ayatsukiaya.shippitsu`** | Bundle Identifier |

`CFBundleName` と `CFBundleDisplayName` の**両方**に「執筆」を入れる。macOS のバージョンによってアプリメニューのタイトルがどちらを参照するかが揺れるため、両方を揃えて曖昧さを消す。ディレクトリ名・ターゲット名・実行ファイル名はすべて英字 `Shippitsu` のまま（D-3 の「日本語パスに起因するトラブルを避ける」意図）。

> ⚠ Bundle ID は `com.konoreiji.shippitsu` **ではなく** `com.ayatsukiaya.shippitsu` が正（design.md D-3 の注意書き）。

**deployment target:** `options.deploymentTarget.macOS: "26.0"`（D-4）。`LSMinimumSystemVersion` には `$(MACOSX_DEPLOYMENT_TARGET)` を渡し、二重管理しない。

**`project.yml` の骨子（実装時の出発点）:**

```yaml
name: Shippitsu
options:
  bundleIdPrefix: com.ayatsukiaya
  deploymentTarget:
    macOS: "26.0"
  createIntermediateGroups: true

settings:
  base:
    SWIFT_VERSION: "6"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    CODE_SIGN_IDENTITY: "-"          # ad-hoc 署名。ローカル実行に必要な最小限
    CODE_SIGN_STYLE: Manual
    SWIFT_TREAT_WARNINGS_AS_ERRORS: NO

targets:
  Shippitsu:
    type: application
    platform: macOS
    sources:
      - path: Sources/Shippitsu
    settings:
      base:
        PRODUCT_NAME: Shippitsu
        PRODUCT_BUNDLE_IDENTIFIER: com.ayatsukiaya.shippitsu
    info:
      path: Generated/Info.plist
      properties:
        CFBundleName: 執筆
        CFBundleDisplayName: 執筆
        CFBundleExecutable: $(EXECUTABLE_NAME)
        CFBundleIdentifier: $(PRODUCT_BUNDLE_IDENTIFIER)
        CFBundlePackageType: APPL
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        LSMinimumSystemVersion: $(MACOSX_DEPLOYMENT_TARGET)
        NSPrincipalClass: NSApplication
        NSHighResolutionCapable: true
    scheme:
      testTargets:
        - ShippitsuTests

  ShippitsuTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests/ShippitsuTests
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES   # ← 実装時に必要と判明（下の補足を参照）
    dependencies:
      - target: Shippitsu
```

補足:

- `scheme.testTargets` を書くことで `Shippitsu` スキームが生成され、`xcodebuild test -scheme Shippitsu` が動く。スキームが無いと `xcodebuild` がターゲットを見つけられない。
- **`ShippitsuTests` には `GENERATE_INFOPLIST_FILE: YES` が必須**（2026-07-28、実装時に判明して骨子へ反映済み）。当初の骨子にはこの行が無く、`ShippitsuTests` に `info:` ブロックも `GENERATE_INFOPLIST_FILE` も無いため Info.plist が存在せず、Step 8（`xcodebuild test`）が `Cannot code sign because the target does not have an Info.plist file` で失敗した。Xcode に自動生成させることで解決している。**「`Info.plist` を手書きしない」という本節の方針とは矛盾しない** — アプリ本体は `info:` ブロック（`project.yml` が単一情報源）、テストターゲットは Xcode の自動生成に委ねるだけで、いずれも手書きの XML は増えていない。テストターゲットの Info.plist に固有の値を持たせる必要が無いため、`info:` ブロックを書かず自動生成に寄せるほうが記述量が少ない。
- `INFOPLIST_FILE` は `info.path` から XcodeGen が自動設定するため、`settings` に手書きしない（二重指定を避ける）。
- **`TEST_HOST` / `BUNDLE_LOADER` は XcodeGen が自動設定する**（2026-07-28、Step 6 で実測確認済み）。`project.yml` への手動追加は不要だった。
- `CODE_SIGN_IDENTITY: "-"`（ad-hoc）はローカル実行とテスト実行に必要な最小限の設定。`DEVELOPMENT_TEAM` は設定しないため、将来 Developer ID 署名・公証・App Store 配布へ移行する道を塞がない（NFR-4）。
- `SWIFT_VERSION: "6"` で Swift 6 言語モード（strict concurrency）を有効にする。グリーンフィールドの今なら適用コストがほぼゼロで、後から遡って直すと全ファイルに波及するため。AppKit の型は `@MainActor` なので、後述のファクトリ関数にも `@MainActor` を付ける。
- **⚠ `SWIFT_VERSION: "6"` × `@main` + `NSApplicationDelegate` は本タスクで踏みうる詰まりどころ。** 既知の摩擦で、Step 7（ビルド）で最初に表面化する可能性がある。`NSApplicationDelegate` は `@MainActor` 隔離プロトコルである一方、`@main` が要求する `static func main()` は隔離コンテキストの整合を求めるため、「Main actor-isolated ... cannot satisfy nonisolated requirement」系のエラーが出ることがある。
  - **第 1 対処:** `AppDelegate` クラス宣言に `@MainActor` を明示する（2-2 の骨子はこれを織り込み済み）。ファクトリの `enum MainMenu` / `enum MainWindow` にも `@MainActor` を付ける。
  - **第 2 対処:** それでも解けない場合は、エラーメッセージが指す個別の要求に `nonisolated` を付ける。
  - **最終手段（＝ Claude が単独で採ってはいけない対処）:** 上記で解けないときの `SWIFT_VERSION: "5"` への引き下げは、**design.md の未決事項へ差し戻す class として扱う。** Swift 6 言語モードの採用は「グリーンフィールドの今なら適用コストがほぼゼロで、後から遡って直すと全ファイルに波及する」という理由で選んだ**プロジェクト全体に効く前提**であり、引き下げると後続タスクのすべてのコードがその前提の上に乗る。**「本節に追記して完了報告で提示する」では弱すぎる**（それでは 6-2 の SwiftLint ルール 1 個の無効化より軽い扱いになり、影響範囲と釣り合わない）。したがって:
    1. **エージェントは引き下げを実行しない。** 実装ループを止める。
    2. `docs/scaffold/design.md` の**未決事項として起票**し、選択肢（Swift 6 のまま別の回避策を探す / Swift 5 へ引き下げる）とトレードオフを提示してユーザーの判断を仰ぐ。
    3. 判断が出たら決定事項へ転記し、本節を決定内容に合わせて書き換える。
  - この問題は「後続タスクへの影響」（6-4）ではなく**本タスクの Step 7 で踏みうる**ものとして扱う。ビルドが 1 発で通らなくても構成自体を疑う必要はない。
  - **【実績 / 2026-07-28】実際には第 1 対処（`AppDelegate` / `MainMenu` / `MainWindow` への `@MainActor` 明示）のみでビルドが通った。** 第 2 対処の `nonisolated` も、最終手段の `SWIFT_VERSION: "5"` への引き下げも**不要だった**。`SWIFT_VERSION: "6"` は据え置きであり、上記の未決事項起票も発生していない。

### 2-2. アプリのエントリポイントの実装方式

> **本節以降のコード骨子の読み方（重要）:** 掲載しているコードは**整形前かつ `import` 等を省いた抜粋**であり、完全なファイル内容でも整形後の姿でもない。インデントは説明用に 4 スペースで書いているが `swift-format` の既定は **2 スペース・1 行 100 桁**であり、Step 5 の `swift-format format --in-place` を通した実ファイルはそれに従う。また `MainWindow` / `MainMenu` の骨子には `import AppKit` を記載していないが、実ファイルには必要である。**骨子は「何をどの順序で組み立てるか」を示すものであり、字面をそのまま写すためのものではない。** 骨子と実ファイルの字面が違っても差分ではない（実際に相違が生じた箇所は「5. 実装状況」の補足に記録する）。

**方針:** SwiftUI は使わず AppKit（D-1）。`@main` を付けた `NSApplicationDelegate` 準拠クラスをエントリポイントとする。Storyboard / XIB（`MainMenu.xib`）は使わず、ウィンドウもメニューもコードで組み立てる。

**なぜ XIB を使わないか:** XIB は巨大な機械生成 XML であり、Claude が安全に編集できない（NFR-1）。メニュー 1 個・ウィンドウ 1 枚の構築ならコードのほうが短く、差分レビューも可能。

**S-3 の振る舞い → 実装の対応表:**

| S-3 の項目 | 実装 |
|-----------|------|
| 1. 起動するとウィンドウが 1 枚表示される | `AppDelegate.applicationDidFinishLaunching(_:)` で `MainWindow.make(title:)` を呼び、`makeKeyAndOrderFront(nil)`。`AppDelegate` が `mainWindow` を強参照で保持する |
| 2. ウィンドウにアプリ名がタイトル表示される | `window.title = appName`（`AppDelegate.resolveDisplayName()` が返す `CFBundleDisplayName` = 執筆） |
| 3. メニューバーにアプリ名が出て、`アプリ名 > 終了`（Cmd+Q）で終了 | `NSApp.mainMenu = MainMenu.make(appName:)`。メニュー階層の組み立て方は後述の骨子を参照（ここを誤ると S-3.3 を満たせない）。アプリメニューのタイトルは macOS が `CFBundleName` / `CFBundleDisplayName` から差し替えるため、Info.plist 側で「執筆」を保証する（2-1 参照） |
| 4. ウィンドウを閉じるとアプリが終了する | `applicationShouldTerminateAfterLastWindowClosed(_:) -> Bool` で `true` を返す |

**ファイル分割の方針（3 ファイル）とその根拠:**

当初案は `AppDelegate` / `AppInfo` / `MainMenu` / `MainWindow` の 4 ファイルだったが、以下のとおり見直した。

1. **撤回した根拠。** 「`AppDelegate` が肥大化すると SwiftLint の `function_body_length` / `type_body_length` に抵触しやすい」という理由は本タスクの規模では成立しない。SwiftLint の既定は関数 50 行・型 250 行であり、空ウィンドウ 1 枚の `applicationDidFinishLaunching` は 10 行前後、アプリ本体のコード全量でも 70 行程度にとどまる。この根拠は使わない。
2. **`AppInfo.swift` は作らない。** `Bundle.main` から 1 キー読むだけで、呼び出し箇所も `applicationDidFinishLaunching` の 1 箇所しかない。独立した型・独立したファイルにする必然性が無く、ファイルを 1 枚増やすコストのほうが大きい。表示名の解決は `AppDelegate` の private static メソッドに置く（後述の骨子）。なお「表示名の単一情報源は Info.plist（2-1 の `info.properties`）」という原則は変わらない — `AppInfo` 型はその原則の担い手ではなく、単なる読み出し口にすぎなかった。
3. **`MainMenu` / `MainWindow` は分ける。** これは「後続タスクで `NSTextView` を載せるとき変更が 1 ファイルに閉じる」という将来都合ではなく、**現時点の可読性の判断**である。両者は `AppDelegate` の状態に触れない独立したファクトリ（それぞれ 20〜30 行）であり、分けておくと `AppDelegate` を**「ライフサイクル + 起動時に必要な小さなヘルパ（表示名の解決）」**に保てる。上記 2 のとおり `resolveDisplayName()` は `AppDelegate` に置いているため、`AppDelegate` は「ライフサイクルだけ」ではない — ウィンドウとメニューの**組み立て手順**を持ち込まない、というのが実際の線引きである。結果として後続タスクでも都合が良いが、それは理由ではなく副次的な効果である。
4. **NFR-6 との関係（リバート対象ではない）。** NFR-6 が禁じているのは「縦書き・IME の検証結果しだいで取り消しが必要になる先取り**実装**」である。ファイルの置き場所は検証結果に左右されず、後で 1 ファイルに畳むのも分け直すのもコード移動のみで、機能の取り消し（リバート）は発生しない。したがってファイル分割は NFR-6 の禁止対象に当たらない。ただし **D-6 の最小スコープに照らして「増やす方向の判断はしない」**ことは守り、上記 2 のとおりファイル数は減らした。

**ウィンドウの生成場所:** `AppDelegate.applicationDidFinishLaunching(_:)` で `MainWindow.make(title:)` を呼ぶ。`AppDelegate` は「組み立てて表示する」だけに留める。

**実装の骨子:**

```swift
// AppDelegate.swift
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

    /// 表示名を Info.plist から解決する。単一情報源は project.yml の info.properties（2-1）。
    /// CFBundleDisplayName → CFBundleName → リテラルの順にフォールバックする。
    private static func resolveDisplayName() -> String {
        let bundle: Bundle = .main
        if let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            !name.isEmpty
        {
            return name
        }
        if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
            !name.isEmpty
        {
            return name
        }
        return "執筆"  // 最終フォールバック（D-3 の表示名）
    }
}
```

**フォールバックの設計（実装エージェントはこの順序で書くこと）:**

| 順 | 参照先 | 備考 |
|----|--------|------|
| 1 | `CFBundleDisplayName` | 正常系。2-1 で「執筆」を入れている |
| 2 | `CFBundleName` | 1 と同じ値を入れているため、片方だけ欠けた場合の保険 |
| 3 | リテラル `"執筆"` | 最終フォールバック |

- **`ProcessInfo.processInfo.processName` は使わない。** これは実行ファイル名 `Shippitsu` を返すため、D-3 が定めた表示名「執筆」と食い違う値が UI に出てしまう。「英字が出る」ほうが「異常に気づける」ように見えるが、S-3.2 / S-3.3 が要求するのは表示名の一致であり、誤った値を出すより正しい既定値を出すほうが要件に近い。
- **リテラル `"執筆"` は Info.plist との二重管理になる**が、ここに到達するのは `Generated/Info.plist` の生成失敗など異常時のみで、通常の変更経路（`project.yml` を直す）とは交わらない。空文字や英字名がウィンドウタイトル・メニューに出る事故を防ぐ側を優先した。
- 空文字チェック（`!name.isEmpty`）を入れるのは、キーが存在して値が空のときに黙って空タイトルになるのを防ぐため。
- **⚠【実績 / 2026-07-28】上の骨子の `if let ... , !name.isEmpty { ... }`（複数行条件）はそのままでは Step 5 を通らない。** `swift-format`（複数行条件では `{` を次行へ送る）と SwiftLint の `opening_brace`（`{` は宣言と同じ行を要求）が真っ向から衝突し、**両方を同時に満たせない**。実装では判定を `nonEmptyInfoString(_:forKey:)` という private static ヘルパーへ切り出して条件を 1 行に収める形へ書き換えて解消した（**ルールの無効化はしていない** — D-10 / 6-2 の「まずコードを直す」に従った）。フォールバックの順序（`CFBundleDisplayName` → `CFBundleName` → リテラル）は変更していない。この骨子を写経すると同じ衝突を踏むので、複数行条件を書かないこと。詳細は「5. 実装状況」の補足と 6-2 を参照。

**`@MainActor` を明示する理由:** `NSApplicationDelegate` は `@MainActor` 隔離されたプロトコルであり、`SWIFT_VERSION: "6"`（2-1）の strict concurrency 下では `@main` の要求する `static func main()` との隔離が噛み合わずコンパイルエラーになりやすい。クラス宣言に `@MainActor` を明示して先に噛み合わせておく（2-1 の `SWIFT_VERSION` 注記 / Step 7 参照）。

```swift
// MainWindow.swift
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
        window.isReleasedWhenClosed = false   // ARC 下で二重解放を避けるため必須
        window.center()
        return window
    }
}
```

```swift
// MainMenu.swift
@MainActor
enum MainMenu {
    static func make(appName: String) -> NSMenu {
        // AppKit のメニューバーは 2 階層構造:
        //   NSApp.mainMenu（＝この NSMenu）
        //     └─ [0] NSMenuItem  ← この「先頭項目」の submenu がアプリメニューになる
        //          └─ NSMenu     ← 「執筆を終了」などが並ぶのはこちら
        // 終了項目を mainMenu へ直接 addItem するとメニューバーに裸で並び、S-3.3 を満たせない。
        let mainMenu = NSMenu()

        // 先頭項目そのものの title は表示に使われない（macOS が Info.plist の
        // CFBundleName / CFBundleDisplayName で差し替える）。空文字で構わない。
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
```

**メニュー構築で外してはいけない点（S-3.3 の成否がここで決まる）:**

1. **`NSApp.mainMenu` の先頭 `NSMenuItem` の `submenu` がアプリメニューになる。** これは AppKit の暗黙の規約で、API シグネチャからは読み取れない。先頭項目を作らずに終了項目を `mainMenu` へ直接足すと、メニューバーの並びが崩れて「アプリ名 > 終了」の階層にならない。
2. **先頭項目の `title` は当てにしない。** 実際にメニューバーへ出るアプリ名は macOS が Info.plist から差し替える。だからこそ 2-1 で `CFBundleName` / `CFBundleDisplayName` の両方に「執筆」を入れている。
3. **`keyEquivalent: "q"` は小文字で書く。** 大文字 `"Q"` にすると Shift 付き（⇧⌘Q）と解釈される。
4. **`target = nil`** にしてレスポンダチェーンへ委ねる。`NSApp` を直接 target にしても動くが、nil-targeted action が AppKit の標準形。
5. `NSMenuItem` / `NSMenu` は `@MainActor` 隔離型のため、`make(appName:)` を持つ `enum` にも `@MainActor` を付ける（2-1 の Swift 6 言語モード）。

実装上の注意（ハマりどころ）:

- `NSWindow.isReleasedWhenClosed` の既定は `true`。ARC で強参照を持ったままウィンドウを閉じるとクラッシュするため、**`false` を明示し、かつ `AppDelegate` が強参照を保持する**。S-3.4 のウィンドウを閉じる操作で必ず踏むパスなので落とせない。
- アクティブ化は `NSApp.activate()` を使う。`activate(ignoringOtherApps:)` は macOS 14 で非推奨になっており、deployment target が macOS 26（D-4）である以上、新 API のみを使えば非推奨警告が出ない。
- `@main` と `main.swift` は共存できない。`main.swift` という名前のファイルを作らないこと。
- 終了メニュー項目のタイトルは macOS 標準慣行に合わせて `"\(appName)を終了"`（= 「執筆を終了」）とする。design.md S-3.3 の `アプリ名 > 終了` は「アプリメニュー配下の終了項目」を指す記述と解釈しており、この文言で満たす。文言を厳密に「終了」にしたい場合はユーザーの指示で変更する。

**⚠【実績 / 2026-08-09】`@main` を付けるだけでは、nib を使わない構成でデリゲートが生成されない — 実機検証で判明した致命的な不具合と修正。**

ユーザーが `open DerivedData/Build/Products/Debug/Shippitsu.app` で実機起動したところ、**ウィンドウが 1 枚も開かず、メニューバーにはアプリ名だけが出て終了項目（Cmd+Q）が無い**という S-3.1 / S-3.3 を満たさない不具合が判明した。原因と対処は以下のとおり。

- **原因:** 当初の実装は上記の骨子どおり `@main @MainActor final class AppDelegate: NSObject, NSApplicationDelegate` のみで、独自の `static func main()` を持たなかった。この場合 `@main` は AppKit が提供する既定の `static func main()`（内部で `NSApplicationMain` を呼ぶ）を使う。**`NSApplicationMain` は `Info.plist` の `NSMainNibFile` が指す nib からアプリケーションデリゲートを生成する仕組みであり**、本プロジェクトは XIB / Storyboard を使わない方針（本節冒頭）のため `NSMainNibFile` を設定していない。結果として `NSApp.delegate` が nil のままアプリが起動し、`applicationDidFinishLaunching` が一度も呼ばれず、ウィンドウ生成もメニュー構築も実行されなかった。メニューバーにアプリ名だけが出ていたのは AppKit の既定の空メニューバーであり、終了項目が無いため Cmd+Q も効かなかった（Dock からの終了は launchd 経由のため引き続き可能だった）。
- **対処:** `@main` は型が独自の `static func main()` を持つ場合そちらを優先して呼ぶ。この性質を利用し、`AppDelegate` に明示的な `static func main()` を実装して `NSApplication` の初期化とデリゲート設定を自前で行う形に変更した。`main.swift` を新設して `@main` を外す方式（本節冒頭のとおり `@main` と `main.swift` は共存できない）も検討したが、**`@main` を維持したまま `static func main()` を明示することで済んだため、ファイル構成（1 章）を変える必要は無かった。**

```swift
// AppDelegate.swift（抜粋）
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
```

- **`setActivationPolicy(.regular)` を明示した理由:** `Info.plist` に `LSUIElement` を設定していないため既定でも `.regular` 相当にはなるが、「Dock とメニューバーに出る通常のアプリとして扱われる」という意図をコードで明示し、将来 `LSUIElement` 等の設定が入っても意図が崩れにくくするため。
- **Swift 6 言語モードとの整合:** `static func main()` は `@MainActor` クラスのメンバーとして `@MainActor` 隔離されるが、`@main` が合成するエントリポイント自体も `@MainActor` 隔離されたコンテキストとして扱われる（SE-0343）ため、2-1 で踏んだ MainActor 隔離の摩擦は本メソッドの追加では再発しなかった。
- **後続タスクへの教訓（重要な落とし穴として記録）:** **`@main` を `NSApplicationDelegate` 準拠クラスに付けるだけでは、`NSMainNibFile` を設定しない（nib を使わない）構成において一切のライフサイクルメソッドが呼ばれない。** 「`@main` を付ければ AppKit アプリとして動く」という直感は nib ベースの伝統的なプロジェクト構成を前提にしており、本プロジェクトのような **XIB レス構成では成立しない。** 今後 AppKit のエントリポイントに触れる作業（本タスクに限らない）では、`static func main()` を明示するか、`NSApplicationMain(_:_:)` を直接呼ぶ等、nib に依存しない起動経路を必ず用意すること。
- **検証方法（実機での確認手順）:** `open` でアプリを起動した状態で以下が有効だった。
  - `pgrep -x Shippitsu` — プロセスの存在確認（実行ファイル名ベース）。
  - `lsappinfo list` / `lsappinfo info <pid>` — `type="Foreground"` であることから、Dock・メニューバーに出る通常アプリとして登録されていることを確認できる。`bundleID` / 表示名（`執筆`）も併せて確認できる。
  - `applicationDidFinishLaunching` 内に一時的なマーカーファイル書き込みを仕込み、起動後にファイルの生成を確認する手法で、修正前は書き込まれず・修正後は書き込まれることを直接確認した（確認後にコードは削除済み）。
  - **効かなかった手段:** `osascript ... tell application "System Events" to count windows of process "..."` は `-25211`（osascript には補助アクセスは許可されません）で失敗し、`screencapture` も `could not create image from display`（画面収録権限なし）で失敗した。いずれも TCC（プライバシー権限）がターミナル / エージェント実行環境に付与されていないためであり、コード側の問題ではない。**ウィンドウの実際の描画・タイトル・メニューバー上の見た目は、この環境からは機械的に確認できない。** ユーザーによる目視確認が必要な理由はここにある（6-1 のチェックリストを参照。本節はそのチェックリスト自体は変更しない）。

### 2-3. テストフレームワークの選択 — **Swift Testing を採用**

プレースホルダのテスト 1 件（D-9）は **Swift Testing**（`import Testing` / `@Test` / `#expect`）で書く。XCTest は使わない。

**理由:**

1. **XcodeGen 側の設定差はゼロ。** テストターゲットの型は両者とも `bundle.unit-test` であり、フレームワークの違いはソースコード上の `import` だけ。「XcodeGen の設定例は XCTest のほうが枯れている」という懸念は、XcodeGen が関与しない層の話なので当たらない。
2. **`xcodebuild test` の成熟度も現時点では差がない。** Swift Testing は Xcode 16 以降 `xcodebuild test` に統合済みで、本環境は Xcode 26.6 / Swift 6.3.3。数世代分の成熟期間を経ている。
3. **後続タスクで有利。** 縦書き組版のテストは「文字数 × 行数の組み合わせ」「禁則処理の入力パターン」のようなパラメタライズドテストが中心になる見込みで、Swift Testing の `@Test(arguments:)` は XCTest より圧倒的に記述量が少ない。テストは後続タスクで大量に書く前提（D-7「テストはマスト」）なので、この差は効いてくる。
4. **ユーザーがレビューできる。** ユーザーは Swift を読めないが他言語の知識でレビューする（D-5 の理由）。`#expect(a == b)` は Jest / Vitest の `expect` に近く、`XCTAssertEqual` より他言語の直感が効く。

**リスクと退避経路:** 万一 Swift Testing 側でテストが検出されない・実行できない等の問題が出た場合、**同一テストターゲット内で XCTest と併存できる**（`import XCTest` したクラスを足すだけ）。フレームワーク選択は取り消しコストが小さく、NFR-6 に反しない。

**前提となる依存と、実行時に起きること（実装エージェントが誤診しやすい点）:**

| # | 内容 |
|---|------|
| 1 | **`@testable import Shippitsu` はアプリターゲットの `ENABLE_TESTABILITY` に依存する。** Debug 構成では既定 YES のため実害はまず出ないが、本節は「テストホストの結線を実際に検証する」ことを目的に掲げている以上、依存関係として明記しておく。Release 構成でテストを走らせると（既定 NO のため）`@testable import` がコンパイルエラーになる。テスト実行は Debug で行う（Step 8 のコマンドは `-configuration` 未指定 = Debug） |
| 2 | **macOS の unit test は `TEST_HOST` 経由でアプリを起動するため、テスト実行中に `applicationDidFinishLaunching` が走り、実際にウィンドウが 1 枚開く。** これは正常な挙動でテストは失敗しない。Step 8 のログや画面を見た実装エージェントが「テストなのにアプリが起動した / ウィンドウが出た」を異常と誤診しないこと。逆に言えば、テスト実行はアプリの起動経路を毎回通す（結線検証としての価値がここにもある） |
| 3 | Swift 6 言語モードに起因するコンパイル面のリスクは 2-1 の `SWIFT_VERSION` 注記を参照（テスト側にも同じ隔離規則が及ぶ。`@Test` 関数から `@MainActor` の型に触る場合は関数側にも `@MainActor` が必要になる） |

**プレースホルダの内容:**

```swift
// Tests/ShippitsuTests/ScaffoldPlaceholderTests.swift
import Testing
@testable import Shippitsu

@Test
func scaffoldPlaceholder() {
    #expect(Bool(true))
}
```

`@testable import Shippitsu` を**あえて含める**。D-9 の趣旨は「テストを書ける状態が整っていることを実際に 1 回実行して検証する」ことであり、アプリモジュールを import できるか（テストホスト = `TEST_HOST` / `BUNDLE_LOADER` の結線が正しいか）まで検証してはじめてその趣旨を満たす。import が無いテストは結線の不備を素通りさせる。

なお、テストの中身は `#expect(Bool(true))` のみに留める（D-9 のスコープ限定 / NFR-6）。意味のあるアサーションは後続タスクで書く。

### 2-4. SwiftLint / swift-format の実行方法 — **どちらもビルドフェーズに組み込まず、独立コマンドとして実行する**

**判断:** `project.yml` に `preBuildScripts` / `postBuildScripts` を書かない。lint / format は明示的なコマンドとして叩く。

**理由:**

1. **`implement-review-loop` が毎周 lint を明示実行する前提である。** ビルドフェーズに組み込むと、ループ 1 周のなかで `xcodebuild build` → `xcodebuild test` → 明示 lint と最大 3 回走り、実行時間が無駄に伸びる。ループ側が lint の主体である以上、ビルドは lint を知らないほうが構造として素直。
2. **ビルドの失敗要因を増やさない。** `swiftlint` は `brew install` が必要な外部ツール。ビルドフェーズに入れると、未インストール環境でビルド自体が壊れる（あるいは警告を無視して素通りする）。NFR-2「Claude がビルドエラーを自力で確認・修正できる」観点では、ビルドエラーと lint 指摘は分離されているほうが原因を切り分けやすい。
3. **出力が混ざらない。** `xcodebuild` のログは冗長で、そこに lint 指摘が混ざると Claude が読み落とす。独立コマンドなら指摘だけが出る。
4. **`swift-format` は整形（ファイル書き換え）を伴う。** ビルド中にソースを書き換えるのは、ビルドシステムの入力を実行中に変える行為であり避けるべき。

**実行コマンド（S-5 の基準 4 に対応）:**

```bash
# 整形（ソースを書き換える）
xcrun swift-format format --in-place --recursive Sources Tests

# 整形差分 0 件の検証（差分があれば非ゼロ終了）
xcrun swift-format lint --strict --recursive Sources Tests

# SwiftLint 警告 0 件の検証（--strict で warning を error 扱いにして非ゼロ終了させる）
swiftlint lint --strict Sources Tests
```

`swift-format` は `xcrun` 経由で呼ぶ（PATH に無いことを実測で確認済み）。

**`swiftlint` にも `Sources Tests` と対象を明示する。** 引数なしだとカレントディレクトリ配下を全走査し、`DerivedData/` や `Shippitsu.xcodeproj/` の中まで舐めにいく（実行が遅くなるうえ、生成物由来の指摘が混ざる）。`swift-format` 側の `--recursive Sources Tests` と対象を揃えることで、2 ツールが同じ範囲を見ていることも保証される。

**設定ファイルは作らない。** `.swiftlint.yml` を事前に作らないのは D-10 の明示的な決定。`.swift-format` 設定ファイルも同じ考え方で作らず、まず既定設定で走らせる。既定値のみで衝突するかどうかは実際に走らせて確かめる（**6-2 の「予見されるリスク」**を参照）。

### 2-5. Swift の関数シグネチャ型注釈の方針（`function-signature-typing` 規約の適用）

**規約本体は `function-signature-typing` スキルを参照する**（Swift は適用対象言語）。ここでは本タスクで実際に効く差分だけを書く。一般論は規約側にあるので写さない。

Swift は引数型・戻り値型が文法上必須のため、規約の中核は言語仕様で担保される。本タスクで判断が要るのは次の 2 点のみ。

- **ローカル変数の型注釈は、AppKit の戻り値型が読み手に伝わりにくい箇所で明示する**（`let appName: String = ...` / `let window: NSWindow = ...`）。2-2 の骨子はこの方針で書いてある。ユーザーは Swift を読めないまま他言語の知識でコードレビューを行う（D-5）ため、型が字面に出ていることの価値が通常より高い。
- **`-> Void` は省略してよい**（Swift の慣行）。

本タスクで書かれるのは 70 行程度であり、`Any` の扱いや計算プロパティの型注釈が争点になる場面は生じない見込み。生じた場合は規約本体の判断に従い、規約から外れる必要が出たら実装を止めてユーザーに許可を求める。

---

## 3. 実装ステップ ＝ NFR-5 のセットアップ手順書

各ステップに「完了確認方法」を併記する。確認が通らないうちは次へ進まない。

**この章が NFR-5（再現性のあるセットアップ手順の文書化）を満たす成果物である。** README 等の常設ドキュメントは作らない — D-6 の最小スコープと NFR-6 に照らし、同じ内容を持つ成果物を 2 つ用意して片方が腐る状態を作らないため。「実装着手前の upfront ドキュメント」であることと「セットアップ手順書であること」は両立する（環境を作り直すときは本章を上から順に実行すれば同じ状態が再現できる）。したがって本章は**実装完了後も維持する**（実装が済んだら消してよい作業メモではない）。

**S-2 の 3 操作 — コマンド早見表（引く場所はここ 1 箇所）:**

各ステップ内にも同じコマンドが出てくるが、正はこの表とする。パスはすべてリポジトリルート `/Users/konoreiji/shippitsu` を起点とする。

| S-2 の操作 | コマンド | 対応ステップ |
|-----------|---------|-------------|
| **前提ツールの導入**（初回のみ / D-11） | `brew install mint`<br>`mint bootstrap --link`<br>（`swift-format` は Xcode 同梱。`xcrun swift-format` で使う） | Step 1 |
| **セットアップ**（`project.yml` → `.xcodeproj`） | `xcodegen generate` | Step 6 |
| **ビルド** | `xcodebuild -project Shippitsu.xcodeproj -scheme Shippitsu -configuration Debug -derivedDataPath DerivedData build` | Step 7 |
| **実行** | `open DerivedData/Build/Products/Debug/Shippitsu.app` | Step 10 |
| （参考）テスト | `xcodebuild -project Shippitsu.xcodeproj -scheme Shippitsu -destination 'platform=macOS' -derivedDataPath DerivedData test` | Step 8 |
| （参考）整形 + lint | `xcrun swift-format format --in-place --recursive Sources Tests`<br>`xcrun swift-format lint --strict --recursive Sources Tests`<br>`swiftlint lint --strict Sources Tests` | Step 5 |

環境を作り直す場合は「前提ツールの導入 → セットアップ → ビルド → 実行」の 4 行で足りる（ソースは Git から取得される前提）。`-derivedDataPath DerivedData` は全コマンドで一貫して付ける（6-4 参照）。

> **⚠ PATH の前提（2026-08-25 追記 / `docs/ci/design.md` D-2）:** `swiftlint` / `xcodegen` は **Mint がリポジトリルートの `Mintfile` に固定したバージョン**を使う。`mint bootstrap --link` はそれらを `~/.mint/bin` にリンクするだけで PATH は通さないため、**上表の `swiftlint` / `xcodegen` を含むコマンドは `$HOME/.mint/bin` に PATH が通った状態で実行する**こと。通っていないと brew 版など別バージョンが走り、CI と結果が食い違いうる。
>
> ```bash
> export PATH="$HOME/.mint/bin:$PATH"
> ```
>
> **バージョンの正は `Mintfile`**（現在: SwiftLint 0.65.0 / XcodeGen 2.46.0）。更新は独立した PR で行う。旧手順の `brew install xcodegen swiftlint` はバージョンが固定されず、環境を作り直すたびに別バージョンが入るため置き換えた。CI 側の扱いは `docs/ci/impl.md` を参照。

**役割分担（重要）:**

| 作業 | 担当 |
|------|------|
| `brew install`、ファイル作成、ビルド、テスト、lint、目視確認 | **実装エージェント** |
| `git init`、`feat/init-scaffold` ブランチ作成、`git add` / `git commit` | **コミットエージェント**（実装エージェントは git 操作を一切行わない） |
| `.gitignore` の**ファイル作成** | **実装エージェント**（ファイルを書く行為であって git 操作ではない） |
| 仕様に関わる判断 | **ユーザー**（エージェントは design.md 未決事項へ差し戻す） |

### Step 1. 開発ツールの導入（D-11 により Claude が実行してよい）

```bash
brew install xcodegen
brew install swiftlint
```

**完了確認:** `xcodegen --version` と `swiftlint --version` がそれぞれバージョンを出力する。`xcrun --find swift-format` がパスを返す（導入不要・確認のみ）。

### Step 2. `.gitignore` の作成

「1. 構成」の内容で作成する。

**完了確認:** ファイルが存在し、`/Shippitsu.xcodeproj/` `/Generated/` `/DerivedData/` `xcuserdata/` `.DS_Store` の各行が含まれている。

### Step 3. `project.yml` の作成

「2-1」の骨子どおりに作成する。Bundle ID は `com.ayatsukiaya.shippitsu`、`CFBundleName` / `CFBundleDisplayName` は「執筆」。

**完了確認:** ファイルが存在する（この時点ではまだ生成しない。ソースが無い状態で生成すると空ターゲットになるため Step 6 で生成する）。

### Step 4. ソースファイルの作成

- `Sources/Shippitsu/AppDelegate.swift`
- `Sources/Shippitsu/MainMenu.swift`
- `Sources/Shippitsu/MainWindow.swift`
- `Tests/ShippitsuTests/ScaffoldPlaceholderTests.swift`

**完了確認:** 4 ファイルが存在する。`main.swift` という名前のファイルが**無い**こと（`@main` と競合するため）。`AppInfo.swift` は作らない（2-2 の分割方針）。

### Step 5. 整形と lint（S-5 基準 4 / FR-7 / D-10）

```bash
xcrun swift-format format --in-place --recursive Sources Tests
xcrun swift-format lint --strict --recursive Sources Tests
swiftlint lint --strict Sources Tests
```

**なぜビルド・テストより前に置くか:** `swift-format format --in-place` はソースを書き換える。ビルド・テストを通したあとに整形すると、書き換わったソースでビルド・テストをやり直すことになり、本章冒頭の「確認が通らないうちは次へ進まない」原則に対して往復が発生する。整形をソース作成直後に置けば、この往復は構造的に生じない。lint / format はプロジェクト生成（`.xcodeproj`）に依存しないため、この順序で問題なく実行できる。

**完了確認:** `swift-format lint` が何も出力せず終了コード 0。`swiftlint lint --strict Sources Tests` が警告・エラー 0 件で終了コード 0。

**警告が出た場合の手順:** まず**コード側を直す**。ルール無効化は最終手段であり、6-2 の手順（記録必須）に従う。直したら本ステップの 3 コマンドを再実行する。

> **Step 6 以降でソースを修正した場合**（ビルドエラーの修正、テストの調整など）は、**本ステップに戻って整形と lint をやり直してから**先へ進む。これは手戻りではなく、修正が入ったソースに対する正規の経路である。

### Step 6. プロジェクト生成（S-2 のセットアップ）

```bash
cd /Users/konoreiji/shippitsu && xcodegen generate
```

**完了確認:**

- `Shippitsu.xcodeproj` と `Generated/Info.plist` が生成される。
- `xcodebuild -project Shippitsu.xcodeproj -list` に `Shippitsu` / `ShippitsuTests` の 2 ターゲットと `Shippitsu` スキームが出る。
- テストホストの結線を確認する:
  ```bash
  xcodebuild -project Shippitsu.xcodeproj -target ShippitsuTests -showBuildSettings | grep -E 'TEST_HOST|BUNDLE_LOADER'
  ```
  **【実測済み / 2026-07-28】XcodeGen はアプリターゲットへの依存から `TEST_HOST` / `BUNDLE_LOADER` を自動設定する。** `project.yml` への手動追加は不要だった（2-1 の補足にも記録）。環境を作り直す場合も本コマンドで確認するが、空になることは想定しない。万一空だった場合は `ShippitsuTests` の `settings.base` に以下を明示的に足す:
  ```yaml
  TEST_HOST: $(BUILT_PRODUCTS_DIR)/Shippitsu.app/Contents/MacOS/Shippitsu
  BUNDLE_LOADER: $(TEST_HOST)
  ```
  （対応した場合は本ドキュメントの 2-1 に追記する。）

### Step 7. ビルド（S-5 基準 1 / FR-1）

```bash
cd /Users/konoreiji/shippitsu && xcodebuild -project Shippitsu.xcodeproj -scheme Shippitsu -configuration Debug -derivedDataPath DerivedData build
```

`-derivedDataPath DerivedData` を付けて成果物パスを固定する。既定の `~/Library/Developer/Xcode/DerivedData/<ハッシュ>` だと毎回パスが変わり、次ステップの起動コマンドが安定しないため。D-8 が `.gitignore` に `DerivedData/` を挙げているのもこの運用を前提としている。

**完了確認:** `** BUILD SUCCEEDED **` が出る。警告 0 件が望ましい（警告が出たら原因を潰してから進む）。成果物 `DerivedData/Build/Products/Debug/Shippitsu.app` が存在する。

**ここで最初に踏みうるエラー:** `SWIFT_VERSION: "6"` × `@main` + `NSApplicationDelegate` の MainActor 隔離まわり。2-1 の `SWIFT_VERSION` 注記に対処の順序（`@MainActor` 明示 → `nonisolated` → 最終手段）を記載してある。構成そのものを疑う前にそちらを見ること。ソースを修正したら Step 5 に戻る。

### Step 8. テスト実行（S-5 基準 3 / FR-6 / D-9）

```bash
cd /Users/konoreiji/shippitsu && xcodebuild -project Shippitsu.xcodeproj -scheme Shippitsu -destination 'platform=macOS' -derivedDataPath DerivedData test
```

**完了確認:** `** TEST SUCCEEDED **` が出て、`scaffoldPlaceholder` が 1 件実行されている（0 件実行で成功しても合格にしない。テストが検出されていない可能性があるため、実行件数をログで確認する）。

**ログを読むときの注意:** macOS の unit test は `TEST_HOST` 経由でアプリを起動するため、**テスト実行中に `applicationDidFinishLaunching` が走り、実際にウィンドウが 1 枚開く**。これは正常な挙動であり、異常と誤診しないこと（2-3 の「前提となる依存」参照）。

### Step 9. Bundle ID / 表示名の機械確認（FR-3 / D-3）

```bash
PLIST=DerivedData/Build/Products/Debug/Shippitsu.app/Contents/Info.plist
plutil -extract CFBundleIdentifier  raw "$PLIST"   # => com.ayatsukiaya.shippitsu
plutil -extract CFBundleName        raw "$PLIST"   # => 執筆
plutil -extract CFBundleDisplayName raw "$PLIST"   # => 執筆
plutil -extract CFBundleExecutable  raw "$PLIST"   # => Shippitsu
```

**完了確認:** 4 つの値が上記コメントのとおり。1 つでも違えば `project.yml` を直して Step 6 からやり直す。

### Step 10. 目視確認（S-3 の残り項目 / 6-1 参照）

```bash
open DerivedData/Build/Products/Debug/Shippitsu.app
```

実装エージェントはアプリを起動し、6-1 のチェックリストを自分で確認できる範囲で確認したうえで、**確認しきれなかった項目をユーザーへの動作確認依頼として完了報告に添える**。起動できたことの確認は `pgrep -x Shippitsu` で機械的に取れる（`pgrep` は**実行ファイル名** `Shippitsu` を見る）。

**終了のさせ方:**

```bash
# 第一候補: 実行ファイル名で確実に終了させる（pgrep -x と同じ名前空間）
pkill -x Shippitsu

# 補助: Cmd+Q 相当の graceful 終了を確認したいとき（AppleScript は CFBundleName で解決する）
osascript -e 'quit app "執筆"'
```

> ⚠ `osascript -e 'quit app "Shippitsu"'` は使わない。AppleScript はアプリを **`CFBundleName`（＝「執筆」）** で解決するため、内部名 `Shippitsu` を渡すと "Can't get application" で失敗しうる。実行ファイル名で引ける `pgrep` / `pkill` と名前空間が異なる点に注意する。
>
> なお `quit app "執筆"` はユーザーの操作に近い経路（Cmd+Q と同じ terminate）を通るため S-3.3 の確認に使えるが、名前解決の失敗・確認ダイアログ等でブロックされる余地がある。**確実に落とすことが目的なら `pkill -x Shippitsu` を使う。**

**完了確認:** アプリが起動し、プロセスが存在すること（`pgrep -x Shippitsu` がヒットする）。確認後にプロセスが残っていないこと（`pgrep -x Shippitsu` がヒットしない）。6-1 のチェックリストの各項目について「確認済み」か「ユーザー確認待ち」かが明確になっていること。

### Step 11. Git 操作 —— **コミットエージェントの担当。実装エージェントは実行しない**

> ✅ **ブロックはすべて解除済み（2026-08-24）。** 本ステップは以前 design.md の未決事項 11（`main` ブランチの用意方法）と未決事項 15（空の `main` を PR の base にできない問題）でブロックされていたが、**すべてに判断が出て D-12 / D-13 / D-14 / D-15 として確定した。未決事項は 0 件であり、PR 作成まで通しで実行してよい。**
>
> **【2026-08-24 時点の進捗】下記コマンド列の 1〜5（`git init` 〜 `feat/init-scaffold` の 6 コミット作成 → push）は実行済み。残るは 6〜8（`main` の空コミット作成 → push → PR 作成）のみ。**

**前提となる決定（着手前に design.md の D-12 / D-13 / D-14 / D-15 を読むこと）:**

| 決定 | 本ステップへの効き方 |
|------|---------------------|
| **D-12** | `main` に**プロジェクトのファイルを置かない**。すべてのコミットを `feat/init-scaffold` に乗せる。PR の差分にはプロジェクト全体が現れる |
| **D-13** | リモートは**作成済み**の `https://github.com/ayatsuki-meowmeow/shippitsu`（**public**）。`gh repo create` は**実行しない**。remote として追加するだけ |
| **D-14** | `user.name` は `~/.gitconfig.local` の既存設定（`ayatsuki-meowmeow`）をそのまま使う（**追加設定なし**）。`user.email` のみ**ローカル設定**で GitHub の noreply アドレスを指定する。コミットメッセージに `Co-Authored-By` フッターを**付ける** |
| **D-15** | **`main` に空コミット（`git commit --allow-empty`）を 1 個置いて push し、PR の base にする。** これがないと `main` は ref として存在せず `gh pr create --base main` が必ず失敗する。空コミットは**ファイルを含まない**ため、D-12 の「`main` にファイルを置かない」意図と PR の完全な差分はどちらも維持される |

```bash
cd /Users/konoreiji/shippitsu

# ── 1〜5 は 2026-07-28 に実行済み ────────────────────────────────

# 1. 初期化（D-12）
#    -b main は「最初のコミットを置く先を main にする」という予約にすぎず、
#    この時点で main が ref として作られるわけではない（コミットが 0 件のため）。
git init -b main

# 2. コミット作成者情報（D-14）
#    user.name は ~/.gitconfig.local の設定を継承するため設定しない。
#    user.email はこのリポジトリのローカル設定のみで上書きする（グローバルは触らない）。
git config --local user.email "94098626+ayatsuki-meowmeow@users.noreply.github.com"

# 3. 作業ブランチへ。main にファイルを置かないため、ここで即座に切り替える（D-8 / D-12）
git switch -c feat/init-scaffold

# 4. 4 章のコミット分割案に従って 6 コミットを作成する
#    （commit-workflow 規約に従い、Co-Authored-By フッターを付ける / D-14）

# 5. 既存リポジトリを remote として追加して push（D-13。gh repo create はしない）
#    remote は SSH 形式で登録する（git 操作は SSH 経由という前提。表記の正は下の注記）。
git remote add origin git@github.com:ayatsuki-meowmeow/shippitsu.git
git push -u origin feat/init-scaffold

# ── 6〜8 が残作業（D-15 / 2026-08-24 にブロック解除） ──────────────

# 6. main を PR の base にするための「空コミット」を 1 個作成する（D-15）
#    ファイルを 1 つも含まないコミットを作り、main をそのコミットに向ける。
#    ★ git switch --orphan main は使わない — 追跡ファイルを作業ツリーから削除する
#      副作用があり、feat/init-scaffold での作業（未コミットの変更を含む）に影響するため。
#      下記は作業ツリー・インデックスに一切触れずに同じ結果を得る手順。
#    ★ 作成者情報は 2 で設定済みのローカル設定が使われる（D-14）。
EMPTY_TREE=$(git hash-object -t tree /dev/null)      # 空ツリーのハッシュを得る
EMPTY_COMMIT=$(git commit-tree "$EMPTY_TREE" -F - <<'EOF'
create empty root commit to serve as PR base

PR の base ブランチとして main を実体化させるための空コミット。
ファイルを 1 つも含まないため、main にプロジェクトのファイルは乗らない（design.md D-12 / D-15）。
プロジェクト全体は feat/init-scaffold 側に乗せ、PR の差分に完全な差分が現れる状態を保つ。

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)
git branch main "$EMPTY_COMMIT"                       # main を空コミットに向ける（HEAD は動かさない）

# 7. main を push して、リモートにも base として存在させる（D-15）
git push -u origin main

# 8. PR を作成する（D-12 / D-15）。HEAD は feat/init-scaffold のままでよい。
#    --title / --body を必ず付ける。省略するとインタラクティブモードに入り、
#    エディタが開いてエージェント実行環境では手順が止まるため。
gh pr create \
  --base main \
  --head feat/init-scaffold \
  --title "add project scaffold for Shippitsu (執筆)" \
  --body "$(cat <<'EOF'
Set up the initial project scaffold for the vertical-writing Japanese novel editor.

## 概要

macOS 用縦書き日本語小説エディタ「執筆」のプロジェクト雛形を構築する。
エディタ本体の機能実装（縦書き表示・IME 検証・原稿用紙グリッド等）は後続タスク。

## 含まれる変更

- `.gitignore`: XcodeGen / xcodebuild の生成物とユーザー固有ファイルを除外
- `.claude/skills/`: 本リポジトリで従う開発規約（6 スキル）
- `docs/scaffold/`: 仕様書（design.md / 決定事項 D-1〜D-15）と実装詳細（impl.md）
- `project.yml`: XcodeGen のプロジェクト定義（アプリ本体 + テストの 2 ターゲット）
- `Sources/Shippitsu/`: AppKit の最小アプリ（空のウィンドウ 1 枚 + アプリメニュー）
- `Tests/ShippitsuTests/`: Swift Testing のプレースホルダテスト 1 件

## 受け入れ基準（design.md S-5）の状況 — **4 項目すべて充足**

- [x] ビルドが成功する
- [x] 起動してウィンドウ 1 枚表示・Cmd+Q で終了（**ユーザーの実機目視確認で 2026-08-24 に確認**）
- [x] `xcodebuild test` が成功する（プレースホルダ 1 件が緑）
- [x] SwiftLint 警告 0 件 / swift-format 整形差分 0 件
EOF
)"
```

**PR タイトル・本文の方針:** `commit-workflow` 規約のコミットメッセージと同じ 2 層構造（**1 行目は英語サマリ、詳細は日本語**）に揃える。上記は内容案であり、実際の状況（受け入れ基準のチェック状態など）に合わせて調整してよい。`--fill`（コミットメッセージから自動生成）でも要件は満たすが、6 コミットの内容が機械的に連結されるだけで PR 全体の説明にはならないため、明示指定を推奨する。

> **リポジトリ URL の表記について（design.md D-13 との差分は意図的）:** design.md D-13 は `https://github.com/ayatsuki-meowmeow/shippitsu`（HTTPS 形式）、上記 `git remote add origin` は `git@github.com:ayatsuki-meowmeow/shippitsu.git`（SSH 形式）と表記が異なるが、**同じリポジトリを指しており実害はない。** 使い分けは「**表示用・ブラウザで開く URL は HTTPS、remote に登録するのは SSH**」（git 操作は SSH 経由という前提による）。

D-8 に従い、本 design.md に対応する作業はすべて `feat/init-scaffold` ブランチで行う。

**完了確認:**

- `git branch --show-current` が `feat/init-scaffold` を返すこと。
- `git status` で `Shippitsu.xcodeproj/` `Generated/` `DerivedData/` が untracked にも出ないこと（`.gitignore` が効いている証拠）。
- 全コミット後に `git status` がクリーンであること（**`.claude/` を含め、追跡対象のファイルが残らないこと** — D-12 により「PR に完全な差分を出す」ため、`.claude/skills/` もコミットする。4 章のコミット 2 を参照）。
- `git config --local user.email` が noreply アドレスを返し、`git log -1 --format='%an <%ae>'` が `ayatsuki-meowmeow <94098626+ayatsuki-meowmeow@users.noreply.github.com>` になること（D-14）。
- **`main` に乗っているコミットが「空コミット 1 個だけ」であること（D-15）。**
  - `git rev-list --count main` が **`1`** を返す。
  - `git show --stat main` が**ファイルを 1 つも表示しない**（＝ `main` にプロジェクトのファイルが乗っていない証拠 / D-12 の意図の維持）。
  - > ⚠ **旧・完了確認「`git branch --list main` が空を返すこと」は D-15 により無効（2026-08-24 更新）。** D-12 の「コミットを一切置かない」を前提とした確認であり、空コミットを 1 個置く現在の手順では成立しない。さらにその前の版「`git log main` がコミットを 1 件も返さないこと」も成立しなかった（コミット 0 件の `main` は ref として存在せず、`git log main` は 0 件ではなく `fatal: ambiguous argument 'main': unknown revision` で**エラー終了する**）。**現在有効な確認は上記 2 行である。**
- 各コミットのメッセージ末尾に `Co-Authored-By:` フッターが付いていること（D-14）。**`main` の空コミットも同様**（D-15 のメッセージ案を参照）。
- （PR 作成後）PR の差分にプロジェクト全体（`.gitignore` / `.claude/` / `docs/` / `project.yml` / `Sources/` / `Tests/`）が現れていること（D-12）。**`main` の空コミットはファイルを含まないため、差分はプロジェクト全体になる。**

> ⚠ **`main` に置いてよいのは D-15 の空コミット 1 個だけ。ファイルを含むコミットを独断で置かないこと。** 「ベースブランチにドキュメントや設定を置いておくと扱いやすい」という一般論で初期コミットを作らない。D-12 はユーザーの明示的な指示（「main は空にしておいて、PR で完全な差分を見せてください」）に基づく決定であり、未決事項 11 の選択肢 B の文言に引きずられて `main` に `.gitignore` / `docs/` / `.claude/` を置くのは**誤り**である（判断の経緯は D-12 の解釈欄）。
>
> **D-15（2026-08-24 決定）で許可されたのは「ファイルを 1 つも含まない空コミットを 1 個置く」ことのみ**であり、これは `main` を PR の base として成立させるためである。**`main` にファイルを乗せない**という D-12 の意図は維持されている。

---

## 4. コミット分割案

> ✅ **確定済み（2026-07-28）。** 本章は design.md の**未決事項 11 の判断待ちで暫定**だった（`main` に初期コミットを置くなら `.gitignore` / `docs/` / `.claude/` はこのブランチのコミット対象から外れるため）。**D-12 により `main` にファイルを置かないことが確定した**ので、下記 6 コミットで確定とする。**D-15（`main` に空コミットを 1 個置く）は本章に影響しない** — 空コミットはファイルを含まず、下記 6 コミットとは別枠だからである。

**前提（D-12 / D-15）:** **ファイルを含むコミットはすべて `feat/init-scaffold` に乗る。** `main` に置くのは D-15 の空コミット 1 個（ファイルを含まない）だけであるため、`.gitignore` で除外されないファイルは**すべて**このブランチのコミット対象になり、PR の差分にはプロジェクト全体（`docs/` や `.claude/` を含む）が現れる。ドキュメントやスキル設定を先に `main` へ逃がす運用は採らない。

> **【進捗 / 2026-08-24】下記 6 コミットは作成済みで、`feat/init-scaffold` としてリモートに push 済み。**

**PR 作成前の確認事項（2026-08-24 追記 / コミットエージェント向け）:** 6 コミットの作成後にも以下の変更が発生している。**これらが既存コミットに含まれているか、未コミットとして残っているかは PR 作成前に `git status` / `git log` で確認すること**（本ドキュメントは git の状態を参照していないため断定しない）。**未コミットで残っていれば `feat/init-scaffold` への追加コミットとして積む**（`main` には乗せない / D-12。分割は `commit-workflow` の意味単位に従う）。

| 発生日 | 変更内容 | 対象ファイル |
|--------|---------|-------------|
| 2026-08-09 | `@main` のみではデリゲートが生成されない不具合の修正（`static func main()` の追加。2-2 / 5 章参照） | `Sources/Shippitsu/AppDelegate.swift` |
| 2026-08-09 / 2026-08-24 | 上記不具合の記録、D-15 の転記、S-5 充足状況の確定、Step 11 のブロック解除 | `docs/scaffold/design.md`、`docs/scaffold/impl.md` |

`commit-workflow` 規約の「意味単位」に従う。**`Co-Authored-By:` フッターを付ける**（D-14。本プロジェクトでは規約の既定を反転している）。`git add -A` / `git add .` は使わず、ファイル名を明示してステージングする。

**`Co-Authored-By` の形式（2026-07-28 訂正）:**

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

- 一般形は `Co-Authored-By: Claude モデル名 <noreply@anthropic.com>`。**モデル名は実際に作業した Claude のもの**を書く（固定文字列ではない）。
- **モデル名に山括弧（`< >`）を付けない。** git の trailer 慣行では山括弧は**メールアドレスにのみ**使う。旧記述 `Co-Authored-By: Claude <モデル名> <noreply@anthropic.com>` は山括弧が 2 組ある誤った表記だった（design.md D-14 の 3 も同時に訂正済み）。

**コミットに含まれるドキュメントの版について:** 本章の 6 コミットは**すべて Step 11 で一括作成する**（実装完了後にまとめてコミットする運用であり、各ステップの途中でコミットしない）。したがって**コミット 3 に含まれる `design.md` / `impl.md` は「実装完了時点の版」**である — 実装着手前の upfront 版ではなく、レビュー指摘の反映と D-12〜D-14 の転記、および「5. 実装状況」の更新まで入った状態が最初のコミットに乗る。

### コミット 1: `.gitignore`（意味単位: 設定）

**含めるファイル:** `.gitignore`

```
add gitignore for build artifacts and Xcode user data

XcodeGen / xcodebuild の生成物とユーザー固有ファイルを Git 追跡から除外する。
- Shippitsu.xcodeproj と Generated/Info.plist は project.yml から再生成できるため追跡しない
- DerivedData/ と .build/ はビルド中間生成物
- xcuserdata/ は Xcode のユーザー固有設定
```

最初に置く理由: 以降のコミットで生成物を誤ってステージングする事故を構造的に防ぐため。

### コミット 2: 開発規約（スキル設定）（意味単位: 設定）

**含めるファイル:** `.claude/skills/` 配下の全ファイル（6 スキル × `SKILL.md` + `references/rules.md` = 12 ファイル）

```
add project-local Claude Code skill definitions

本リポジトリで従う開発規約（スキル定義）を追加。
- design-impl-docs / implement-review-loop / subagent-orchestration: ドキュメント運用と
  実装ループ・サブエージェント委譲の規約
- code-review-agent / commit-workflow / function-signature-typing: レビュー・コミット・
  型注釈の規約
- commit-workflow はオリジナルから 1 点変更し、本プロジェクトでは
  Co-Authored-By フッターを付ける方針とした（design.md D-14）
```

`.gitignore` の次に置く理由: 以降のコミット（ドキュメント・実装）が従っている規約そのものであり、先に履歴へ入れておくとレビュー時に前提を先に読める。

> **なぜこのコミットが必要か:** D-12 / D-15 により `main` にはファイルを置かない（空コミット 1 個のみ）ため、`.claude/` を「初期コミットとして `main` へ置く」経路が存在しない。追跡しないままにすると Step 11 の完了確認「`git status` がクリーン」を満たせず、PR も「完全な差分」にならない。

### コミット 3: ドキュメント（意味単位: ドキュメント）

**含めるファイル:** `docs/scaffold/design.md`、`docs/scaffold/impl.md`

**版:** 実装完了時点の版（本章冒頭の「コミットに含まれるドキュメントの版について」を参照）。

```
add scaffold design and implementation documents

スキャフォールド構築タスクの仕様書と実装詳細を追加。
- design.md: 要件・仕様と決定事項 D-1〜D-14（技術選定、プロジェクト構成方式、
  アプリ名 / Bundle ID、対応 OS、Lint / Formatter、完成定義、テスト、Git 運用、
  main ブランチと PR の方針、GitHub リポジトリ、コミット作成者情報）
- impl.md: ディレクトリ構成、技術的判断、実装ステップ、コミット分割案、実装状況
```

### コミット 4: プロジェクト定義（意味単位: 設定）

**含めるファイル:** `project.yml`

```
add XcodeGen project definition for Shippitsu app

project.yml から .xcodeproj を生成する XcodeGen 構成を追加。
- アプリ本体 Shippitsu とテスト ShippitsuTests の 2 ターゲット構成
- Info.plist は YAML にインライン記述し Generated/Info.plist へ生成する
- 表示名は「執筆」、内部ターゲット名は Shippitsu、Bundle ID は com.ayatsukiaya.shippitsu
- deployment target は macOS 26.0、Swift 6 言語モード
- テストターゲットは GENERATE_INFOPLIST_FILE を有効にし Info.plist を自動生成させる
```

### コミット 5: アプリ本体の実装（意味単位: UI 実装）

**含めるファイル:** `Sources/Shippitsu/AppDelegate.swift`、`MainMenu.swift`、`MainWindow.swift`

```
implement AppKit entry point with empty main window

AppKit の最小アプリを実装。Storyboard / XIB は使わずコードで構築する。
- @main を付けた AppDelegate をエントリポイントとする
- 起動時に空のウィンドウを 1 枚表示し、タイトルにアプリ表示名を設定する
- アプリメニューに終了項目（Cmd+Q）を追加する
- 最後のウィンドウを閉じたらアプリを終了する
```

### コミット 6: テスト（意味単位: テスト）

**含めるファイル:** `Tests/ShippitsuTests/ScaffoldPlaceholderTests.swift`

```
add placeholder test for the test target

テスト基盤が動作することを確認するためのプレースホルダを 1 件追加。
Swift Testing を採用し、@testable import でアプリモジュールを読み込むことで
テストホストの結線まで検証する。意味のあるテストケースは後続タスクで追加する。
```

**分割方針の補足:** コミット 4（`project.yml`）とコミット 5・6（ソース）を分けた結果、コミット 4 単体ではビルドが通らない（ソースディレクトリが空）。`commit-workflow` 規約は「各コミットが単体でビルドできること」を要求しておらず、意味単位（設定 / 実装 / テスト）の分離を優先する規約であるため、この分割を採る。ブランチ全体をマージ単位として扱う運用（D-8 / D-12 — `main` は空で、PR 単位でレビューする）とも整合する。

---

## 5. 実装状況

**項目 1〜14 完了（S-5 の受け入れ基準 4 項目すべて充足）/ 項目 15 は残り 3 手順**（2026-08-24 時点）。

- **S-5 の受け入れ基準 4 項目はすべて満たしている。**
  1. ビルド成功 ✅（`** BUILD SUCCEEDED **` / 警告 0 件）
  2. **ウィンドウ 1 枚表示 + ⌘Q で終了 ✅（2026-08-24、ユーザーによる実機の目視確認で充足を確認）**
  3. `xcodebuild test` 成功 ✅（`scaffoldPlaceholder` 1 件が緑）
  4. SwiftLint 警告 0 件・swift-format 整形差分 0 件 ✅（ルール無効化 0 件）
- **基準 2 の確認経緯:** 実装エージェントの実行環境には画面キャプチャ・GUI オートメーションの権限が無く、`pgrep` / `pkill` によるプロセスの起動・終了の機械確認までしか行えなかった（`osascript` は `-25211`、`screencapture` は画面収録権限なしで失敗）。**そのため基準 2 はユーザーの実機確認に委ねていたが、その確認の過程で下記の不具合が発覚し、修正後に改めてユーザーが目視して充足を確認した。**
- **【2026-08-24】ユーザーの実機目視確認により、6-1 のチェックリストのうち 5 項目（ウィンドウ 1 枚表示 / タイトル「執筆」/ メニューバーの「執筆」と終了項目 / ⌘Q での終了 / ウィンドウを閉じるとアプリごと終了）が確認済みとなった。** 残る「Dock のアイコン名が『執筆』」は未確認だが、**S-5 の受け入れ基準には含まれない補助項目**である（6-1 の注意書きを参照）。`CFBundleName` / `CFBundleDisplayName` = 執筆 は Step 9 で機械確認済みのため、実害は想定していない。

**⚠【追記 / 2026-08-09】実機動作確認で S-3.1 / S-3.3 の不具合が発覚し、修正した。** 上記「項目 14 一部完了」に基づきユーザーが実機で `open` したところ、**ウィンドウが 1 枚も開かず、メニューバーから終了もできない**（Dock からの終了のみ可能）という不具合が判明した。原因は `@main` のみでは nib を使わない構成でデリゲートが生成されないことで、`AppDelegate.applicationDidFinishLaunching` が一度も呼ばれていなかった。`AppDelegate` に明示的な `static func main()` を実装して解消した（詳細・後続タスクへの教訓は 2-2 末尾の実績注記を参照）。修正後に Step 5〜8 の整形・lint・ビルド・テストをすべて再実行し、いずれも成功を再確認した。あわせて `applicationDidFinishLaunching` 内に一時的なマーカーファイル書き込みを仕込んで実機で修正前後の呼び出し有無を直接確認した（確認後にコードは削除済み）。~~**S-5 の受け入れ基準 2 は、この修正により「ウィンドウが生成されメニューが構築される」という前提の不具合は解消されたが、実際の描画結果（タイトル文字列・メニューバーの見た目・Cmd+Q の実挙動）はこの環境からは引き続き機械的に確認できないため、依然としてユーザーの目視確認待ちのままとする。**~~ → **【2026-08-24 更新】ユーザーの実機目視確認が完了し、S-5 の受け入れ基準 2 は充足済みとなった**（本節冒頭を参照）。

**この不具合から得た教訓（design.md S-5 にも注記として記録済み）:** 本不具合は**コードレビュー 5 レンズとドキュメントレビュー 3 巡をすべてすり抜けた。** `@main` の記述自体は文法上正しく、ビルド・テスト・SwiftLint・swift-format のすべてが通っていたためである。**「起動経路が nib の有無に依存する」という AppKit 固有の暗黙の前提はコード読解では検出できない。実機確認でしか見つからない類の問題が存在する**ことを、後続タスクでも前提とする（UI を持つ変更は機械的検証がすべて緑でも目視確認が済むまで完成と判定しない）。

項目 15（Git 操作）は design.md の未決事項 11〜13（→ D-12 / D-13 / D-14）に加え、**未決事項 15 にも判断が出て D-15 として確定した**ため、**PR 作成まで含めてブロックは解除済み**（Step 11 参照）。担当は一貫して**コミットエージェント**であり、実装エージェントは着手しない。

| # | 項目 | 対応する要件・決定 | 状況 |
|---|------|-------------------|------|
| 1 | `brew install xcodegen` / `brew install swiftlint` | D-11 | 完了（xcodegen 2.46.0 / swiftlint 0.65.0） |
| 2 | `.gitignore` の作成 | D-8 | 完了 |
| 3 | `project.yml` の作成（2 ターゲット / Info.plist インライン / D-3 の名前割り当て） | S-1 / D-2 / D-3 / D-4 / D-7 | 完了（`ShippitsuTests` に `GENERATE_INFOPLIST_FILE: YES` を追加。詳細は本節末尾の補足） |
| 4 | `AppDelegate.swift`（@main / ウィンドウ表示 / 終了ポリシー / 表示名の解決） | S-3.1 / S-3.2 / S-3.4 / D-1 / D-3 | 完了（表示名解決を `nonEmptyInfoString` ヘルパーに分離。**【2026-08-09 追記】実機検証で `applicationDidFinishLaunching` が未発火の不具合が発覚し、明示的な `static func main()` を追加して解消。**理由は本節末尾の補足および 2-2 末尾の実績注記） |
| 5 | `MainMenu.swift`（メニューバー / Cmd+Q） | S-3.3 | 完了 |
| 6 | `MainWindow.swift`（空のウィンドウ 1 枚） | S-3.1 / S-4 / D-6 | 完了 |
| 7 | `ScaffoldPlaceholderTests.swift`（Swift Testing のプレースホルダ 1 件） | FR-6 / D-9 | 完了 |
| 8 | `swift-format` 整形差分 0 件 | S-5 基準 4 / D-5 / D-10 | 完了（`xcrun swift-format lint --strict --recursive Sources Tests` 終了コード 0） |
| 9 | `swiftlint --strict` 警告 0 件 | S-5 基準 4 / D-5 / D-10 | 完了（`swiftlint lint --strict Sources Tests` で 0 violations。ルール無効化なし） |
| 10 | `xcodegen generate` の成功確認 | S-2 | 完了（`Shippitsu.xcodeproj` / `Generated/Info.plist` 生成、2 ターゲット + `Shippitsu` スキーム確認、`TEST_HOST` / `BUNDLE_LOADER` は自動設定を確認） |
| 11 | `xcodebuild build` の成功確認 | S-5 基準 1 / FR-1 | 完了（`** BUILD SUCCEEDED **`、警告 0 件、`Shippitsu.app` 生成確認） |
| 12 | `xcodebuild test` の成功確認 | S-5 基準 3 / D-9 | 完了（`** TEST SUCCEEDED **`、`scaffoldPlaceholder` 1 件実行・成功） |
| 13 | Bundle ID / 表示名の機械確認 | FR-3 / D-3 | 完了（`CFBundleIdentifier`=`com.ayatsukiaya.shippitsu`、`CFBundleName`/`CFBundleDisplayName`=`執筆`、`CFBundleExecutable`=`Shippitsu` を確認） |
| 14 | S-3 の目視確認チェックリスト消化 | S-3 / 6-1 | **完了（2026-08-24）**。実装エージェント側は `pgrep -x Shippitsu` によるプロセス起動・終了の機械確認までしか行えなかった（画面キャプチャ・GUI オートメーション権限が無く、`osascript` は `-25211`、`screencapture` は画面収録権限なしで失敗）。**【2026-08-09】実機確認でウィンドウが 1 枚も開かず終了項目も無い不具合を検出・修正（2-2 参照）。**修正後 `lsappinfo` で `type="Foreground"` を確認し、`applicationDidFinishLaunching` 内の一時マーカーで発火自体を確認した（確認後にコードは削除済み）。**【2026-08-24】ユーザーの実機目視確認により 6-1 のチェックリスト 5 項目（ウィンドウ 1 枚 / タイトル「執筆」/ メニューバーの「執筆」と終了項目 / ⌘Q / 閉じるとアプリごと終了）が確認済みとなり、S-5 の受け入れ基準 2 の充足を確定した。**（「Dock のアイコン名」のみ未確認だが S-5 の基準外の補助項目） |
| 15 | `git init` + `user.email` のローカル設定 + `feat/init-scaffold` + **6 コミット** + remote 追加 + push + **`main` の空コミット + push** + PR 作成（コミットエージェント担当） | D-8 / D-12 / D-13 / D-14 / **D-15** | **進行中**（実装エージェントの担当外）。**Step 11 の 1〜5（`git init` 〜 `feat/init-scaffold` の 6 コミット作成・push）は完了。残るは 6〜8（`main` の空コミット作成 → push → PR 作成）で、D-15 の決定によりブロックは解除済み。** 手順は Step 11 / 4 章 |

（項目の並びは 3 章のステップ順に対応する。項目 4〜7 = Step 4、8〜9 = Step 5、10 = Step 6、11 = Step 7、12 = Step 8、13 = Step 9、14 = Step 10、15 = Step 11。）

**実装時に判明した補足（2-1 / 2-2 に対する実態の差分。本節以外は変更していない）:**

- **`ShippitsuTests` に `GENERATE_INFOPLIST_FILE: YES` の追加が必要だった。** 2-1 の骨子どおりに `project.yml` を作成し Step 8（`xcodebuild test`）を実行したところ、`Cannot code sign because the target does not have an Info.plist file` でビルド失敗した。`ShippitsuTests` ターゲットには `info:` ブロックも `GENERATE_INFOPLIST_FILE` も設定されておらず、Info.plist が存在しないことが原因。`ShippitsuTests.settings.base` に `GENERATE_INFOPLIST_FILE: YES` を追加（Xcode に自動生成させる）して解決した。手書き Info.plist を増やさない 2-1 の方針（「Info.plist を手で編集しない」）とは矛盾しない対処である。
- **`AppDelegate.resolveDisplayName()` の実装が骨子と異なる。** 2-2 の骨子は `if let ... , !name.isEmpty { ... }` を 2 回書く形だったが、`swift-format`（複数行条件で `{` を次行に送る）と SwiftLint の `opening_brace` ルール（`{` は宣言と同じ行を要求）が衝突し、両者を同時に満たせなかった。ルール無効化ではなくコード側を直す方針（D-10 / 6-2）に従い、判定を `nonEmptyInfoString(_:forKey:)` という private static ヘルパーに切り出して 1 行に収める形に書き換えた。フォールバック順序（`CFBundleDisplayName` → `CFBundleName` → リテラル）は変更していない。

**`AppInfo.swift` について:** 初版では独立ファイルとして計上していたが、2-2 の分割方針の見直しにより作らない（表示名の解決は項目 4 に含む）。

**SwiftLint ルール無効化の記録:** 現時点で無効化ゼロ（6-2 の表を参照）。

---

## 6. 既知の制約・TODO

### 6-1. S-3 の振る舞いのうち、S-5 の受け入れ基準で機械的に検証されない項目

design.md S-3 は 4 つの振る舞いを規定しているが、S-5 の受け入れ基準 4 項目（ビルド成功 / 起動して Cmd+Q で終了 / `xcodebuild test` 成功 / lint 通過）では以下が機械的に検証されない。

| S-3 / FR の項目 | 検証手段 | 分類 |
|----------------|---------|------|
| Bundle ID が `com.ayatsukiaya.shippitsu` である（FR-3 / D-3） | **機械確認可能** — Step 9 の `plutil -extract` | 実装エージェントが確認 |
| 表示名が「執筆」である（FR-3 / D-3） | **機械確認可能** — Step 9 の `plutil -extract`（Info.plist の値まで） | 実装エージェントが確認 |
| ウィンドウにアプリ名がタイトル表示される（S-3.2） | 実際の描画結果は目視 | **目視確認** |
| メニューバーにアプリ名が出る（S-3.3） | macOS がどのキーを使って差し替えるかは実行時に決まるため目視 | **目視確認** |
| ウィンドウを閉じるとアプリが終了する（S-3.4） | 実装（`applicationShouldTerminateAfterLastWindowClosed` が `true` を返す）はコード上で確認できるが、実挙動は目視 | **目視確認** |
| Dock に正しく表示される（FR-3） | 目視 | **目視確認** |

**方針:**

1. **機械確認できるものは機械確認に寄せる。** Bundle ID・`CFBundleName` / `CFBundleDisplayName` は `plutil` で完全に検証できるため、Step 9 として実装ステップに組み込んだ（「目視でしか確認できない」を減らす）。
2. **残りは「目視確認チェックリスト」として実装ステップ Step 10 に組み込む。** 実装エージェントは `open` でアプリを起動し、自分で確認できる範囲を確認する。
3. **確認しきれない項目はユーザーへの動作確認依頼として完了報告に添える。** `implement-review-loop` の「ユーザーへの動作確認依頼は UI・仕様確認要の場合に添える」に該当する（本タスクは UI を持つため該当する）。

**目視確認チェックリスト（ユーザーに提示する文面の雛形）— 【2026-08-24 更新】ユーザーの実機確認結果を反映:**

- [x] アプリを起動すると、ウィンドウが **1 枚だけ** 表示される（**2026-08-24 ユーザー確認済み**）
- [x] ウィンドウのタイトルバーに **「執筆」** と表示されている（**2026-08-24 ユーザー確認済み**）
- [x] 画面上部のメニューバー左端（Apple マークの右）に **「執筆」** と表示されている（**2026-08-24 ユーザー確認済み**）
- [x] メニュー「執筆」を開くと **「執筆を終了」** があり、右側に **⌘Q** と表示されている（**2026-08-24 ユーザー確認済み**）
- [x] **⌘Q** を押すとアプリが終了する（**2026-08-24 ユーザー確認済み**）
- [x] ウィンドウの赤い閉じるボタンを押すと **アプリごと終了する**（Dock に残らない）（**2026-08-24 ユーザー確認済み**）
- [ ] 起動中、Dock のアイコン名が **「執筆」** になっている（**未確認**。S-5 の受け入れ基準には含まれない補助項目であり、完成判定を妨げない。`CFBundleName` / `CFBundleDisplayName` = 執筆 は Step 9 で機械確認済み）

> **【2026-08-24】上記のうち 6 項目がユーザーの実機目視確認で満たされ、design.md S-5 の受け入れ基準 2（ウィンドウ 1 枚表示 / ⌘Q で終了）の充足が確定した。** なお、この確認に至る過程で **`@main` のみではデリゲートが生成されず `applicationDidFinishLaunching` が一度も呼ばれない**という不具合が発覚しており（2026-08-09 / 2-2 末尾および 5 章参照）、**本チェックリストがそれを検出した唯一の手段だった。** ビルド・テスト・SwiftLint・swift-format はすべて通り、コードレビュー 5 レンズとドキュメントレビュー 3 巡もすり抜けていた。**「機械的検証がすべて緑でも目視確認でしか見つからない問題がある」ことの実例として、本チェックリストは後続タスクでも維持する。**

**注意:** このチェックリストは S-5 の受け入れ基準を**拡張するものではない**。S-5 の 4 項目が「完成」の判定基準であり、本チェックリストは S-3 の記述が実際に満たされているかを補助的に確認するもの。チェックリストの結果を受けて受け入れ基準を変更したい場合は、design.md 側の改訂（ユーザー判断）が必要。

**TODO（後続タスク）:** UI テスト（`XCUITest`）を導入すればウィンドウタイトルとメニュー項目は自動検証できる。本タスクではテストターゲットを 1 つに限定しており（D-7 / D-9 のスコープ）、UI テストターゲットの追加は行わない。

### 6-2. SwiftLint の警告を無効化する際の判断主体

D-10 は「実際に警告が出て、それが本質的でないと判断された場合に限り無効化し、無効化したルールと理由を impl.md に記録する」と定めているが、**誰がその判断を下すか**が未定である。無効化が積み重なると lint が形骸化し、D-5 でユーザーが lint を導入した意図（ユーザー自身のコードレビューの補助）が失われる。

**方針:**

1. **まずコードを直す。無効化は最終手段。** 警告が出たら、原則としてコード側を規約に合わせる。無効化を先に検討しない。
2. **実装エージェントは「恒久的な無効化」を単独で決定しない。** ただしループを止めないため、暫定対応として無効化してよい。その代わり以下を必須とする。
3. **記録なしの無効化は禁止。** 無効化したら**必ず**下記の表に追記する。記録されていない `swiftlint:disable` コメントや `.swiftlint.yml` のエントリを見つけたら、それは規約違反として差し戻す。
4. **無効化のスコープは最小に。** 原則として該当箇所に `// swiftlint:disable:next <rule>` を書き、直上に理由をコメントで添える。プロジェクト全体で不適切と判断したルールに限り `.swiftlint.yml` の `disabled_rules` を使う（D-10 が禁じているのは**事前の**無効化であり、警告発生後の対応としての作成は禁じられていない）。
5. **ユーザーの追認をもって確定とする。** 実装エージェントの判断は暫定であり、`implement-review-loop` のレビューフェーズおよび完了報告で、本表をユーザーに提示して追認を得る。追認されなければコード側の修正に戻す。
6. **件数が増えたらエスカレーションする。** 1 タスク内で無効化が複数件（目安として 3 件以上）に達した場合、個別判断ではなくルールセット方針の問題である可能性が高い。その時点でループを止め、design.md の未決事項としてユーザーに判断を仰ぐ。

**SwiftLint ルール無効化記録:**

| ルール名 | 無効化スコープ | 出た警告の内容 | 本質的でないと判断した理由 | 判断者 | ユーザー追認 |
|---------|--------------|--------------|------------------------|--------|------------|
| （現時点で無効化なし） | — | — | — | — | — |

**【実績 / 2026-07-28】本タスクで無効化したルールは 0 件。** 上の表が空のままであることが正しい状態である（記録漏れではない）。`swiftlint lint --strict Sources Tests` は 0 violations で通っている。

**【実績 / 2026-07-28】ただし「ツール間の衝突」は下記の予見とは別の形で実際に発生した。** 予見していたのは `trailing_comma` を軸にした衝突だったが、実際に起きたのは **`AppDelegate.resolveDisplayName()` の複数行 `if let` 条件における `swift-format`（`{` を次行へ送る）と SwiftLint の `opening_brace`（`{` は宣言と同じ行）の衝突**で、両方を同時に満たせない状態だった。**対処は上記手順 1「まずコードを直す」に従い、判定を `nonEmptyInfoString(_:forKey:)` ヘルパーへ切り出して条件を 1 行に収める書き換え**とし、**ルールの無効化は行っていない**（詳細は 2-2 の骨子への注記と「5. 実装状況」の補足）。**教訓: 衝突は `trailing_comma` に限らない。「複数行にまたがる構文で `{` の位置が争点になる箇所」全般で起きうる**ため、後続タスクでも先回りの無効化ではなく「1 行に収まる形へ書き換えられないか」を先に検討する。

**予見されるリスク（事前の無効化はしない）:** `swift-format` の既定は複数要素のコレクションリテラルに末尾カンマを付ける方向で、SwiftLint の `trailing_comma` 既定は末尾カンマを警告する方向であるため、両者が衝突して「どちらかを直すともう一方が怒る」デッドロックになり得る。**先回りしての無効化は D-10 が禁じているため行わない。** 実際に発生した場合は、その時点で**本質的な警告かどうかを改めて判断**し、上記 1〜6 の手順に従って対処する（本節に先んじて「本質的でない」と結論づけない — D-10 は「実際に警告が出て、それが本質的でないと判断された場合に限り」という順序を定めている）。なお本タスクのコード量では複数行コレクションリテラルがほぼ登場しないため、発生しない可能性が高い。

### 6-3. Git / GitHub まわりの決定内容へのポインタ（**すべて解決済み**）

かつては「`main` ブランチをどう用意するかが未定（ユーザー判断待ち）」という保留の節だったが、**2026-07-28 に D-12 / D-13 / D-14 が、2026-08-24 に D-15 が確定し、Git / GitHub まわりの未決事項はすべて解消した。** 以下は決定内容へのポインタである（内容の正は design.md 側）。

> ✅ **PR 作成のブロックも解除済み（2026-08-24 / design.md D-15）。** かつて「D-12 の『`main` は空のまま』と『base = `main` の PR を出す』は技術的に両立しない（コミットが 0 件の `main` は ref として存在しないため `gh pr create --base main` が必ず失敗する）」という未決事項 15 が残っていたが、**`main` に空コミットを 1 個置く**（＝ ファイルは置かない）という判断が出て解決した。

| 論点 | 決定 | 内容の要旨 |
|------|------|-----------|
| `main` ブランチの用意方法 / PR の差分 | **D-12** + **D-15** | `main` に**プロジェクトのファイルを置かない**。ファイルを含むコミットはすべて `feat/init-scaffold` に乗せ、PR の差分にプロジェクト全体（`.claude/` / `docs/` を含む）を出す（D-12）。**`main` には PR の base とするための空コミットを 1 個だけ置く（D-15。D-12 の「コミットを一切置かない」という旧文言を改めたもの）** |
| GitHub リポジトリ | **D-13** | 作成済みの `https://github.com/ayatsuki-meowmeow/shippitsu`（**public**）を使う。`gh repo create` は実行せず remote 追加のみ |
| コミット作成者情報 / `Co-Authored-By` | **D-14** | `user.name` は `~/.gitconfig.local` の既存設定を継承（追加設定なし）。`user.email` のみローカル設定で GitHub の noreply アドレス。`Co-Authored-By` フッターは**付ける** |

**旧・保留内容の記録（経緯）:** D-8 は「`feat/init-scaffold` ブランチを作成し作業する」までしか定めておらず、`main` の用意方法を規定していなかった。impl.md 側で既定を決めることはせず（規約: 「design.md から答えが出ない仕様レベルの疑問は、本ドキュメントで補完せず design.md の未決事項へ差し戻す」）、design.md の**未決事項 11** として差し戻したうえで、判断が出るまで Step 11 に進まない運用を採っていた。**その差し戻しが機能し、判断が返ってきたのが本節の解決である。**

**本節の解決に伴う影響:**

- **Step 11 の停止ブロックをすべて解除した**（コマンド列は D-12〜D-15 を反映。`main` の空コミット作成 → push → PR 作成の 3 手順を追加）。
- **4 章のコミット分割案を確定した**（`main` にファイルを置かないため `.claude/skills/` もコミット対象になり、5 → 6 コミットに変更）。**コミット分割は D-15 の影響を受けない**（空コミットは `feat/init-scaffold` の 6 コミットとは別枠）。

### 6-4. その他の制約・TODO

| 項目 | 内容 |
|------|------|
| 署名・公証・サンドボックス | `CODE_SIGN_IDENTITY: "-"`（ad-hoc）のみ。Developer ID 署名・公証・App Store 配布（サンドボックス entitlements）は未対応。NFR-4 のとおり道は塞いでいない（`DEVELOPMENT_TEAM` 未設定・XcodeGen で後から追加可能）が、実施は後続タスク |
| アプリアイコン | 未設定（design.md スコープ外）。Dock / Finder では既定のアイコンが表示される |
| `Generated/Info.plist` は生成物 | 手で編集しても `xcodegen generate` で上書きされる。Info.plist を変えたいときは必ず `project.yml` の `info.properties` を編集する |
| ウィンドウ内は空 | D-6 / S-4 により意図的に空。`NSTextView` の配置・縦書き設定・IME 検証は後続タスク（NFR-6：リバート前提の先取り実装をしない） |
| Swift 6 言語モードの影響 | **本タスク: 解決済み（2026-07-28）。** `@main` + `NSApplicationDelegate` の MainActor 隔離は `@MainActor` の明示のみで解決し、`nonisolated` も `SWIFT_VERSION: "5"` への引き下げも不要だった（`SWIFT_VERSION: "6"` を据え置き）。**後続タスク:** strict concurrency により、非 `@MainActor` の文脈から AppKit を触るとコンパイルエラーになる。これは意図した制約（早期に是正できる）。なお**引き下げが必要になった場合は design.md の未決事項へ差し戻す**（Claude が単独で決めない / 2-1） |
| `ENABLE_TESTABILITY` への依存 | `@testable import Shippitsu` はアプリターゲットの `ENABLE_TESTABILITY` に依存する（Debug 既定 YES）。テストは Debug 構成で実行する。Release でのテスト実行は本タスクの範囲外（2-3 参照） |
| `TEST_HOST` の自動設定 | **解決済み（2026-07-28 実測）。** XcodeGen がアプリターゲットへの依存から `TEST_HOST` / `BUNDLE_LOADER` を自動設定するため、`project.yml` への手動追加は不要だった（2-1 / Step 6） |
| ビルド成果物のパス固定 | `-derivedDataPath DerivedData` を全コマンドで一貫して付ける。付け忘れると成果物が既定の DerivedData に出て、起動コマンドや `plutil` 確認のパスがずれる |

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-08-25 | **CI 構築タスク（`docs/ci/`）に伴う 3 章の早見表の更新のみ。本タスク（scaffold）の仕様・実装・実装状況は一切変更していない。** **[3 章]** 「前提ツールの導入」を `brew install xcodegen swiftlint` から **`brew install mint` + `mint bootstrap --link`** に置き換えた。理由は `docs/ci/design.md` **D-2**（SwiftLint / XcodeGen のバージョンを `Mintfile` で固定する）— 旧手順はバージョンが固定されず、環境を作り直すたびに別バージョンが入るため、NFR-5（再現性のあるセットアップ手順）が構造的に崩れていた。あわせて **PATH の前提**（`mint bootstrap --link` は `~/.mint/bin` にリンクするだけで PATH は通さないため、`swiftlint` / `xcodegen` を含むコマンドは `$HOME/.mint/bin` に PATH が通った状態で実行する）を注記した。**固定バージョンの正は `Mintfile`**（SwiftLint 0.65.0 / XcodeGen 2.46.0 = 従来ローカルで使っていたものと同一）であり、**コマンド文字列そのものは変更していない**ため、Step 5〜8 の記述と受け入れ基準 S-5 への影響は無い |
| 2026-08-24 | **design.md の D-15（`main` に空コミットを 1 個置いて PR の base にする）の確定と、ユーザーによる実機目視確認の完了を反映。** **[Step 11]** 未決事項 15 による PR 作成のブロック注記を**解除**し、前提テーブルに **D-15** を追加。コマンド列に **6.「`main` を PR の base にするための空コミット作成」・7.「`main` の push」・8.「PR 作成」**の 3 手順を追加した（1〜5 は実行済みと明記）。**空コミットは `git switch --orphan` を使わず、`git hash-object -t tree /dev/null` → `git commit-tree` → `git branch main <sha>` の手順で作業ツリー・インデックスに一切触れずに作る**方式とした（`git switch --orphan` は追跡ファイルを作業ツリーから削除する副作用があり、`feat/init-scaffold` 側の未コミット変更に影響しうるため）。空コミットのメッセージ案（英語サマリ + 日本語詳細 + `Co-Authored-By` / D-14）も記載。**完了確認を D-15 に合わせて更新** — 旧「`git branch --list main` が空を返すこと」は無効化し、**`git rev-list --count main` が `1`** ・ **`git show --stat main` がファイルを 1 つも表示しない**（＝ `main` にファイルが乗っていない証拠）に置き換えた。末尾の警告注記も「`main` に置いてよいのは D-15 の空コミット 1 個だけ」に改めた。**[5. 実装状況]** 冒頭を**「項目 1〜14 完了（S-5 の受け入れ基準 4 項目すべて充足）/ 項目 15 は残り 3 手順」**に更新。**S-5 の基準 2（ウィンドウ 1 枚表示 / ⌘Q で終了）はユーザーの実機目視確認により 2026-08-24 に充足を確認**したため「目視確認待ち」の記述を打ち消し線付きで無効化し、項目 14 を**完了**に、項目 15 を**進行中（1〜5 完了 / 6〜8 が残り）**に更新した。**[6-1]** 目視確認チェックリストの 6 項目（ウィンドウ 1 枚 / タイトル「執筆」/ メニューバーの「執筆」/ 終了項目と ⌘Q 表示 / ⌘Q での終了 / 閉じるとアプリごと終了）を**確認済み**に更新。「Dock のアイコン名」のみ未確認だが **S-5 の基準外の補助項目**であり完成判定を妨げない旨を明記。**[6-3]** 「PR 作成のみ未決」→**「すべて解決済み」**に改め、D-12 の要旨を D-15 と併記する形に更新。**[4 章]** 前提を D-12 / D-15 併記に改め、**6 コミット作成後に発生した変更（2026-08-09 の不具合修正・2026-08-24 のドキュメント更新）が未コミットで残っていないかを PR 作成前に確認する**旨の指示を追加した（git の状態は本ドキュメントからは参照していないため断定していない）。**[教訓の記録]** 2026-08-09 の不具合が**コードレビュー 5 レンズとドキュメントレビュー 3 巡をすべてすり抜けた**こと、**機械的検証（ビルド・テスト・lint）がすべて緑でも実機確認でしか見つからない類の問題があること**を 5 章と 6-1 に記録した（design.md 側は S-5 の注記と変更履歴に記録）。**冒頭の参照を D-1〜D-14 → D-1〜D-15 に、環境表の Git 行を「初期化済み・6 コミット push 済み」に更新。2 章の技術的判断と項目 1〜13 の完了内容は変更していない。** |
| 2026-07-28 | **3 巡目のドキュメントレビュー指摘（should-fix 2 件 / nit 3 件）に対応。** **[should-fix 1]** Step 11 の完了確認「`git log main` がコミットを 1 件も返さないこと」は成立しないため（コミットが 0 件の `main` は ref として存在せず、`git log main` は 0 件ではなく `fatal: ambiguous argument 'main': unknown revision` で**エラー終了する**）、**`git branch --list main` が空を返すこと**（同等の確認として `git rev-parse --verify main` の失敗）へ置き換え、旧記述が成立しなかった旨を注記した。**[should-fix 2]** Step 11 の `gh pr create` に **`--title` / `--body` を追加**（省略するとインタラクティブモードに入りエディタが開いて、エージェント実行環境では手順が止まるため）。PR タイトル・本文の内容案（`commit-workflow` と同じ「1 行目は英語サマリ + 詳細は日本語」の 2 層構造）を併記し、`--fill` を使わず明示指定を推奨する理由も記載。**[nit 3]** `Co-Authored-By` の形式を **`Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`** の形（**モデル名には山括弧を付けない**。git の trailer 慣行では山括弧はメールアドレスにのみ使う）へ訂正し、4 章冒頭に独立した記述として整理した（design.md D-14 の 3 も同時訂正）。**[nit 4]** リポジトリ URL の表記揺れ（design.md D-13 は HTTPS / `git remote add origin` は SSH）について、**「表示用 URL は HTTPS、remote は SSH」**（git 操作は SSH 経由という前提による）という使い分けを Step 11 に明記。同じリポジトリを指すため実害はない。**[nit 5]** 「5. 実装状況」冒頭の要約を実態に合わせ、**「項目 1〜14 完了」→「項目 1〜13 完了 / 項目 14 は一部完了（ユーザーの目視確認待ち）」**に修正。**S-5 の受け入れ基準 2（ウィンドウ 1 枚表示 / Cmd+Q で終了）がユーザーの目視確認待ちであり、その確認が取れるまで S-5 の 4 項目すべてを満たしたとは言えない**旨を明示した（基準 1 / 3 / 4 は充足済み）。**[blocker 対応の反映]** design.md に**未決事項 15**（`main` にコミットが無いと `gh pr create --base main` が必ず失敗する — D-12 の「`main` は空のまま」と「base = `main` の PR」は技術的に両立しない）が起票されたことを受け、**Step 11 の PR 作成（コマンド列の 6）のみを「未決事項 15 の判断待ちでブロック中」に変更**した（`git init` 〜 push の 1〜5 は判断に依存せず実行してよい）。あわせて `git init -b main` のコメントを「main は作るが〜」から「**ブランチ名を予約するだけで、コミットが 0 件の間は main が ref として作られるわけではない**」へ訂正し、`main` への空コミットは**エージェントが独断で実行してはならない**旨を完了確認直後の警告に追記、6-3 を「解決済み」から「**PR 作成のみ未決**」へ改めた。**実装状況の事実（項目 1〜13 の完了内容）と 2 章の技術的判断は変更していない。** |
| 2026-07-28 | **2 巡目のドキュメントレビュー指摘（should-fix 3 件 / nit 6 件）と、design.md の未決事項 11〜13 の判断（D-12〜D-14）、および実装で判明した実態差分をまとめて反映。** **[should-fix 1]** D-12〜D-14 を Step 11 と 6-3 に反映し、**Step 11 の停止ブロックを解除**（コマンド列を確定版に差し替え。`git init -b main` → `user.email` のローカル設定 → `feat/init-scaffold` → 6 コミット → remote 追加 → push → PR 作成）。**[should-fix 2]** 4 章のコミット分割案を確定（`main` が空と確定したため `.claude/skills/` もコミット対象になり **5 → 6 コミット**に変更。全コミットが `feat/init-scaffold` に乗り、PR の差分にプロジェクト全体が現れる前提を冒頭に明記）。**[should-fix 3]** 2-1 の `SWIFT_VERSION: "5"` 引き下げを「本節に追記して完了報告で提示」から**「design.md の未決事項へ差し戻す class」へ格上げ**（SwiftLint ルール 1 個の無効化より軽い扱いだった非対称を是正）。あわせて**実際には `@MainActor` の明示のみでビルドが通り引き下げは不要だった**実績を追記。**[nit 4]** 2-4 末尾の参照先を「2-6 の予見リスク」→「**6-2 の予見されるリスク**」に修正（2 章の見出しは 2-1〜2-5 のみ）。**[nit 5]** 2-2 冒頭に「コード骨子は**整形前かつ `import` 等を省いた抜粋**であり、完全なファイル内容でも整形後の姿でもない」旨の注記を追加（骨子は 4 スペース、`swift-format` 既定は 2 スペース・100 桁）。**[nit 6]** 4 章に「6 コミットはすべて Step 11 で一括作成するため、コミット 3 に含まれる design.md / impl.md は**実装完了時点の版**である」旨を明記。**[nit 7]** `swiftlint lint --strict` に対象 `Sources Tests` を明示（2-4 / 3 章早見表 / Step 5 / 完了確認の 4 箇所。引数なしだと `DerivedData/` や `Shippitsu.xcodeproj/` まで走査するため）。**[nit 8]** 2-2 のファイル分割方針 3 項の文言矛盾を是正（「`AppDelegate` をライフサイクルだけに保てる」→「**ライフサイクル + 起動時に必要な小さなヘルパ（表示名の解決）**」。実際の線引きはウィンドウ / メニューの組み立て手順を持ち込まないこと）。**[nit 9]** 6-3 の「別途起票済み / 起票中」という両論併記を解消し、節全体を**「解決済み — D-12 / D-13 / D-14 へのポインタ」**に書き換え（旧・保留内容は経緯として保持）。**[実態差分]** (1) `ShippitsuTests` の `GENERATE_INFOPLIST_FILE: YES` を 2-1 の骨子に反映し、必要になった経緯（`Cannot code sign because the target does not have an Info.plist file`）と「Info.plist を手書きしない方針と矛盾しない」理由を補足。(2) `swift-format` と SwiftLint の `opening_brace` の衝突（複数行 `if let` 条件）を 2-2 の骨子注記と 6-2 に記録 — **6-2 が予見していた「ツール間の衝突」が `trailing_comma` とは別の形で実際に発生した事例**として、ルール無効化ではなくコード側の書き換えで解消した経緯と教訓を明記。(3) `TEST_HOST` / `BUNDLE_LOADER` は XcodeGen が自動設定する旨を実測結果として Step 6 / 2-1 / 6-4 に反映。(4) Swift 6 の MainActor 隔離は `@MainActor` 明示のみで解決した旨を 2-1 / 6-4 に反映。(5) **SwiftLint の無効化 0 件**であり 6-2 の記録表が空のままで正しい状態である旨を明記。あわせて冒頭の参照を D-1〜D-11 → **D-1〜D-14** に、環境表の Git 行をリモート情報（public / 作成済み）込みに、「5. 実装状況」の項目 15 を 6 コミット・ブロック解除済みの記述に更新。**「5. 実装状況」の事実そのものは書き換えていない。** |
| 2026-07-27 | ドキュメントレビュー指摘（should-fix 5 件 / nit 4 件）に対応。**(1)** アプリ本体を 4 → 3 ファイルに削減（`AppInfo.swift` を廃止し表示名の解決を `AppDelegate` の private static メソッドへ）。成立しない分割根拠（SwiftLint の行数ルール）を撤回し、残る根拠と NFR-6 との関係を 2-2 に明記。**(2)** `MainMenu` の実装骨子（`NSApp.mainMenu` の先頭 `NSMenuItem` の submenu がアプリメニューになる階層構造）と、表示名フォールバック（`CFBundleDisplayName` → `CFBundleName` → リテラル）を追加。**(3)** 6-3（`main` ブランチの扱い）を「design.md 未決事項 11 でユーザー判断待ち。判断まで Step 11 に進まない」という保留の形に変更（impl.md 側で既定を決めない）。**(4)** 3 章を NFR-5 の成果物と明記し、S-2 の 3 操作のコマンド早見表を 3 章冒頭に集約。**(5)** Step 10 の終了コマンドを `pkill -x Shippitsu` 第一候補に変更（`quit app "Shippitsu"` は `CFBundleName` 解決のため失敗しうる）。**(6)** Swift Testing の依存・実行時の挙動（`ENABLE_TESTABILITY` / `TEST_HOST` でウィンドウが開く / Swift 6 × `@main` の MainActor 隔離）を追記。**(7)** 6-2 の `trailing_comma` 衝突に関する記述を「発生時に改めて判断する」中立の形へ。**(8)** 2-5 を本タスクで効く 2 点に圧縮。**(9)** 整形 + lint を旧 Step 8 から Step 5（ソース作成直後）へ移動し、旧 Step 5〜7 を Step 6〜8 に繰り下げ（章内の参照・実装状況テーブルも更新） |
| 2026-07-27 | 初版作成。ディレクトリ構成・ファイル名を確定。技術的判断（Info.plist を YAML にインライン / `@main` + `NSApplicationDelegate` + コードによるメニュー構築 / テストは Swift Testing / lint・format は独立コマンド / Swift への型注釈規約の適用）を記録。実装ステップ 11 段階、コミット分割案 5 件を策定。実装状況は全項目「未着手」 |
