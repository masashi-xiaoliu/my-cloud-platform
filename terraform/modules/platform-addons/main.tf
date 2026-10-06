# 80% 共通基盤のクラスタアドオン。kind でも GKE でも同じモジュールを使う。
#   - Traefik       : Ingress Controller
#   - Argo CD       : GitOps
#   - metrics-server: kubectl top / HPA 用（GKE は標準搭載なので無効化）
#   - kube-prometheus-stack: Prometheus + Grafana + Alertmanager（enable_monitoring）
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

locals {
  admin_hosts = {
    argocd     = "argocd.${var.base_domain}"
    grafana    = "grafana.${var.base_domain}"
    prometheus = "prometheus.${var.base_domain}"
  }
}

resource "helm_release" "traefik" {
  name             = "traefik"
  namespace        = "traefik"
  create_namespace = true
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = var.chart_versions.traefik

  values = concat(
    [yamlencode({
      ingressClass = { enabled = true, isDefaultClass = true, name = "traefik" }
      service      = { type = var.ingress_service_type }
    })],
    # kind: NodePort を固定し、kind の extraPortMappings (30080/30443 → 80/443) と対応させる
    var.ingress_service_type == "NodePort" ? [yamlencode({
      ports = {
        web       = { nodePort = 30080 }
        websecure = { nodePort = 30443 }
      }
    })] : [],
  )
}

resource "helm_release" "metrics_server" {
  count      = var.enable_metrics_server ? 1 : 0
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_versions.metrics_server

  # kind の kubelet は自己署名証明書のため検証をスキップする（ローカル限定の設定）
  values = [yamlencode({ args = ["--kubelet-insecure-tls"] })]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_versions.argocd

  values = [yamlencode({
    configs = {
      params = { "server.insecure" = true } # TLS は Ingress 側で扱う（ローカルは HTTP）
      cm = {
        # ★ LAB C08: Git をポーリングする間隔。短くすると反映が早いが GitHub API を多く叩く
        "timeout.reconciliation" = var.argocd_reconciliation_timeout
      }
    }
    server = {
      ingress = {
        enabled          = var.expose_admin_uis
        ingressClassName = "traefik"
        hostname         = local.admin_hosts.argocd
      }
    }
  })]

  depends_on = [helm_release.traefik]
}

resource "helm_release" "kube_prometheus_stack" {
  count            = var.enable_monitoring ? 1 : 0
  name             = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_versions.kube_prometheus_stack
  timeout          = 900

  values = [
    yamlencode({
      prometheus = {
        ingress = {
          enabled          = var.expose_admin_uis
          ingressClassName = "traefik"
          hosts            = [local.admin_hosts.prometheus]
        }
        prometheusSpec = {
          # ラベルに関係なく全 Namespace の ServiceMonitor / PrometheusRule を拾う
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          ruleSelectorNilUsesHelmValues           = false
        }
      }
      grafana = {
        adminPassword = var.grafana_admin_password
        ingress = {
          enabled          = var.expose_admin_uis
          ingressClassName = "traefik"
          hosts            = [local.admin_hosts.grafana]
        }
        sidecar = {
          dashboards = { enabled = true, label = "grafana_dashboard", searchNamespace = "ALL" }
        }
      }
    }),
    # 学習者が調整する値（保存期間・スクレイプ間隔・リソース）は別ファイルに分離
    file(var.monitoring_values_file),
  ]

  depends_on = [helm_release.traefik]
}
