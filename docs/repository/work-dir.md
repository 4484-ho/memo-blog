---
sidebar_position: 1
title: work-dir を置きつつ配下は Git 管理外にする
description: リポジトリに work-dir を残し、配下のファイルだけ追跡しない .gitignore と .gitkeep のパターン
---

## 目的

`work-dir/` のような**ローカル作業用ディレクトリ**を clone 後も存在させたいが、**その中身はバージョン管理したくない**ときの設定メモです。

## .gitignore の書き方

次の 2 行を使います。

```gitignore
work-dir/*
!work-dir/.gitkeep
```

- `work-dir/*` … ディレクトリ直下のエントリを無視する（中身は追跡しない）。
- `!work-dir/.gitkeep` … 例外として `.gitkeep` だけ追跡する。

### `work-dir/` だけだとダメな理由

`work-dir/` のように**ディレクトリ全体を無視**すると、Git はその配下を走査しません。その結果、`!work-dir/.gitkeep` のような**否定パターンが効かない**ことがあります。中身単位で無視する `work-dir/*` にすると、`.gitkeep` への例外が期待どおり働きます。

## リポジトリ側のファイル

`work-dir/.gitkeep` を置き（中身は空でよい）、コミットします。これでディレクトリがリポジトリ上でも存在します。

```bash
git add work-dir/.gitkeep .gitignore
git commit -m "Add work-dir placeholder; ignore contents under work-dir"
```

## 注意

- **すでに `git add` 済みのファイル**は、`.gitignore` を足しただけでは追跡から外れません。誤って追加した場合は `git rm -r --cached work-dir/` などでインデックスから外し、必要なら `.gitkeep` だけ再度追加します。
- ディレクトリ自体をリポジトリに載せる必要がなければ、`.gitkeep` は不要で、`work-dir/` を `.gitignore` に書くだけでも運用できます（clone 後は手で mkdir する想定）。
