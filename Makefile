# よく使う操作のショートカット。中身のコマンドも読んで、何をしているか理解すること。
NS ?= mcp-dev
TAG ?= v0.0.0-local

.PHONY: help test run docker-run kind-up local-image local-deploy status load chaos hint reveal reset tf-local-plan tf-local-apply

help:            ## このヘルプ
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-16s %s\n", $$1, $$2}'

test:            ## Phase 1: Go のテスト
	cd apps/hello-go && go test -race -cover ./...

run:             ## Phase 1: Go をそのまま起動 (http://localhost:8080)
	cd apps/hello-go && APP_MESSAGE="Hello from My Cloud Platform" LOG_LEVEL=debug go run .

docker-run:      ## Phase 2: docker compose で起動
	docker compose up --build

kind-up:         ## Phase 3: kind クラスタ + Traefik を手作業で作る
	./scripts/cluster-up.sh

local-image:     ## Phase 3: イメージをビルドして kind に読み込む
	docker build --build-arg VERSION=$(TAG) -t hello-go:$(TAG) apps/hello-go
	kind load docker-image hello-go:$(TAG) --name my-cloud-platform

local-deploy: local-image ## Phase 3: overlays/local を kubectl apply
	kubectl apply -k kubernetes/overlays/local
	kubectl -n mcp-local rollout status deploy/hello-go
	curl -s http://hello-local.localtest.me/

status:          ## 現在の状態を俯瞰 (NS=mcp-dev)
	./scripts/status.sh $(NS)

load:            ## 負荷を発生 (NS=mcp-dev)
	./scripts/load.sh $(NS)

chaos:           ## dev にランダムな障害を仕込む（ブラインド訓練）
	python3 scripts/chaos.py inject

hint:            ## 障害訓練のヒント
	python3 scripts/chaos.py hint

reveal:          ## 障害訓練の答え合わせ
	python3 scripts/chaos.py reveal

reset:           ## dev overlay を lab-baseline に戻す
	./scripts/reset.sh dev

tf-local-plan:   ## Phase 6: terraform plan (local)
	terraform -chdir=terraform/environments/local init -upgrade
	terraform -chdir=terraform/environments/local plan

tf-local-apply:  ## Phase 6: terraform apply (local)
	terraform -chdir=terraform/environments/local apply
