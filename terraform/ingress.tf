resource "kubernetes_manifest" "app_rate_limit_plugin" {
  manifest = {
    apiVersion = "configuration.konghq.com/v1"
    kind       = "KongPlugin"
    metadata = {
      name      = "api-rate-limit"
      namespace = "default"
    }
    plugin = "rate-limiting"
    config = {
      minute = 20
      policy = "local"
    }
  }

  depends_on = [helm_release.kong]
}

resource "kubernetes_manifest" "app_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "eks-demo-ingress"
      namespace = "default"
      annotations = {
        "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
        "external-dns.alpha.kubernetes.io/hostname" = "demoeks.vivekkumarsingh.online"
        "konghq.com/plugins"                        = "api-rate-limit"
      }
    }
    spec = {
      ingressClassName = "kong"
      tls = [
        {
          hosts      = ["demoeks.vivekkumarsingh.online"]
          secretName = "demoeks-tls-secret"
        }
      ]
      rules = [
        {
          host = "demoeks.vivekkumarsingh.online"
          http = {
            paths = [
              {
                path     = "/api"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "backend"
                    port = { number = 5000 }
                  }
                }
              },
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "frontend"
                    port = { number = 80 }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.app_rate_limit_plugin, kubernetes_manifest.argocd_backend_app, kubernetes_manifest.argocd_frontend_app]
}

resource "kubernetes_manifest" "argocd_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "argocd-server-ingress"
      namespace = "argocd"
      annotations = {
        "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
        "external-dns.alpha.kubernetes.io/hostname" = "argocd.vivekkumarsingh.online"
      }
    }
    spec = {
      ingressClassName = "kong"
      tls = [
        {
          hosts      = ["argocd.vivekkumarsingh.online"]
          secretName = "argocd-tls-secret"
        }
      ]
      rules = [
        {
          host = "argocd.vivekkumarsingh.online"
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "argocd-server"
                    port = { number = 80 }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

  depends_on = [helm_release.argocd]
}
