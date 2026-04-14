---
sidebar_position: 1
title: 新規プロジェクト参加時に役立つGitコマンド5選
---

## はじめに

[新しくプロジェクトに入った人がリポジトリの現状を素早く把握するためのGitコマンド5選](https://l.smartnews.com/m-7vjV4zza/flt0Ju)（元記事: [The Git Commands I Run Before Reading Any Code](https://piechowski.io/post/git-commands-before-reading-code/)）の要約。
コードを読む前にコミット履歴からプロジェクトの健全性やリスクを把握するためのコマンド群。

## コマンドと意図

### 1. 最も変更されているファイルは何か (What Changes the Most)

```bash
git log --format=format: --name-only --since="1 year ago" | sort | uniq -c | sort -nr | head -20
```

**意図**: 過去1年で最も変更されたファイル上位20件を特定する。変更頻度が高いファイルは、活発な開発が行われているか、誰も触りたがらない負債（バグの温床）である可能性が高い。

### 2. 誰がこれを作ったのか (Who Built This)

```bash
git shortlog -sn --no-merges
```

**意図**: コミット数順にコントリビューターをランク付けする。特定の人物に依存しすぎていないか（バスファクター）、過去の開発者と現在の保守者が異なっていないかを確認する。

### 3. バグはどこに集中しているか (Where Do Bugs Cluster)

```bash
git log -i -E --grep="fix|bug|broken" --name-only --format='' | sort | uniq -c | sort -nr | head -20
```

**意図**: バグ修正に関連するコミットが多いファイル上位20件を特定する。1のコマンドと組み合わせて、頻繁に変更され、かつバグが多い「最もリスクの高いコード」を見つけ出す。

### 4. プロジェクトは加速しているか、死にかけているか (Is This Project Accelerating or Dying)

```bash
git log --format='%ad' --date=format:'%Y-%m' | sort | uniq -c
```

**意図**: 月ごとのコミット数を集計し、プロジェクトの勢いや開発リズムを把握する。コミット数の急減は主要メンバーの離脱を、定期的なスパイクは継続的デリバリーではなくバッチリリースを行っていることを示唆する。

### 5. チームはどのくらいの頻度で火消しをしているか (How Often Is the Team Firefighting)

```bash
git log --oneline --since="1 year ago" | grep -iE 'revert|hotfix|emergency|rollback'
```

**意図**: 過去1年間のリバートやホットフィックスの頻度を確認する。これらが多い場合、テストの信頼性不足やデプロイプロセスへの不安など、より深い問題が潜んでいることを示す。
