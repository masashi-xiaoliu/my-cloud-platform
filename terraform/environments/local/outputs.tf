output "kubeconfig_path" {
  value = module.cluster.kubeconfig_path
}

output "urls" {
  value = merge(module.addons.urls, {
    hello_dev     = "http://hello-dev.localtest.me"
    hello_staging = "http://hello-staging.localtest.me"
    hello_prod    = "http://hello.localtest.me"
  })
}

output "argocd_initial_password_command" {
  value = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
}
