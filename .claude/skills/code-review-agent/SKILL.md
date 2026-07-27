---
name: code-review-agent
description: |
  実装差分のコードレビューを、単一エージェントの主観ではなく「5 つの独立レンズの並列レビュー → Haiku による confidence scoring → 閾値フィルタ → 分類ヒント付き指摘の返却」という構造で実行するオーケストレーション規約。5 レンズは (1) 外部仕様遵守 / (2) 内部整合性 / (3) バグ・エッジケース / (4) デグレ影響 / (5) 保守性・可読性。implement-review-loop の step 3（レビュー）で使う。観点の被りとノイズを減らし、レビュアーの主観への依存を最小化する。

  TRIGGER: implement-review-loop の step 3 レビューフェーズに入るとき、メインが「レビューエージェントに委譲」「コードレビュー走らせて」「working diff をレビュー」等と指示したとき。design.md / impl.md が揃った実装差分に対するレビュー全般。

  SKIP: GitHub PR に対するレビュー（公式 code-review プラグイン推奨）、design.md / impl.md が未整備（先に design-impl-docs を回す）、単発の 1〜数行修正で 5 レンズが過剰なとき、サブエージェントが利用できない環境。
---

# コードレビューエージェント

## 目的

「実装 → レビュー → 修正」の反復におけるレビューフェーズを、単一エージェントの主観ではなく独立レンズの並列 + confidence scoring で構造化する。観点の被りとノイズを減らし、レビュアー（＝スキル作者）の主観への依存を最小化する。

## 参照

- ルール本体は `references/rules.md` を参照する。レビュー起動前に必ず読むこと。
- レビュー結果の受け取り・分類・記録・反復制御は implement-review-loop skill に従う。
- サブエージェント委譲の共通要素・モデル選択・コンテキスト管理は subagent-orchestration skill に従う。

## 実行手順

1. `references/rules.md` を読む
2. 対象タスクの design.md / impl.md と、レビュー対象差分（変更ファイル一覧・要約）を確定する
3. rules.md の 5 レンズを並列にサブエージェントとして委譲する
4. 各レンズの指摘に対し Haiku で confidence scoring を並列実行し、閾値未満（既定 80）を捨てる
5. 生き残った指摘を分類ヒント付きで implement-review-loop に返す（未解決の疑問があれば先頭に出す）
