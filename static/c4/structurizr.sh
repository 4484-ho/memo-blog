#!/bin/bash

# Docker を使って Structurizr CLI を実行するラッパースクリプト
# ローカルに Java や CLI をインストールせずに実行可能です
docker run --rm -v "$(pwd):/usr/local/structurizr" structurizr/structurizr:latest "$@"