# ci — 実装詳細

`docs/ci/design.md` の仕様（S-1〜S-4 / D-1〜D-3）をどう実現するかを記す。**仕様・要件の正は `design.md`** であり、本ファイルはコマンド列・ジョブ構成・バージョン番号など実装詳細の管轄。

**前提とする決定:** `docs/ci/design.md` D-1（実行タイミング）/ D-2（Mint によるバージョン固定）/ D-3（必須チェック）、および `docs/scaffold/design.md` D-4 / D-5 / D-9 / D-10 / D-11 / D-13 / D-14（**scaffold 側の番号**。ci 側の D-1〜D-4 とは別系統）。

---

## 1. 構成

```
Mintfile                      # SwiftLint / XcodeGen のバージョン固定（新規）
.github/
└── workflows/
    └── ci.yml                # CI ワークフロー定義（新規）
docs/
├── ci/
│   ├── design.md             # 仕様・要件
│   └── impl.md               # 本ファイル
└── scaffold/
    └── impl.md               # 3 章の早見表を更新（既存ファイルの更新 / 3 章ステップ 5）
```

**`.gitignore` の変更は不要。** Mint の導入先は既定で `~/.mint`（ホーム配下）でありリポジトリ内に生成物を作らない。

### `Mintfile` の内容

```
realm/SwiftLint@0.65.0
yonaskolb/XcodeGen@2.46.0
```

書式は `owner/repo@version`。**リポジトリ名の大文字小文字を含めて上記のとおり**（`realm/SwiftLint` / `yonaskolb/XcodeGen`）。

### 固定するバージョン（2026-08-24 時点のスナップショット）

> **正は `Mintfile`（および `ci.yml` の `DEVELOPER_DIR`）であり、本表は作成時点の記録である**（design.md S-3）。バージョン更新 PR では `Mintfile` が正、本表は追随して更新する。

| ツール | バージョン | 固定方法 | ローカル実測 |
|--------|-----------|---------|-------------|
| Xcode | **26.6** (17F113) | `ci.yml` の `DEVELOPER_DIR` | 26.6（一致） |
| SwiftLint | **0.65.0** | `Mintfile` | 0.65.0（一致） |
| XcodeGen | **2.46.0** | `Mintfile` | 2.46.0（一致） |
| swift-format | 6.3.0 | Xcode 同梱のため Xcode の固定に連動 | 6.3.0（一致） |
| Mint 本体 | 固定しない | `brew install mint`（ローカル・CI とも） | 未インストール |

いずれも**ローカルの実測値に合わせた**。スキャフォールドが緑になった実績のあるバージョンであり、CI 導入時点で赤くなる要因を作らないため。**SwiftLint は 0.65.1 が既にリリースされているが、更新は独立した PR で行う**（design.md D-2）。

**Mint 本体を固定しない理由:** Mint は「固定されたバージョンを導入する道具」であって、成果物（lint 結果・ビルド結果）に影響しない。固定対象を増やすと管理コストだけが増える。

---

## 2. 技術的判断

### 2-1. Xcode の固定は `DEVELOPER_DIR` 環境変数で行う（`sudo xcode-select` は使わない）

ランナーには Xcode 26.0.1〜26.6 の 7 バージョンが `/Applications/Xcode_<version>.app` として導入済みで、`/Applications/Xcode.app` は既定（26.6）へのシンボリックリンクである。

`DEVELOPER_DIR=/Applications/Xcode_26.6.app/Contents/Developer` をジョブレベルの `env` に置く。`sudo xcode-select -s` ではなくこちらを選ぶ理由:

1. **sudo が不要** — マシン全体の状態を書き換えず、ジョブのプロセス環境に閉じる。
2. **固定バージョンが YAML の先頭に 1 箇所で現れる** — grep で見つけやすく、更新漏れが起きにくい。
3. `xcodebuild` / `xcrun` の両方がこの変数を参照するため、**`xcrun swift-format` も同じ Xcode のものが使われる**（swift-format のバージョン固定が Xcode の固定に連動する根拠）。

### 2-2. Mint は `bootstrap --link` して PATH を通す

**採用する形:**

```sh
brew install mint               # Mint 本体（ローカル・CI とも未導入）
mint bootstrap --link           # Mintfile 通りに導入し ~/.mint/bin へリンク
# PATH に $HOME/.mint/bin を通したうえで
swiftlint lint --strict Sources Tests
xcodegen generate
```

`mint run` 方式を採らない理由:

- 長形式（`mint run realm/SwiftLint@0.65.0 ...`）は**コマンド文字列にバージョンが現れ、`Mintfile` を唯一の情報源とする方針（design.md S-3）と衝突**する。
- 短縮形（`mint run swiftlint ...`）にはこの問題は無い。**Mint の README は「Mintfile があれば、複数バージョンが入っていても Mintfile で宣言されたバージョンを実行する」と明記**しており、バージョン取り違えの心配も無い。
- それでも `--link` 方式を選ぶのは、**コマンド文字列が既存の早見表（`docs/scaffold/impl.md` 3 章）と完全に同一**になり、FR-3（ローカルと CI のコマンド一致）を追加の抽象化なしに満たせるためである。**これが唯一かつ十分な採用理由。**

**PATH の通し方:**

| 環境 | 方法 |
|------|------|
| CI | `echo "$HOME/.mint/bin" >> "$GITHUB_PATH"`（`$GITHUB_PATH` は**次のステップ以降**に効くため、バージョン出力より前のステップで実行する） |
| ローカル | コマンド実行時に `PATH="$HOME/.mint/bin:$PATH"` を前置する（シェルの設定ファイルは書き換えない） |

**ローカルの brew 版との共存に注意（6 章参照）。**

### 2-3. `ci.yml` の骨格

```yaml
name: CI

on:
  pull_request:
    branches: [main]        # S-1: base が main の PR
  push:
    branches: [main]        # S-1: マージ後の main
  workflow_dispatch:        # S-1: 手動

permissions:
  contents: read            # ビルドと lint しかしないため最小権限

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true  # 連続 push で古い実行を残さない（NFR-3）

jobs:
  verify:                   # ← このジョブ名がそのまま必須チェックの context になる
    name: verify
    runs-on: macos-26       # S-3
    env:
      DEVELOPER_DIR: /Applications/Xcode_26.6.app/Contents/Developer
    steps: ...              # 2-4 のとおり
```

**⚠ ジョブ名は必須チェックの context そのものである。** GitHub の required status check が参照するのは**ジョブ名**（`jobs.<id>.name`、未指定なら job id）であってワークフロー名ではない。**`verify` を後から改名すると、ブランチ保護が「報告されないチェック」を待ち続けて全 PR がマージ不能になる。** 改名する場合はブランチ保護（実装ステップ 8）も同時に更新すること。

`cancel-in-progress: true` は `github.ref` でグループ化しているため、PR への連続 push では古い実行がキャンセルされ、`main` への push は別グループになる。

### 2-4. ジョブは単一・逐次（fail-fast）にする

**ジョブを分割しない理由:**

1. lint 側も SwiftLint を Mint 経由で使うため、**分割するとどちらのジョブでも Mint の導入・キャッシュ復元・`bootstrap` が必要**になり、ビルド時間の節約にならない。
2. macOS ランナーの起動コストが 2 回分かかる。
3. 必須チェック（D-3）に指定する context が 1 つで済み、ブランチ保護の設定が単純になる。

**ステップの並び（この表が step 列の正）:**

| # | ステップ | 備考 |
|---|---------|------|
| 1 | `actions/checkout` | |
| 2 | `actions/cache/restore`（`~/.mint`） | 2-5 |
| 3 | `brew install mint` | **ランナーに Mint は未導入**（design.md「前提の確認結果」） |
| 4 | `mint bootstrap --link` | キャッシュヒット時は高速 |
| 5 | `echo "$HOME/.mint/bin" >> "$GITHUB_PATH"` | 次ステップ以降で `swiftlint` / `xcodegen` が解決する |
| 6 | `actions/cache/save`（`if: always()`） | 2-5。**後続の失敗でキャッシュを失わないためここに置く** |
| 7 | **ツールのバージョン出力** | `xcodebuild -version` / `xcrun swift-format --version` / `swiftlint --version` / `xcodegen --version`。失敗時の切り分け材料をログに残す（NFR-1）。**ツールが揃った後でなければ意味がない**ので 5 の後に置く |
| 8 | swift-format の整形差分チェック | プロジェクト生成不要。最も速い |
| 9 | SwiftLint | プロジェクト生成不要 |
| 10 | `xcodegen generate` | 以降の前提 |
| 11 | `xcodebuild ... build` | |
| 12 | `xcodebuild ... test` | |

**fail-fast のトレードオフ:** lint で落ちるとビルド結果が分からず、1 回の CI 実行で全項目の結果が得られない。ただし**ローカルで同じコマンドを全部流せる**（FR-3）ため実害は小さいと判断した。全項目を常に走らせる構成（`if: always()`）は、ステップ間の依存（10 が失敗したら 11・12 は無意味）を扱うために条件分岐が増え、CI の挙動が読みにくくなる。

### 2-5. Mint のキャッシュは `restore` / `save` を分ける

`actions/cache`（統合版）は**ジョブが成功したときにしか保存しない。** 2-4 は fail-fast の単一ジョブで、コストの高い `mint bootstrap` の**後ろ**に lint / build / test が並ぶため、統合版を使うと **「lint が落ちた」「テストが落ちた」という最も頻度の高い赤いケースでキャッシュが一切保存されない。** 赤い PR で修正を繰り返す間、毎回 SwiftLint のソースビルドを払い続けることになり NFR-3 に直撃する。

そのため **`actions/cache/restore` と `actions/cache/save` に分割**し、`save` を `bootstrap` 直後（ステップ 6）に `if: always()` で置く。

**キー設計:**

```
key:          mint-${{ runner.os }}-xcode26.6-${{ hashFiles('Mintfile') }}
restore-keys: mint-${{ runner.os }}-xcode26.6-
```

`Mintfile` のハッシュを含めることでバージョン変更時に自動で無効化される。**Xcode のバージョンもキーに含める** — `~/.mint` にはそのツールチェーンでビルドしたバイナリと SwiftPM のビルドキャッシュが入るため、Xcode を上げたときに古い成果物を引き継がないようにする。`restore-keys` により、バージョン更新時も SwiftPM のビルド成果物を部分的に再利用できる。

**`DerivedData` はキャッシュしない。** スキャフォールドはソース 3 ファイル + テスト 1 ファイルの規模でビルドが短く、キャッシュの復元・保存コストに見合わないため。規模が増えて実行時間が問題になった時点で再検討する。

**実測値（NFR-3 / 2026-08-26 に CI 上で実測済み）:** **Mint はプリビルドバイナリではなく SwiftPM でソースからビルドする。** キャッシュの有無で所要時間が 20 倍近く変わる。

| 区間 | コールド（キャッシュ無し） | ウォーム（キャッシュヒット） |
|------|--------------------------|---------------------------|
| `Bootstrap Mint packages` | **865 秒（14.4 分）** | **0 秒** |
| `Save Mint cache` | 2 秒 | skipped（`cache-hit == 'true'` の条件が機能） |
| 検証 5 項目（整形 / lint / generate / build / test） | 合計 約 25 秒 | 合計 約 36 秒 |
| **ジョブ全体** | **15.2 分** | **49 秒** |

（参考: ローカル（macOS 26.3 / arm64）でのコールドの `mint bootstrap --link` は 9 分 10 秒。キャッシュサイズは 10.05 MiB。）

**キャッシュ設計は意図どおり機能している。** ウォーム時は `bootstrap` が 0 秒で、保存もスキップされる。

**残る懸念（キャッシュミスの発生条件）:** (a) `Mintfile` の変更（バージョン更新 PR。意図的で稀）、(b) キーに含めた Xcode バージョンの変更、(c) **GitHub のキャッシュ退避（7 日間アクセスの無いキャッシュは削除される / リポジトリ全体で 10GB 超過時も削除）**。**(c) は活動頻度の低い個人プロジェクトでは現実的に起こりうる**（1 週間 push が無いと次の PR が 15 分級になる）。

**この点の扱いはユーザーの判断事項**（代替案: SwiftLint を Mint ではなく配布バイナリの直接取得に切り替える。XcodeGen はビルドが軽いため Mint のままでよい）。**現時点では実害が観測されていないため未決事項としては起票せず、6 章の TODO として記録する。**

### 2-6. swift-format は必ず `xcrun` 経由で呼ぶ

ランナーには **「SwiftFormat 0.62.1」（Nick Lockwood 版の `swiftformat`）がプリインストールされている**が、これは本プロジェクトが使う Apple の `swift-format` とは**別のツール**で、設定もルールも互換性が無い。`swiftformat` を誤って呼ぶと整形差分の判定が `docs/scaffold/design.md` D-5 / D-10 の意図と食い違う。

`xcrun swift-format` の形で呼び、2-1 の `DEVELOPER_DIR` で固定した Xcode のツールチェーンから解決させる。**Mintfile では管理しない**（Xcode 同梱のため）。

**⚠ 未検証:** ランナー上に `xcrun swift-format` が実在することは**ローカル実測からの推定**であり、ランナーでは未確認。**初回 CI 実行で確認する**（2-4 のステップ 7 がそのまま確認になる）。存在しなかった場合は design.md に未決事項として起票する。

### 2-7. 実行するコマンド

`docs/scaffold/impl.md` 3 章の早見表と**同一の文字列**を使う（FR-3）。**オプションの順序も含めて写すこと。**

| 検証 | コマンド |
|------|---------|
| 整形差分 0 件 | `xcrun swift-format lint --strict --recursive Sources Tests` |
| SwiftLint 警告 0 件 | `swiftlint lint --strict Sources Tests` |
| プロジェクト生成 | `xcodegen generate` |
| ビルド | `xcodebuild -project Shippitsu.xcodeproj -scheme Shippitsu -configuration Debug -derivedDataPath DerivedData build` |
| テスト | `xcodebuild -project Shippitsu.xcodeproj -scheme Shippitsu -destination 'platform=macOS' -derivedDataPath DerivedData test` |

`-configuration Debug` / `-destination 'platform=macOS'` / `-derivedDataPath DerivedData` はいずれも早見表が付けているものであり、**CI で落とさない**（落とすと解決がランナー環境依存になり「CI だけ落ちる」を作りかねず、FR-3 が避けようとしている状態そのものになる）。

---

## 3. 実装ステップ

| # | 内容 | 対応 |
|---|------|------|
| 1 | `Mintfile` を作成する（1 章の内容） | design.md S-3 / D-2 |
| 2 | ローカルに Mint を導入し（`brew install mint`）、`mint bootstrap --link` を実行する | scaffold D-11 |
| 3 | ローカルで検証 5 項目が Mint 経由でも通ることを確認する（2-7 のコマンド） | FR-3 |
| 4 | `.github/workflows/ci.yml` を作成する（2-3 の骨格 + 2-4 のステップ） | design.md S-1 / S-2 / S-3 |
| 5 | `docs/scaffold/impl.md` 3 章の早見表を更新する — **「前提ツールの導入」行を `brew install mint` + `mint bootstrap --link` に置き換え**、各コマンドが `$HOME/.mint/bin` を PATH に含む前提であることを注記する | FR-3 / D-2 |
| 6 | コミット・PR 作成（コミットエージェントの担当）。作業ブランチは `ci/github-actions`、PR の base は `main` | `commit-workflow` 規約 / scaffold **D-14**（`Co-Authored-By`） |
| 7 | **初回 CI 実行を観測する** — 実行時間の実測（2-5）、`xcrun swift-format` の実在確認（2-6）、app-hosted テストの挙動確認（6 章） | NFR-3 |
| 8 | **ブランチ保護を設定する**（`gh` API / Claude が実行） | design.md D-3 / **D-4** / S-4 |

**ステップ 5 の補足:** 早見表の「前提ツールの導入」は現在 `brew install xcodegen swiftlint` である。これを残すと、環境を作り直したときに**固定されていないバージョン**が入り、D-2 と FR-3 が構造的に崩れる（scaffold NFR-5 の再現性も Mint 導入前より悪化する）。

**ステップ 6 の注意:** scaffold の **D-12 / D-15 はスキャフォールド PR 限定の一回性の手順**（`main` にファイルを置かない / `main` に空コミットを置いて base にする）であり、**本タスクには適用しない。** PR #1 / #2 はすでに `main` にマージ済みで、`main` はプロジェクト全体を含んでいる。本タスクで有効なのは **D-14** と `commit-workflow` 規約のみ。

**ステップ 8 の順序:** ステップ 7 の後に行う。REST API 経由では `required_status_checks` の context に**任意の文字列を設定できる**ため技術的な依存ではないが、**実測でチェック名（`verify`）を確認してから設定するほうが取り違えを防げる**という運用上の理由による。

### ステップ 8 で設定する内容

| 設定項目 | 値 | 理由 |
|---------|---|------|
| `required_status_checks.contexts` | `["verify"]` | 2-3 のジョブ名 |
| `required_status_checks.strict` | **`true`** | design.md **D-4** |
| `enforce_admins` | `false` | D-3。CI 自体が壊れたときの逃げ道を残す |
| `required_pull_request_reviews` | `null` | レビュアーが実質ユーザー 1 人であり、有効にすると自分の PR をマージできなくなる |
| `restrictions` | `null` | 1 人運用のため push 制限は不要 |

---

## 4. コミット分割案

`commit-workflow` 規約（意味単位で分割 / 1 行目は英語サマリ・詳細は日本語 / `git add` はファイルを明示）に従う。**`Co-Authored-By` フッターを付ける根拠は scaffold D-14**（`commit-workflow` 規約本体には `Co-Authored-By` の規定は無い）。

| # | 意味単位 | 含めるもの |
|---|---------|-----------|
| 1 | 設定 | `Mintfile` + `docs/scaffold/impl.md` の早見表更新 — 開発ツールのバージョン固定と、それに伴う手順書の変更 |
| 2 | 設定 | `.github/workflows/ci.yml` — CI ワークフロー |
| 3 | ドキュメント | `docs/ci/design.md` / `docs/ci/impl.md` |

コミット 1 で早見表の更新を同梱するのは、**「なぜ導入手順が brew から Mint に変わったか」が `Mintfile` の追加と同じコミットで追える**ようにするため。

---

## 5. 実装状況

**全ステップ（1〜8）完了**（2026-08-26 時点）。design.md の未決事項は 0 件。**CI は初回実行から全項目グリーンで、未検証リスク 3 件はすべて解消した。**

| # | ステップ | 状況 |
|---|---------|------|
| 1 | `Mintfile` 作成 | **完了**（1 章の内容で作成） |
| 2 | ローカルへの Mint 導入 | **完了**（mint 0.18.0 / `mint bootstrap --link` に **9 分 10 秒**。SwiftLint 0.65.0・XcodeGen 2.46.0 を `~/.mint/bin` にリンク） |
| 3 | ローカルでの検証 | **完了**（PATH を通したうえで 5 項目すべて成功: 整形差分 0 件 / SwiftLint 0 violations / `xcodegen generate` / `** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **` かつ `scaffoldPlaceholder()` 1 件成功。`which` で `~/.mint/bin` 解決も確認） |
| 4 | `ci.yml` 作成 | **完了**（2-3 の骨格 + 2-4 の 12 ステップ。YAML 構文・ジョブ名 `verify`・`runs-on: macos-26` を機械確認） |
| 5 | `docs/scaffold/impl.md` の早見表更新 | **完了**（前提ツールの導入行を Mint に置換 + PATH の前提を注記。同ファイルの変更履歴にも記録） |
| 6 | コミット・PR | **完了**（3 コミット / PR [#19](https://github.com/ayatsuki-meowmeow/shippitsu/pull/19) を base = `main` で作成） |
| 7 | 初回 CI 実行の観測 | **完了**（run `32972357261`。コールド 15.2 分 / ウォーム 49 秒。ランナーのツールは Xcode 26.6 (17F113) / swift-format 6.3.0 / SwiftLint 0.65.0 / XcodeGen 2.46.0 で**ローカルと完全一致**） |
| 8 | ブランチ保護の設定 | **完了**（`gh api` で設定。`contexts: [verify]` / `strict: true` / `enforce_admins: false` / `required_pull_request_reviews: null` / `restrictions: null` を応答で確認） |

---

## 6. 既知の制約・TODO

| 項目 | 内容 |
|------|------|
| **キャッシュ退避時の 15 分実行**（⚠ 唯一残った NFR-3 の懸念） | 2-5 のとおり、キャッシュがあれば 49 秒だが、**7 日間アクセスが無いとキャッシュが削除され、次の実行が 15.2 分になる。** 活動頻度の低い個人プロジェクトでは現実的に起こりうる。許容するか、SwiftLint を配布バイナリの直接取得に切り替えるかは**ユーザーの判断事項**。実害が観測された時点で判断する |
| ~~**Mint のビルド時間が未実測**~~ | **解消（2026-08-26）。** CI で実測しコールド 15.2 分 / ウォーム 49 秒。詳細は 2-5 |
| ~~**`xcrun swift-format` のランナー上での実在が未確認**~~ | **解消（2026-08-26）。** ランナー上で `xcrun swift-format --version` → `6.3.0`（ローカルと一致）を確認。整形差分チェックも成功 |
| ~~**app-hosted テストがランナー上で動くか未検証**~~ | **解消（2026-08-26）。** `xcodebuild ... test` がランナー上で成功（12 秒）。`TEST_HOST` 経由でアプリが起動する構成でも問題は出なかった |
| **ローカルの brew 版と Mint 版の二重管理** | ローカルには brew 版の `swiftlint` 0.65.0 / `xcodegen` 2.46.0 が既に存在する。現時点では Mintfile と同一バージョンのため実害は無いが、`brew upgrade` 後は PATH の解決順で挙動が変わる。**brew 版のアンインストールを推奨するが、ユーザーの環境を削る操作のため確認を取ってから実施する**（scaffold D-11 はインストールの許可であり、アンインストールは範囲外） |
| **ローカルの PATH をシェル設定に永続化していない** | 2-2 のとおりコマンド実行時に前置する方式。ユーザーが手で `swiftlint` を叩くと brew 版が走る。永続化するかはユーザーの dotfiles の問題であり本タスクでは触らない |
| **ジョブ名の改名がブランチ保護を壊す** | 2-3 のとおり `verify` は必須チェックの context そのもの。改名時はブランチ保護も同時更新する |
| **SwiftLint 0.65.1 が未取り込み** | リリース済み。design.md D-2 に従い**独立した PR** で上げる |
| **CI は S-5 の基準 2 を代替しない** | 基準 2 は「人がウィンドウを見て判断する」ことを内容とするため（design.md「CI で代替できないもの」）。テスト実行時にウィンドウ自体は開くが、描画結果の判断は人にしかできない |
| **`macos-26` ランナーのイメージ更新** | ランナーイメージ自体は GitHub 側で継続的に更新される。Xcode とツールを固定しても、OS のパッチバージョン等は追随する。完全な再現性は担保しない |

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-08-26 | **実装完了（ステップ 1〜8）と CI 実測値の記録。方針・技術的判断（2 章）は変更していない。** **[実測 / 2-5]** CI 上でコールド **15.2 分**（うち `mint bootstrap` が **865 秒 = 14.4 分**）、ウォーム **49 秒**（`bootstrap` 0 秒 / `Save Mint cache` は `cache-hit == 'true'` によりスキップ）を実測し、リスク欄を推定から実測値の表に置き換えた。キャッシュサイズは 10.05 MiB。**キャッシュ設計（restore / save の分割と条件付き保存）は意図どおり機能することを確認。** **[未検証リスク 3 件がすべて解消]** (1) Mint のビルド時間 → 実測済み、(2) **ランナー上の `xcrun swift-format` は実在**（`6.3.0`。ローカルと一致）、(3) **app-hosted テストはランナー上で成功**（12 秒。`TEST_HOST` 経由でアプリが起動する構成でも問題なし）。6 章の該当 3 行を打ち消し線付きの解消済み記録に置き換えた。**[残る懸念]** キャッシュは **7 日間アクセスが無いと退避される**ため、活動が空くと次の実行が 15.2 分になる点のみ 6 章の TODO として残した（実害が出た時点でユーザーが判断。代替案は SwiftLint の配布バイナリ直接取得）。**未決事項としては起票していない。** **[実装状況]** 全 8 ステップを完了に更新。ランナーのツールバージョン（Xcode 26.6 / 17F113、swift-format 6.3.0、SwiftLint 0.65.0、XcodeGen 2.46.0）が**ローカルと完全一致**することを確認（FR-3）。ブランチ保護は `gh api` で設定し、応答で 5 項目すべてを検証した。**[design.md 側]** 「前提の確認結果」の `swift-format` 行を「実在は初回実行で確認する（未検証）」から**確認済み**に更新した |
| 2026-08-24 | **ドキュメントレビューの指摘（blocker 5 / should-fix 8 / nit 5）に対応。** **[blocker]** (1) **CI 側に Mint 本体の導入ステップが無く `mint: command not found` で即死する**問題を修正（2-4 のステップ 3 に `brew install mint` を追加。design.md の「前提の確認結果」にも `mint` 未プリインストールを追記）。(2) **2-7 のコマンドが早見表と一致しておらず FR-3 違反だった**問題を修正（ビルドの `-configuration Debug`、テストの `-destination 'platform=macOS'` が欠落していた。「同一の文字列」と断定しながら実際は不一致だった）。(3) **ステップ順序の誤り**を修正（バージョン出力をツール導入前に置いていたため command not found で落ち、NFR-1 の目的も果たせなかった。キャッシュ復元・PATH 追加のステップも表に欠落していた）。(4) **`mint run` 短縮形が「最新タグを選ぶ」という記述は事実誤認**だったため訂正（Mint README は「Mintfile があればそのバージョンを使う」と明記。`bootstrap --link` の採用理由を「早見表とコマンド文字列が同一になる」の 1 点に整理）。(5) **必須チェックの context（ジョブ名）が未確定**だった問題を解消（`verify` に固定し、改名するとブランチ保護が壊れる旨を明記）。あわせて「チェック名は一度観測されないと候補に出ない」という記述は **Web UI のサジェストの話で `gh` API には当てはまらない**ため、ステップ 8 の順序を「技術的依存」から「取り違え防止という運用上の理由」に書き換えた。**[should-fix]** `actions/cache` は**ジョブ成功時しか保存しない**ため、fail-fast 構成では最も頻度の高い赤いケースでキャッシュが失われる問題に対応し、`cache/restore` + `cache/save`（`if: always()`）の分割とキーへの Xcode バージョン追加を 2-5 に明記 / **`ci.yml` の骨格（`on` / `permissions` / `concurrency` / `runs-on` / ジョブ名 / `env`）が未記載**だったため 2-3 として追加 / **ブランチ保護の設定値が未確定**だったため 3 章に表を追加し、`strict` は仕様レベル（ユーザーの手作業に影響）と判断して **design.md の未決事項 4 として起票** / ステップ 5 を「PATH の前提を追記」から**「前提ツールの導入行を Mint に置き換える」**に修正（brew のままでは環境再構築時に固定されないバージョンが入り D-2 / FR-3 が崩れる）/ ステップ 6 の **scaffold D-12 / D-15 参照を削除**（スキャフォールド PR 限定の一回性手順であり実態と食い違う。有効なのは D-14 のみ）/ バージョン表を「正は `Mintfile`、本表はスナップショット」と整理。**[nit]** `Mintfile` の内容を 1 章に例示 / `Co-Authored-By` の根拠は `commit-workflow` 規約本体ではなく scaffold D-14 である旨を 4 章に明記 / `DerivedData` をキャッシュしない判断を 2-5 に明記 / コミット 1 に早見表更新を同梱。**[design.md 側の対応]** 「ランナーには GUI セッションが無い」という**根拠なき断定を訂正**（テスト実行時に `TEST_HOST` 経由でウィンドウは実際に開く。CI で代替できないのは起動ではなく**描画結果の目視判断**）/ 「`macos-26` は FR-4 を満たす唯一の選択肢」を訂正（`macos-26-intel` 等も満たす。arm64 であることを選択理由に）/ S-2 表の自己参照を解消。**未検証リスクを 2 件 → 3 件**に増やした（app-hosted テストがランナー上で動くかを追加） |
| 2026-08-24 | 初版作成（実装フェーズ前の upfront 作成）。構成・固定バージョン表・技術的判断・実装ステップ・コミット分割案を策定。実装状況は全項目「未着手」 |
