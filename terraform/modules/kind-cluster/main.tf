# ローカル Kubernetes (kind) クラスタを Terraform で作る。
# Phase 3 で手作業 (kind create cluster) で作ったものを、Phase 6 でコード化する。
terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.6"
    }
  }
}

resource "kind_cluster" "this" {
  name           = var.cluster_name
  node_image     = "kindest/node:${var.kubernetes_version}"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      # Ingress Controller (Traefik) の NodePort をホストの 80/443 に公開する
      extra_port_mappings {
        container_port = 30080
        host_port      = var.http_port
      }
      extra_port_mappings {
        container_port = 30443
        host_port      = var.https_port
      }
    }

    # ★ LAB TF-01: worker_count を変えて plan → apply し、`kubectl get nodes` で確認する
    dynamic "node" {
      for_each = range(var.worker_count)
      content {
        role = "worker"
      }
    }
  }
}
