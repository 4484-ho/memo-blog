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