---
sidebar_position: 1
title: Cursor のエージェントスキル（プロジェクト）
description: プロジェクト単位で Agent Skill を置く場所、ディレクトリ構成、SKILL.md の書き方のメモ
---

## 概要

[エージェントスキル](https://cursor.com/ja/docs/skills)は、エージェントにドメイン固有の手順や知識を渡すためのオープンな仕組みです。Cursor では起動時にスキルディレクトリを走査し、エージェントが文脈に応じて読み込みます。チャットで `/` からスキル名を選んで明示的に呼び出すこともできます。

## プロジェクトレベルで置く場所

チームやリポジトリごとに共有したいスキルは、**リポジトリ直下の** `.agents/skills/` に置きます。各スキルは **`SKILL.md` を含むフォルダ**が 1 単位です。

```text
.agents/
└── skills/
    └── my-skill/
        └── SKILL.md
```

- フォルダ名（例: `my-skill`）はフロントマターの `name` と**一致**させる必要があります（[公式ドキュメント](https://cursor.com/ja/docs/skills)の要件）。
- このリポジトリでは、Docusaurus 用ドキュメント追加手順を `.agents/skills/create-docs/SKILL.md` として定義しており、プロジェクトスキルの配置例になります。

## その他の読み込みパス（互換・スコープ）

Cursor は次の場所からもスキルを読み込みます（互換用）。

| 場所 | スコープ |
|------|----------|
| `.agents/skills/` | プロジェクト |
| `.cursor/skills/` | プロジェクト |
| `~/.cursor/skills/` | ユーザー（グローバル） |
| `.claude/skills/`、`~/.claude/skills/` など | 互換 |

個人用のスキルはユーザーディレクトリ、チームで揃えたいものは `.agents/skills/` または `.cursor/skills/` に置く、という切り分けがしやすいです。

## 任意ディレクトリ（scripts / references / assets）

`SKILL.md` だけで足りる場合もありますが、実行用スクリプトや長い参照資料は分離すると、エージェントが**必要なときだけ**読み込みやすく、コンテキストも節約できます。

```text
.agents/
└── skills/
    └── deploy-app/
        ├── SKILL.md
        ├── scripts/
        │   ├── deploy.sh
        │   └── validate.py
        ├── references/
        │   └── REFERENCE.md
        └── assets/
            └── config-template.json
```

| ディレクトリ | 用途の目安 |
|--------------|------------|
| `scripts/` | エージェントが実行するコマンド・スクリプト（言語は Bash / Python / Node など実装依存） |
| `references/` | 詳細仕様や長文。メインの `SKILL.md` は要約に留める |
| `assets/` | テンプレート、設定例、画像など静的ファイル |

`SKILL.md` 内では、スキルルートからの**相対パス**でこれらを参照します。

## SKILL.md の形式

YAML フロントマターと本文で、**いつ・何をするスキルか**をエージェント向けに書きます。

```markdown
---
name: my-skill
description: Short description of what this skill does and when to use it.
---

# My Skill

Detailed instructions for the agent.

## When to Use

- Use this skill when...
- This skill is helpful for...

## Instructions

- Step-by-step guidance for the agent
- Domain-specific conventions
- Best practices and patterns
- Use the ask questions tool if you need to clarify requirements with the user
```

### フロントマターで覚えておくとよい項目

- **`name`（必須）**: 識別子。小文字英数字とハイフンのみ。親フォルダ名と一致。
- **`description`（必須）**: 機能と利用タイミング。モデルが関連スキルを選ぶときの材料になる。
- **`disable-model-invocation`（任意）**: `true` にすると、文脈からの自動適用はせず、`/skill-name` で明示したときだけ読み込まれる動きに近づけられます（スラッシュコマンド相当の運用向け）。

その他の任意フィールド（`license`、`compatibility`、`metadata` など）は [公式のエージェントスキル](https://cursor.com/ja/docs/skills)を参照してください。

## 参考

- [エージェントスキル（Cursor 公式・日本語）](https://cursor.com/ja/docs/skills)
- 標準仕様の詳細: [agentskills.io](https://agentskills.io)
