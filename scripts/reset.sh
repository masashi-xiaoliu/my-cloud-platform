#!/usr/bin/env bash
# 実験で壊した設定を「正常な状態（git tag: lab-baseline）」に戻す。
#   使い方: ./scripts/reset.sh [dev|staging|prod|all]
# 戻した後は通常どおり commit → PR → merge で反映する（GitOps なので Git が正）。
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="${1:-dev}"
git rev-parse -q --verify lab-baseline >/dev/null || { echo "tag lab-baseline がありません（setup 手順参照）"; exit 1; }
if [ "$TARGET" = all ]; then paths="kubernetes"; else paths="kubernetes/overlays/$TARGET"; fi
git checkout lab-baseline -- $paths
git rm -q --cached kubernetes/overlays/*/patch-chaos.yaml 2>/dev/null || true
rm -f kubernetes/overlays/*/patch-chaos.yaml
rm -f .chaos/last
git status --short
echo "✅ $paths を lab-baseline の状態に戻しました。commit → PR → merge で反映してください。"
