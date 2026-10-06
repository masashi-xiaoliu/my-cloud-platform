#!/usr/bin/env python3
"""ブラインド障害訓練（Incident Response Lab 用）。

dev overlay にランダムな「設定ミス」を仕込む。何を仕込んだかは表示しない。
あなたは commit → PR → merge して、症状から原因を突き止め、修正して復旧する。

  python3 scripts/chaos.py list            # シナリオ一覧（症状のみ。答えは出ない）
  python3 scripts/chaos.py inject [ID]     # ID 省略でランダム
  python3 scripts/chaos.py hint            # ヒントを 1 つずつ表示
  python3 scripts/chaos.py reveal          # 答え合わせ（調査が終わってから！）
  ./scripts/reset.sh dev                   # 正常状態に戻す
"""
import json
import random
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEV = ROOT / "kubernetes/overlays/dev"
STATE = ROOT / ".chaos/last"


def set_env(key, value):
    p = DEV / "config.env"
    s = p.read_text()
    s = re.sub(rf"^{key}=.*$", f"{key}={value}", s, flags=re.M)
    p.write_text(s)


def set_secret(key, value):
    p = DEV / "secret.env"
    s = p.read_text()
    s = re.sub(rf"^{key}=.*$", f"{key}={value}", s, flags=re.M)
    p.write_text(s)


def add_patch(kind, name, ops):
    """kustomization.yaml に JSON6902 パッチ (patch-chaos.yaml) を追加する。"""
    pf = DEV / "patch-chaos.yaml"
    lines = []
    for op in ops:
        lines.append(f"- op: {op[0]}\n  path: {op[1]}\n  value: {json.dumps(op[2])}")
    pf.write_text("\n".join(lines) + "\n")
    k = DEV / "kustomization.yaml"
    s = k.read_text()
    if "patch-chaos.yaml" not in s:
        # overlay 自身の patch より「後」に適用されるよう、patches リストの末尾に追加する
        anchor = "  - path: patch-ingress.yaml\n    target:\n      kind: Ingress\n      name: hello-go\n"
        s = s.replace(
            anchor,
            anchor + f"  - path: patch-chaos.yaml\n    target:\n      kind: {kind}\n      name: {name}\n",
            1,
        )
        k.write_text(s)


def set_tag(tag):
    k = DEV / "kustomization.yaml"
    k.write_text(re.sub(r"newTag: .*", f"newTag: {tag}", k.read_text()))


C = "/spec/template/spec/containers/0"
SCENARIOS = {
    "I01": dict(symptom="Pod が起動と終了を繰り返している気がする",
                inject=lambda: set_env("APP_MESSAGE", ""),
                hints=["kubectl get pods の STATUS と RESTARTS を見る", "kubectl logs <pod> --previous を見る", "ConfigMap (config.env) を見直す"],
                answer="APP_MESSAGE が空 → アプリが設定エラーで exit 1 → CrashLoopBackOff"),
    "I02": dict(symptom="新しい Pod がいつまでも起動しない",
                inject=lambda: set_tag("v999.0.0"),
                hints=["kubectl get pods の STATUS を見る", "kubectl describe pod の Events を見る", "image の tag は Registry に存在する?"],
                answer="存在しない image tag v999.0.0 → ErrImagePull / ImagePullBackOff"),
    "I03": dict(symptom="Pod は Running なのにブラウザでアクセスすると 502/503/接続エラー",
                inject=lambda: add_patch("Service", "hello-go", [("replace", "/spec/ports/0/targetPort", 9090)]),
                hints=["kubectl get endpointslices でエンドポイントを確認", "kubectl describe svc hello-go の TargetPort を見る", "Pod が実際に待ち受けているポートは?"],
                answer="Service の targetPort が 9090 → Pod は 8080 で待受 → 接続拒否"),
    "I04": dict(symptom="Pod は Running なのにアクセスできない（Endpoint がない?）",
                inject=lambda: add_patch("Service", "hello-go", [("replace", "/spec/selector/app.kubernetes.io~1name", "hello-goo")]),
                hints=["kubectl get endpointslices を見る", "kubectl get pods --show-labels と Service の selector を比べる"],
                answer="Service の selector が hello-goo → どの Pod にもマッチせず Endpoint が空"),
    "I05": dict(symptom="Pod が Running なのに READY が 0/1 のまま",
                inject=lambda: add_patch("Deployment", "hello-go", [("replace", f"{C}/readinessProbe/httpGet/path", "/ready")]),
                hints=["kubectl describe pod の Events に Readiness probe failed がある?", "probe の path をアプリのエンドポイントと比べる"],
                answer="readinessProbe の path が /ready（正しくは /readyz）→ 404 で NotReady"),
    "I06": dict(symptom="デプロイ後、Pod が起動直後に落ちる",
                inject=lambda: (set_env("REQUIRE_API_KEY", "true"), set_secret("API_KEY", "")),
                hints=["kubectl logs <pod> --previous", "エラーメッセージに出てくるキー名を Secret で探す"],
                answer="REQUIRE_API_KEY=true なのに Secret の API_KEY が空 → 起動時バリデーションで exit 1"),
    "I08": dict(symptom="新しい Pod が Pending のまま",
                inject=lambda: add_patch("Deployment", "hello-go", [("replace", f"{C}/resources/requests/cpu", "64"), ("replace", f"{C}/resources/limits/cpu", "64")]),
                hints=["kubectl describe pod の Events（FailedScheduling）", "kubectl describe nodes の Allocatable と比べる"],
                answer="CPU requests 64 コア → どのノードにも収まらず Insufficient cpu で Pending"),
    "I09": dict(symptom="Pod の RESTARTS が増え続ける。ログには何も出ていない",
                inject=lambda: (set_env("MEMORY_BALLAST_MB", "100"), add_patch("Deployment", "hello-go", [("replace", f"{C}/resources/limits/memory", "48Mi")])),
                hints=["kubectl describe pod の Last State: Terminated の Reason", "memory limit と MEMORY_BALLAST_MB を比べる"],
                answer="起動時に 100MB 確保するが memory limit 48Mi → OOMKilled (exit 137)"),
    "I10": dict(symptom="http://hello-dev.localtest.me が 404 になった（Pod は正常）",
                inject=lambda: add_patch("Ingress", "hello-go", [("replace", "/spec/ingressClassName", "nginx")]),
                hints=["kubectl get ingress の CLASS / ADDRESS を見る", "kubectl get ingressclass で存在するクラスを確認"],
                answer="ingressClassName が nginx（存在しない）→ Traefik が Ingress を無視 → 404"),
    "I11": dict(symptom="Pod が定期的に再起動される。アクセスは時々成功する",
                inject=lambda: add_patch("Deployment", "hello-go", [("replace", f"{C}/livenessProbe/httpGet/port", 9999)]),
                hints=["kubectl describe pod の Events に Liveness probe failed", "probe の port を確認"],
                answer="livenessProbe の port が 9999 → 失敗が続き kubelet が再起動し続ける"),
    "I12": dict(symptom="Pod が起動しない（CrashLoopBackOff）。直前に「ログを詳しくしたい」という変更があった",
                inject=lambda: set_env("LOG_LEVEL", "verbose"),
                hints=["kubectl logs --previous", "LOG_LEVEL に許される値は?"],
                answer="LOG_LEVEL=verbose は不正値 → 設定バリデーションで exit 1"),
    "I07": dict(symptom="一部のリクエストだけ 500 が返る（Grafana の Error rate が上昇）",
                inject=lambda: set_env("ERROR_RATE", "40"),
                hints=["kubectl logs で level=ERROR のログを探す", "Grafana の Error rate / Requests by status code", "/info で現在の設定を確認"],
                answer="ERROR_RATE=40 → アプリが 40% の確率で 500 を返す（アプリ設定起因の障害）"),
}


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        for k, v in sorted(SCENARIOS.items()):
            print(f"{k}: {v['symptom']}")
    elif cmd == "inject":
        sid = sys.argv[2] if len(sys.argv) > 2 else random.choice(list(SCENARIOS))
        SCENARIOS[sid]["inject"]()
        STATE.parent.mkdir(exist_ok=True)
        STATE.write_text(json.dumps({"id": sid, "hint": 0}))
        blind = len(sys.argv) <= 2
        print("💥 障害を仕込みました。" + ("（シナリオは秘密）" if blind else f"（{sid}）"))
        print("次: git diff を見ないで（見たら訓練にならない）commit → PR → merge し、症状から調査してください。")
        print("    調査の記録は docs/experiments/ のテンプレートに残しましょう。")
    elif cmd == "hint":
        st = json.loads(STATE.read_text())
        hints = SCENARIOS[st["id"]]["hints"]
        i = st["hint"]
        print(f"Hint {i + 1}/{len(hints)}: {hints[min(i, len(hints) - 1)]}")
        st["hint"] = i + 1
        STATE.write_text(json.dumps(st))
    elif cmd == "reveal":
        st = json.loads(STATE.read_text())
        print(f"{st['id']}: {SCENARIOS[st['id']]['answer']}")
        print(f"詳細: docs/labs/incident/ の {st['id']} を参照 / 復旧: ./scripts/reset.sh dev")
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
