---
sidebar_position: 1
title: Docusaurus で Mermaid を使う
description: Docusaurus で Mermaid 図を有効化する最小手順
---

## 手順

まず、Mermaid テーマを追加します。

```bash
pnpm add @docusaurus/theme-mermaid
```

次に `docusaurus.config.ts` で Mermaid を有効化します。

```ts
import { themes as prismThemes } from 'prism-react-renderer';
import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  // その他設定 ...
  markdown: {
    mermaid: true,
  },
  themes: ['@docusaurus/theme-mermaid'],
  // その他設定 ...
};

export default config;
```

## メモ

- `markdown.mermaid: true` が未設定だと Mermaid ブロックは有効化されません。
- `themes` に `@docusaurus/theme-mermaid` がない場合も描画されません。
