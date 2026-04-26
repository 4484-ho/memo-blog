---
sidebar_position: 2
title: Claude Code CLI をサブプロセスで呼び出し、AIエージェントをアプリに統合する PoC
---

## TL;DR

Claude Code CLI の `-p`（print mode）をアプリのサーバーサイドからサブプロセスとして起動し、自然言語でタスク管理操作を行う PoC を作成・動作確認した。Pro/Max サブスクリプションの枠内で動作するため、API Key も従量課金も不要。

### Code
<details>
  <summary>TypeScriptでの実装内容</summary>

```typescript
/**
 * Taskflow AI Agent PoC
 * 検証内容:
 *   1. claude -p --output-format stream-json の基本動作
 *   2. stream-json のパース
 *   3. システムプロンプト → JSON操作指示の受け取り
 *   4. 模擬API呼び出し（実際のDBなし）
 *
 * 実行方法:
 *   npx tsx agent-poc.ts
 */

import { spawn } from "child_process";
import { once } from "events";

// 型定義

type IssueStatus = "backlog" | "todo" | "in_progress" | "in_review" | "done" | "cancelled";
type IssuePriority = "urgent" | "high" | "medium" | "low" | "none";

interface Issue {
  identifier: string;
  title: string;
  status: IssueStatus;
  priority: IssuePriority;
}

interface AppContext {
  currentView: string;
  selectedIssue: Issue | null;
  activeCycleTitle: string | null;
  projects: { id: string; prefix: string; title: string }[];
  issues: Issue[];
}

type AgentAction =
  | { action: "issue_create"; params: { title: string; projectId: string; priority?: IssuePriority }; message: string }
  | { action: "issue_update"; params: { identifier: string; status?: IssueStatus; priority?: IssuePriority }; message: string }
  | { action: "issue_list"; params: { status?: IssueStatus }; message: string }
  | { action: "summary"; params: Record<string, never>; message: string };

interface ClaudeStreamEvent {
  type: string;
  message?: {
    content?: { type: string; text?: string }[];
  };
}

// 模擬データストア（実際はPrisma/SQLite）

const mockIssues: Issue[] = [
  { identifier: "FE-1", title: "ログイン画面の実装", status: "in_progress", priority: "high" },
  { identifier: "FE-2", title: "ダッシュボードUI", status: "todo", priority: "medium" },
  { identifier: "API-1", title: "認証APIエンドポイント", status: "done", priority: "urgent" },
  { identifier: "API-2", title: "Issue CRUD API", status: "backlog", priority: "low" },
];

const mockProjects = [
  { id: "proj-1", prefix: "FE", title: "Frontend" },
  { id: "proj-2", prefix: "API", title: "Backend API" },
];

// ユーティリティ

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// システムプロンプト構築

function buildSystemPrompt(context: AppContext): string {
  return `
あなたは Taskflow というタスク管理アプリのAIアシスタントです。
ユーザーの自然言語の指示を解釈し、以下のJSON形式 **のみ** で返してください。
説明文や前置きは不要です。JSONブロックだけを返してください。

## 利用可能なアクション

- issue_create: { title, projectId, priority? }
- issue_update: { identifier, status?, priority? }
- issue_list:   { status? }
- summary:      {}

## ステータス値
backlog / todo / in_progress / in_review / done / cancelled

## 優先度値
urgent / high / medium / low / none

## 現在のコンテキスト
- 表示中のビュー: ${context.currentView}
- 選択中のIssue: ${context.selectedIssue?.identifier ?? "なし"}
- アクティブなCycle: ${context.activeCycleTitle ?? "なし"}
- Project一覧: ${JSON.stringify(context.projects)}
- Issue一覧（抜粋）: ${JSON.stringify(context.issues.slice(0, 10))}

## 返答フォーマット（必ずこの形式で）

\`\`\`json
{ "action": "...", "params": { ... }, "message": "ユーザーへの説明（日本語）" }
\`\`\`
`.trim();
}

// 模擬APIハンドラ（実際はfetch('/api/issues/...')）

function handleAgentAction(agentAction: AgentAction): void {
  console.log("\n🔧 [Mock API] アクション実行:");
  switch (agentAction.action) {
    case "issue_update": {
      const issue = mockIssues.find((i) => i.identifier === agentAction.params.identifier);
      if (issue) {
        if (agentAction.params.status) issue.status = agentAction.params.status;
        if (agentAction.params.priority) issue.priority = agentAction.params.priority;
        console.log(`   PATCH /api/issues/${agentAction.params.identifier}`, agentAction.params);
        console.log(`   ✅ ${issue.identifier} を更新しました:`, issue);
      } else {
        console.log(`   ❌ Issue not found: ${agentAction.params.identifier}`);
      }
      break;
    }
    case "issue_create": {
      const project = mockProjects.find((p) => p.id === agentAction.params.projectId);
      const prefix = project?.prefix ?? "UNKNOWN";
      const newIssue: Issue = {
        identifier: `${prefix}-${mockIssues.length + 1}`,
        title: agentAction.params.title,
        status: "backlog",
        priority: agentAction.params.priority ?? "none",
      };
      mockIssues.push(newIssue);
      console.log(`   POST /api/issues`, agentAction.params);
      console.log(`   ✅ Issue作成:`, newIssue);
      break;
    }
    case "issue_list": {
      const filtered = agentAction.params.status
        ? mockIssues.filter((i) => i.status === agentAction.params.status)
        : mockIssues;
      console.log(`   GET /api/issues`, agentAction.params);
      console.log(`   📋 Issue一覧 (${filtered.length}件):`, filtered);
      break;
    }
    case "summary": {
      const counts = mockIssues.reduce<Record<string, number>>((acc, i) => {
        acc[i.status] = (acc[i.status] ?? 0) + 1;
        return acc;
      }, {});
      console.log(`   📊 サマリー:`, counts);
      break;
    }
  }
}

// stream-json パーサ

function extractJsonAction(text: string): AgentAction | null {
  const match = text.match(/```json\s*([\s\S]*?)```/);
  if (!match) return null;
  try {
    return JSON.parse(match[1].trim()) as AgentAction;
  } catch {
    return null;
  }
}

// Claude CLI 呼び出しコア

async function callClaudeCLI(userMessage: string, context: AppContext): Promise<void> {
  const systemPrompt = buildSystemPrompt(context);
  console.log("\n🚀 [Claude CLI] 起動中...");
  console.log(`📝 ユーザー入力: "${userMessage}"`);

  const proc = spawn("claude", [
    "-p", "--output-format", "stream-json",
    "--verbose",
    "--disallowed-tools", "Bash", "Write", "Edit", "Read",
    "--max-turns", "3",
    "--system-prompt", systemPrompt,
    userMessage,
  ], { stdio: ["ignore", "pipe", "pipe"] });

  // close は stdio が閉じた後に発火するので、先に登録しておく
  const closePromise = once(proc, "close") as Promise<[number | null]>;

  let fullText = "";
  let spawnError: Error | undefined;

  proc.on("error", (err: Error) => {
    console.error("❌ [Claude CLI] 起動エラー:", err.message);
    console.error("   → `claude` コマンドがインストールされているか確認してください");
    spawnError = err;
  });

  const consumeStdout = async () => {
    let buffer = "";
    proc.stdout.setEncoding("utf8");
    for await (const chunk of proc.stdout) {
      buffer += chunk as string;
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";
      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const event = JSON.parse(line) as ClaudeStreamEvent;
          if (event.type === "assistant" && event.message?.content) {
            for (const block of event.message.content) {
              if (block.type === "text" && block.text) {
                process.stdout.write(block.text);
                fullText += block.text;
              }
            }
          }
          if (event.type === "result") {
            console.log("\n\n✨ [Claude CLI] 応答完了");
          }
        } catch {
          // JSON以外の行はスキップ
        }
      }
    }
  }

  const consumeStderr = async () => {
    proc.stderr.setEncoding("utf8");
    for await (const chunk of proc.stderr) {
      const msg = chunk as string;
      if (!msg.includes("credentials") && !msg.includes("Loaded")) {
        console.error("⚠️  [stderr]", msg.trim());
      }
    }
  }

  await Promise.all([consumeStdout(), consumeStderr()]);
  if (spawnError) throw spawnError;

  const [code] = await closePromise;
  console.log(`\n[Claude CLI] プロセス終了 (code: ${code})`);

  const agentAction = extractJsonAction(fullText);
  if (agentAction) {
    console.log("\n📦 [Parser] アクション検出:", JSON.stringify(agentAction, null, 2));
    handleAgentAction(agentAction);
  } else {
    console.log("\n⚠️  [Parser] JSONアクションが見つかりませんでした");
    console.log("生のレスポンス:", fullText);
  }

  if (code !== 0) throw new Error(`Claude CLI exited with code ${code}`);
}

// メイン

async function main() {
  const context: AppContext = {
    currentView: "issues",
    selectedIssue: null,
    activeCycleTitle: "Sprint 2026-W17",
    projects: mockProjects,
    issues: mockIssues,
  };

  const scenarios = [
    "FE-1を完了にして",
    "今のスプリントの進捗を教えて",
    // "バグ修正タスクを作って、優先度は高で、プロジェクトはFrontendで",
  ];

  for (const userMessage of scenarios) {
    console.log("\n" + "=".repeat(60));
    await callClaudeCLI(userMessage, context).catch((err: Error) => {
      console.error("エラー:", err.message);
    });
    await sleep(1000);
  }

  console.log("\n" + "=".repeat(60));
  console.log("✅ PoC 完了");
  console.log("最終的なIssue状態:", mockIssues);
}

main();

```

</details>


---

## モチベーション

個人開発のタスク管理アプリ「Taskflow」に AI エージェントを組み込みたいと考えた。やりたいことはシンプルで、「FE-42を完了にして」のような自然言語の指示で Issue のステータスを更新したり、スプリントの進捗サマリーを生成したりすること。

Claude を使う方法は3つある。

| 方式 | サブスク利用 | 備考 |
|---|---|---|
| Claude Code CLI (`claude -p`) | ✅ 可能 | Pro/Max の OAuth トークンで認証 |
| Claude Agent SDK | ❌ API Key 必須 | サブスク課金は非対応（2026年4月時点） |
| Anthropic API 直接呼び出し | ❌ API Key 必須 | 従量課金 |

個人開発で API の従量課金は避けたい。Agent SDK も現時点ではサブスクに非対応。消去法で **CLI をサブプロセスとして呼び出す方式** を採用することにした。

ただし不確実性が高い。CLI のストリーミング出力のパース、システムプロンプトによる構造化レスポンスの制御、OAuth セッションの引き継ぎ——どれも「たぶん動くはず」の域を出ない。そこで本実装に入る前に、1ファイルの TypeScript で一気通貫の PoC を行った。

---

## 前提条件

この PoC を動かすには、ローカル環境で以下が整っている必要がある。

### 1. Claude Code CLI のインストール

```bash
npm install -g @anthropic-ai/claude-cli
```

インストール後、バージョンが確認できれば OK。

```bash
claude --version
# 2.1.119 (Claude Code) など
```

### 2. CLI でのログイン（OAuth 認証）

```bash
claude login
```

このコマンドを実行するとブラウザが自動で開き、Anthropic の認証画面が表示される。Claude Pro または Max のアカウントでログインすると、ブラウザからローカルの CLI にトークンが渡され、認証が完了する。

ターミナルに `Successfully authenticated` と表示されれば成功。以降は `claude` コマンドがサブスク枠で動作する。

### 3. 必要なサブスクリプション

Claude Pro または Max のサブスクリプションが必要。Free プランでは CLI 利用ができない。

### 4. Node.js 環境

TypeScript の実行に `tsx` を使用するため、Node.js（v18 以上推奨）がインストールされていること。

---

## なぜ OAuth で動くのか

「CLI をサブプロセスで起動するだけで、なぜ API Key なしに Claude が使えるのか？」という疑問に答えておく。

### OAuth 2.0 認証フローの仕組み

Claude Code CLI は OAuth 2.0 Authorization Code Flow で認証する。大まかな流れは以下の通り。

```
1. claude login 実行
       │
       ▼
2. ブラウザが開き、Anthropic の認証画面を表示
       │
       ▼
3. ユーザーがログイン・承認
       │
       ▼
4. Anthropic サーバーが認可コードをローカルの CLI に返す
   （CLI がローカルで HTTP サーバーを立て、コールバックを受信）
       │
       ▼
5. CLI が認可コードを アクセストークン + リフレッシュトークン に交換
       │
       ▼
6. トークンをローカルに保存
   - macOS: Keychain（"claude-code" サービス名）
   - Linux: ~/.claude/.credentials.json
```

### トークンの自動更新

一度ログインすれば、基本的に再認証は不要。アクセストークンの有効期限が切れると、リフレッシュトークンを使って CLI が自動的に新しいアクセストークンを取得する。明示的に `claude logout` しない限り、セッションは維持される。

### サブプロセスでも動く理由

`child_process.spawn("claude", [...])` でサブプロセスとして起動した場合でも、CLI はローカルに保存されたトークンを読みに行く。サブプロセスだからといって別の認証が必要になるわけではなく、同じマシン上で `claude` コマンドを直接叩くのと同じ認証情報が使われる。

これが「API Key 不要」の仕組みの正体。サブスクリプションに紐づいた OAuth トークンがローカルに保存されており、CLI がそれを自動的に使うだけ。

### 注意: サブスクの共有クォータ

ただし、この方式で消費されるのは Pro/Max サブスクリプションの使用枠そのもの。claude.ai（Web）、Claude Desktop、Claude Code CLI のすべてが同じ5時間ローリングウィンドウの制限を共有している。アプリから頻繁に呼び出すと、他の用途で枠が足りなくなる可能性がある点は認識しておく必要がある。

---

## 動作原理

### アーキテクチャ

```
┌─────────────────────────────────────┐
│  アプリ (Node.js / Next.js)         │
│                                     │
│  ユーザー入力                         │
│       │                             │
│       ▼                             │
│  child_process.spawn("claude", ...) │
│       │                             │
│       ▼  stdout (stream-json)       │
│  行ごとにJSONパース                   │
│       │                             │
│       ▼                             │
│  JSONアクション抽出 → API呼び出し      │
└──────────────────┬──────────────────┘
                   │ サブプロセス
                   ▼
            ┌──────────────┐
            │ Claude Code  │
            │ CLI (local)  │ ← Pro/Max OAuth セッション
            └──────────────┘
```

ポイントは以下の通り。

1. **`claude -p`（print mode）** で非対話モードとして起動する
2. **`--output-format stream-json`** で応答をストリーミング JSON として受け取る（`--verbose` フラグも必須）
3. **`--system-prompt`** でアプリのコンテキスト（Issue 一覧、利用可能な操作スキーマ）を注入する
4. **`--disallowed-tools`** でファイル操作系ツール（Bash, Write, Edit, Read）を無効化し、Issue 操作のみに限定する
5. CLI はローカルの **OAuth セッション**を使うため、API Key は不要

### stream-json の構造

CLI の stdout には1行ごとに JSON が流れてくる。テキスト応答は `type: "assistant"` イベントの `message.content` 配列に含まれる。

```json
{"type":"assistant","message":{"content":[{"type":"text","text":"..."}]}}
```

完了時には `type: "result"` イベントが届く。

### システムプロンプトの設計

Claude に「JSON だけ返して」と指示し、利用可能な操作スキーマとアプリの現在のコンテキストを渡す。

```
あなたは Taskflow というタスク管理アプリのAIアシスタントです。
ユーザーの自然言語の指示を解釈し、以下のJSON形式のみで返してください。

## 利用可能なアクション
- issue_create: { title, projectId, priority? }
- issue_update: { identifier, status?, priority? }
- issue_list:   { status? }
- summary:      {}

## 現在のコンテキスト
- 表示中のビュー: issues
- Project一覧: [{"id":"proj-1","prefix":"FE"},{"id":"proj-2","prefix":"API"}]
- Issue一覧: [...]

## 返答フォーマット
{ "action": "...", "params": { ... }, "message": "ユーザーへの説明" }
```

レスポンスの中から ` ```json ... ``` ` ブロックを正規表現で抽出し、`JSON.parse` する。

---

## PoC の構成

1ファイル（`agent-poc.ts`）で以下をすべて検証した。

| 検証項目 | 内容 |
|---|---|
| CLI 起動 | `child_process.spawn` で `claude -p` を起動できるか |
| OAuth 認証 | API Key なしでサブスクのセッションが使われるか |
| stream-json パース | stdout の行単位 JSON を正しくパースできるか |
| 構造化レスポンス | システムプロンプトで指定した JSON 形式で返ってくるか |
| 模擬 API 実行 | パースしたアクションで内部 API を呼べるか |

### 使用した CLI オプション

```bash
claude -p \
  --output-format stream-json \
  --verbose \
  --disallowed-tools Bash Write Edit Read \
  --max-turns 3 \
  --system-prompt "..." \
  "FE-1を完了にして"
```

| オプション | 役割 |
|---|---|
| `-p` | print mode（非対話、結果を出力して終了） |
| `--output-format stream-json` | ストリーミング JSON 出力 |
| `--verbose` | stream-json 利用時に必須 |
| `--disallowed-tools` | 指定ツールを無効化 |
| `--max-turns 3` | 無限ループ防止 |
| `--system-prompt` | アプリコンテキストを注入 |

**注意:** `spawn` の `stdio` は `["ignore", "pipe", "pipe"]` に設定する。stdin を閉じないと CLI が3秒間入力を待つ警告が出る。

---

## 実行結果

### シナリオ1: Issue ステータス更新

入力: `"FE-1を完了にして"`

```
📦 [Parser] アクション検出: {
  "action": "issue_update",
  "params": {
    "identifier": "FE-1",
    "status": "done"
  },
  "message": "FE-1「ログイン画面の実装」のステータスを「完了（done）」に更新しました。"
}

🔧 [Mock API] アクション実行:
   PATCH /api/issues/FE-1 { identifier: 'FE-1', status: 'done' }
   ✅ FE-1 を更新しました
```

自然言語の「完了にして」が正しく `status: "done"` にマッピングされた。

### シナリオ2: スプリント進捗サマリー

入力: `"今のスプリントの進捗を教えて"`

```
📦 [Parser] アクション検出: {
  "action": "summary",
  "params": {},
  "message": "...総Issue数: 4件 / 完了 (done): 2件 (50%) / 未着手 (todo): 1件 (25%)..."
}

🔧 [Mock API] アクション実行:
   📊 サマリー: { done: 2, todo: 1, backlog: 1 }
```

`message` フィールドに Markdown テーブル付きの詳細なサマリーが生成された。コンテキストとして渡した Issue 一覧を正しく参照し、シナリオ1で更新した FE-1 のステータスも反映されていた。

---

## PoC で得られた知見

### うまくいったこと

- **CLI のサブプロセス起動は安定している。** `spawn` + `stdio: ["ignore", "pipe", "pipe"]` で問題なく動作した。
- **OAuth セッションは自動的に引き継がれる。** ローカルで `claude` にログイン済みであれば API Key は一切不要。
- **システムプロンプトによる構造化レスポンスは実用的。** JSON フォーマットの指示に従い、パース可能な形式で返してくれる。
- **コンテキスト注入が効く。** Issue 一覧や Project 情報を渡せば、識別子の解決や状況に応じた判断ができる。

### 注意が必要な点

- **`--output-format stream-json` には `--verbose` が必須。** ドキュメントからは読み取りにくいが、これがないとエラーで落ちる（v2.1.x 時点）。
- CLI のバージョンによってオプション名が異なる可能性があるため、`claude -p --help` で確認すべき。
- **stdin を閉じる必要がある。** `spawn` のデフォルトでは stdin が pipe になるため、CLI が入力待ちの警告を出す。`stdio: ["ignore", ...]` で解決。
- **レスポンスの `message` が想定以上にリッチ。** Markdown テーブルや絵文字を含む長文が返ることがある。UI 側でのレンダリング設計が必要。
- **レート制限は Pro/Max の共有枠。** claude.ai、Claude Desktop、Claude Code CLI と同一の5時間ローリングウィンドウ制限を消費する。

---

## 次のステップ

PoC で基本的な疎通は確認できた。本実装に向けて以下を進める。

1. **Next.js API Route での WebSocket 中継** — stream-json をリアルタイムでフロントに流す
2. **エラーハンドリングの強化** — CLI のタイムアウト、レート制限超過、JSON パース失敗時のフォールバック
3. **システムプロンプトの改善** — 複数アクションの一括実行（1メッセージで複数操作）への対応
4. **破壊的操作の確認フロー** — 削除やステータスの巻き戻しなど、確認ダイアログを挟む仕組み

---

## まとめ

Claude Code CLI をサブプロセスとして呼び出す方式は、個人開発の AI エージェント統合として現実的に機能する。API Key 不要・従量課金なしという点は個人開発者にとって大きなメリットで、CLI のオプションとシステムプロンプトの設計次第で、十分に構造化されたレスポンスが得られる。

PoC をやって正解だった。「たぶん動くはず」が「実際に動いた」に変わったことで、本実装のリスクが大幅に下がった。