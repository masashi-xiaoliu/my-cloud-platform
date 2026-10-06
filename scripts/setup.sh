#!/usr/bin/env bash
# 初回セットアップ: 前提ツールの確認と、リポジトリ内のプレースホルダ置換。
#   使い方: ./scripts/setup.sh <your-github-username>
set -euo pipefail
cd "$(dirname "$0")/.."

GH_USER="${1:-}"
if [ -z "$GH_USER" ]; then
  echo "usage: $0 <your-github-username>"; exit 1
fi
GH_USER_LC=$(echo "$GH_USER" | tr '[:upper:]' '[:lower:]')

echo "== 1. 前提ツールの確認 =="
missing=0
for cmd in git docker go kubectl kind helm kustomize terraform; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  ✅ %-10s %s\n" "$cmd" "$($cmd version --short 2>/dev/null | head -1 || $cmd --version 2>/dev/null | head -1 || true)"
  else
    printf "  ❌ %-10s 未インストール（docs/phases/phase-00-setup.md 参照）\n" "$cmd"; missing=1
  fi
done
command -v gcloud >/dev/null 2>&1 && echo "  ✅ gcloud (Phase 7 で使用)" || echo "  ⚪ gcloud (Phase 7 で必要。今は不要)"
docker info >/dev/null 2>&1 || { echo "  ❌ Docker が起動していません"; missing=1; }

echo "== 2. プレースホルダ YOUR_GITHUB_USER → $GH_USER_LC =="
files=$(grep -rl "YOUR_GITHUB_USER" --exclude-dir=.git --exclude=setup.sh . || true)
for f in $files; do
  sed -i.bak "s/YOUR_GITHUB_USER/$GH_USER_LC/g" "$f" && rm -f "$f.bak"
  echo "  updated: $f"
done

echo "== 3. ローカル用ディレクトリ =="
mkdir -p .chaos

cat <<MSG

次のステップ:
  git add -A && git commit -m "chore: set github user" && git push
  git tag lab-baseline && git push origin lab-baseline   # ← reset.sh が戻る「正常な状態」の目印
  → README の「7. Getting Started」の続きへ
MSG
[ $missing -eq 0 ] || { echo "⚠ 足りないツールがあります。インストール後に再実行してください。"; exit 1; }
