---
sidebar_position: 1
title: AlloyDB / PostgreSQL で ENUMの値を確認する
description: AlloyDB Studio（クエリ入力画面）や PostgreSQL で ENUM 型の定義値一覧を取得するためのSQL
---

## 概要

AlloyDB Studio（Google Cloud コンソールのクエリ入力画面）で、ENUM 型の定義内容（設定されている値のリスト）を確認するには、PostgreSQL のシステムカタログ（`pg_enum` など）を参照するのが確実です。

標準的なテーブル定義の表示（`\\d` コマンド相当）では詳細が見えない場合があるため、以下の SQL をクエリとして実行してください。

## 特定の ENUM 型の値を表示する

たとえば `user_status` という ENUM 型がどのような値を持っているかを確認する場合です。

```sql
SELECT
    n.nspname AS schema_name,
    t.typname AS enum_name,
    e.enumlabel AS enum_value
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
WHERE t.typname = 'user_status' -- ここに確認したい型名を入力
ORDER BY e.enumsortorder;
```

## データベース内のすべての ENUM を表示する

どの ENUM が定義されているかを一括で把握したい場合は、上記の `WHERE` 句を外して実行します。

```sql
SELECT
    t.typname AS enum_name,
    string_agg(e.enumlabel, ', ' ORDER BY e.enumsortorder) AS values
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
GROUP BY t.typname;
```

## 補足: なぜこれが必要か

AlloyDB（PostgreSQL）において ENUM は「ユーザー定義型」として扱われます。そのため、`information_schema.columns` などの標準ビューを確認しても、データ型が `USER-DEFINED` と表示されるだけで、具体的な選択肢（例: `'active'`, `'inactive'` など）までは表示されないことが多いです。

このような場合に、`pg_type` と `pg_enum` を結びつけて参照する上記の方法が有効です。

