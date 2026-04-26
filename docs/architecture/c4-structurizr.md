---
sidebar_position: 1
title: C4モデルとStructurizrの調査メモ
---

## 概要

**Structurizr とは**
C4モデルに基づくソフトウェアアーキテクチャの可視化ツールです。

- **C4モデル**: システムを4階層（Context → Container → Component → Code）で段階的に表現する図法
- DSL（テキスト）でアーキテクチャ図を定義し、ブラウザで閲覧可能
- PlantUML や Mermaid 形式へのエクスポートも可能

**DSL（Domain-Specific Language）とは**
特定の目的に特化した専用言語のことです（例: SQL、HTML、Dockerfile、正規表現など）。

- Structurizr DSL は Structurizr 専用の独自記法であり、他ツールではそのまま使えません。
- ただし、C4モデル自体は共通概念であるため、PlantUML や Mermaid でも C4図を描くことは可能です。

## docker-compose の内容

Structurizr をローカルで起動するための `docker-compose.yml` です。

以前はローカルプレビュー用に `structurizr/lite` という軽量イメージが提供されていましたが、現在は廃止（非推奨）となっています。
そのため、メインの統合イメージである `structurizr/structurizr:latest` を使用し、起動時に `command: local` を指定しています。
これにより、サーバー版ではなく「手元のファイルをプレビューするためのローカルモード（旧Lite版と同等）」として動作します。

```yaml
# http://localhost:8080

services:
  structurizr:
    image: structurizr/structurizr:latest
    command: local
    ports:
      - "8080:8080"
    volumes:
      - .:/usr/local/structurizr
    environment:
      - STRUCTURIZR_WORKSPACE_FILENAME=workspace
```

## structurizr.sh の内容

Structurizr CLI を Docker 経由で実行するためのラッパースクリプトです。
ローカル環境に Java や Structurizr CLI 本体をインストールすることなく、DSL の構文チェックやエクスポート（PlantUML / Mermaid 等）を行うことができます。

```bash
#!/bin/bash

# Docker を使って Structurizr CLI を実行するラッパースクリプト
# ローカルに Java や CLI をインストールせずに実行可能です
docker run --rm -v "$(pwd):/usr/local/structurizr" structurizr/structurizr:latest "$@"
```

### 実行の仕組み（なぜ Makefile のコマンドが動くのか）

Makefile では `CLI_SCRIPT := ./structurizr.sh` と定義し、例えば `validate` コマンドでは以下のように呼び出しています。

```bash
./structurizr.sh validate -workspace workspace.dsl
```

この時、`structurizr.sh` 内部の `$@`（シェルスクリプトに渡されたすべての引数）が、そのまま Docker コンテナ内の `structurizr/structurizr` イメージに渡されます。

つまり、シェルスクリプトを実行すると、裏側では以下の Docker コマンドが実行されています。

```bash
docker run --rm -v "$(pwd):/usr/local/structurizr" structurizr/structurizr:latest validate -workspace workspace.dsl
```

**ポイント:**
1. **`-v "$(pwd):/usr/local/structurizr"`**: 現在のディレクトリ（`work-dir/c4`）をコンテナ内の `/usr/local/structurizr` にマウントしています。これにより、コンテナ内の Structurizr CLI がローカルの `workspace.dsl` を読み書きできるようになります。
2. **`"$@"`**: Makefile から渡された `validate -workspace workspace.dsl` などの引数を、そのままコンテナ内の CLI コマンドの引数として展開します。
3. **`--rm`**: 実行が終わったら即座にコンテナを破棄するため、ゴミが残りません。

この仕組みにより、ローカル環境を汚すことなく（JavaやCLIツールをインストールすることなく）、あたかもローカルに `structurizr` コマンドが存在するかのように Makefile から透過的に呼び出せるようになっています。

## Makefile の内容

DSLの構文チェックや、PlantUML / Mermaid 形式へのエクスポートを自動化するための `Makefile` 全体です。

```makefile
.PHONY: serve stop validate export-plantuml export-mermaid clean clean-all all help

# Structurizr CLI (Local mode)
CLI_SCRIPT := ./structurizr.sh

# ディレクトリ
OUTPUT_DIR := ./exports
WORKSPACE := workspace.dsl

help: ## ヘルプを表示
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

serve: ## Structurizr Local をバックグラウンドで起動
	docker-compose up -d

stop: ## Structurizr Local を停止
	docker-compose down

validate: ## DSL ファイルの構文チェック
	$(CLI_SCRIPT) validate -workspace $(WORKSPACE)

export-plantuml: ## PlantUML (C4) 形式でエクスポート
	@mkdir -p $(OUTPUT_DIR)
	$(CLI_SCRIPT) export -workspace $(WORKSPACE) -format plantuml/c4plantuml -output $(OUTPUT_DIR)

export-mermaid: ## Mermaid 形式でエクスポート
	@mkdir -p $(OUTPUT_DIR)/mermaid
	$(CLI_SCRIPT) export -workspace $(WORKSPACE) -format mermaid -output $(OUTPUT_DIR)/mermaid

clean: ## 生成ファイルを削除
	rm -rf $(OUTPUT_DIR)

clean-all: ## 生成ファイルを全て削除
	rm -rf $(OUTPUT_DIR)

all: validate export-plantuml export-mermaid ## 検証 & エクスポート
```

## 参考ファイル

実際に使用している設定ファイルや出力結果は以下から参照・ダウンロードできます。

- [workspace.dsl](pathname:///c4/workspace.dsl)
- [docker-compose.yml](pathname:///c4/docker-compose.yml)
- [structurizr.sh](pathname:///c4/structurizr.sh)
- [Makefile](pathname:///c4/Makefile)
- [エクスポートされたPlantUML図](pathname:///c4/exports/structurizr-SystemContext.puml)

