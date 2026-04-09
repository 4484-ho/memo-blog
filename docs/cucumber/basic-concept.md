---
sidebar_position: 1
title: Cucumberの基本概念と仕組み
---

## Cucumberとは？ (Introduction)

[Cucumber公式ドキュメント](https://cucumber.io/docs/)によると、Cucumberは**振る舞い駆動開発（BDD: Behaviour-Driven Development）**をサポートするツールです。

- **Executable Specifications（実行可能な仕様書）**: Cucumberは、プレーンテキストで書かれた仕様書（Gherkin構文）を読み込み、ソフトウェアがその仕様通りに動作するかを検証します。
- **GherkinとStep Definitionsの結合**: Gherkin構文で書かれた各「ステップ（Step）」は、「ステップ定義（Step Definitions）」と呼ばれるプログラミングコードと結びつきます。
- **Single Source of Truth（信頼できる唯一の情報源）**: これにより、テストの自動化だけでなく「システムが実際にどう振る舞うか」を文書化し、ビジネスサイドと開発サイドが共有できる明確な仕様書として機能します。

## Cucumberの基本と柔軟性

Cucumberの実装上の特徴と柔軟性は以下の通りです。

- **Featureは後述する「BRIEFの原則」に沿って記載される**必要があります。
- Cucumberは、Featureの各ステップの文字列を抽出し、ステップ定義（`steps.ts`など）の中から一致する関数を探し出して呼び出します。
- その関数の中に書かれた「任意のコード（API呼び出し、アサーション、ブラウザ操作など）」が実行され、エラーが起きなければ「テスト成功」とみなされます。

だからこそ、Cucumberは「フロントエンド（Playwrightなどを呼ぶ）」でも「バックエンド（fetchなどを呼ぶ）」でも、なんなら「IoT機器の操作」でも、**中身のコード次第でなんでも自動化できる**という非常に高い柔軟性を持っています。

## BRIEFの原則 (Keep your scenarios BRIEF)

テストシナリオ（Feature）を効果的に書くためには、[Keep your scenarios BRIEF](https://cucumber.io/blog/bdd/keep-your-scenarios-brief/) で提唱されている **BRIEF** の原則に従うことが重要です。

シナリオを書く際の3つの主な目標：
1. テストではなく**ドキュメント**として考えること。
2. ビジネスと開発の**コラボレーション**を促進すること。
3. 妨げになるのではなく、プロダクトの**進化をサポート**すること。

これらを実現するための6つの原則（頭文字をとって **BRIEF**）があります。

1. **Business language（ビジネス用語）**:
   - シナリオはビジネスドメインの言葉で書く。ビジネスサイドのメンバーが曖昧さなく理解できる用語を使うこと。
   - **アンチパターン**: コンテキストによって意味が変わる用語（例：アドレス、ユーザーなど）の使用。
2. **Real data（実際のデータ）**:
   - 具体的な実際のデータを使うことで、境界条件や暗黙の前提を明らかにする。意図を示すために役立つ場合は常に実際のデータを使う。
   - **アンチパターン**: 本番環境の特定のデータが存在することに依存するシナリオ。
3. **Intention revealing（意図の明示）**:
   - どうやって達成するか（メカニクス）ではなく、**何を達成しようとしているのか（意図）**を明らかにする。シナリオの各行が意図を記述していることを確認する。
   - **アンチパターン**: UIの用語（例：「ボタンをクリックする」「リンクをたどる」など）の使用。
4. **Essential（本質的）**:
   - シナリオの目的は「ルールの振る舞い」を説明すること。目的に直接寄与しない付随的な詳細は削除する。読者の理解に寄与しないシナリオはドキュメントとしての居場所はない。
   - **アンチパターン**: 本質的ではない詳細を含めること（例：時間が振る舞いに影響を与えないのに、日時を指定するなど）。
5. **Focused（焦点を絞る）**:
   - ほとんどのシナリオは「単一のルール」を説明することに焦点を当てるべき。Example Mappingセッションで得られた具体例からシナリオを導き出すと達成しやすい。
   - **アンチパターン**: 説明しているルールが変更されていないのに失敗してしまうシナリオ（例：ローン金利の変更が、支払い日を確認するシナリオを失敗させるなど）。
6. **Brief（簡潔に）**:
   - ほとんどのシナリオを**5行以内**に収めるよう努める。これにより読みやすくなり、推論がはるかに容易になる。
   - **アンチパターン**: プロダクトオーナーに理解されず、価値も見出されないために読まれない長すぎるシナリオ。

## 実装例を通じた仕組みの解説

実際に作成したヘルスチェックAPIのテスト実装を通じて、上記の仕組みを確認します。

### 1. Featureファイル (テストシナリオの定義)

自然言語でテストのシナリオ（期待する振る舞い）を定義します。これが「抽出される文字列」の元になります。

```gherkin title="features/health.feature"
Feature: ヘルスチェック API

  Scenario: GET /health は 200 と ok を返す
    When I send a GET request to "/health"
    Then the response status should be 200
    And the response body should contain "Hi"
```

### 2. Step Definitions (ステップ定義)

Featureの各ステップの文字列にマッチする関数を定義します。ここで実際にバックエンド（`fetch` API）を呼び出し、アサーション（`assert`）を行います。

```typescript title="features/step_definitions/health.steps.ts"
import { When, Then } from "@cucumber/cucumber";
import assert from "node:assert/strict";

let lastResponse: Response | undefined;
const baseUrl = "http://localhost:3100";

When('I send a GET request to {string}', async (path: string) => {
    lastResponse = await fetch(`${baseUrl}${path}`);
});

Then("the response status should be {int}", (statusCode: number) => {
    if (!lastResponse) throw new Error("Response is undefined");
    assert.equal(lastResponse.status, statusCode);
});

Then("the response body should contain {string}", async (expected: string) => {
    if (!lastResponse) throw new Error("Response is undefined");
    const body = await lastResponse.text();
    assert.match(body, new RegExp(expected));
});
```

### 3. テスト対象サーバー

テスト対象となる実際のアプリケーション（Expressサーバー）の実装です。ステップ定義内の `fetch` がこのサーバーにリクエストを送信します。

```typescript title="src/server.ts"
import express from "express";

const app = express();
const port = Number(process.env.PORT ?? 3100);

app.get("/health", (_req, res) => {
  res.status(200).send("Hi, I'm healthy!");
});

app.listen(port, () => {
  console.log(`server started on http://localhost:${port}`);
});
```
