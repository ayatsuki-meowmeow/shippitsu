---
name: commit-workflow
description: |
  git commit を作成するときに必ず従うべきワークフロー規約。意味単位ごとに分割・英語サマリ＋日本語詳細の2層メッセージ・Co-Authored-By フッター付与（本プロジェクト固有の方針）、の3ルールを強制する。

  TRIGGER: コミット作成を含むあらゆる依頼（「コミットして」「commit して」「変更を記録して」「セーブして」「PR 出す前に」「push する前に」など）、未コミット変更があり git commit を実行する場面、意味単位分割の含意がある依頼（「ビジネスロジックと UI を分けて」など）。自力で git commit を組み立てる前に必ずこのスキルを参照する。

  SKIP: 新規コミット作成を伴わない操作のみ（git log / show / blame での閲覧、rebase / reset / revert / cherry-pick などの履歴書き換え、push / pull / diff 表示、コードレビュー・設計相談）。
---

# Commit Workflow

## 目的

git commit を作成する際、意味単位ごとに分割し、英語サマリ＋日本語詳細の 2 層メッセージに `Co-Authored-By` フッター（実際に作業した Claude のモデル名を記載）を付けてコミットするワークフローを強制する。

## 参照

- ルール本体は `references/rules.md` を参照する。

## 実行手順

1. 作業開始時に `references/rules.md` を読み、意味単位の分類・コミットメッセージ規約・実行手順を把握する。
2. `git status` / `git diff` で変更を確認し、ファイルを意味単位に分類してから `git add <files...>` で1つの意味単位だけをステージングする。
3. HEREDOC で英語サマリ＋空行＋日本語詳細のメッセージを書き、末尾に空行を挟んで `Co-Authored-By` フッター（実際に作業した Claude のモデル名を記載）を付けて `git commit` する。
4. 残りの意味単位について 2〜3 を繰り返し、最後に `git status` でクリーンになっていることを確認する。
5. 意味単位の分け方に迷う場合は `references/rules.md` の「ルールから外れる必要がある場合」に従い、ユーザーに判断を仰ぐ。
