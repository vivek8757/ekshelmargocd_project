resource "kubernetes_manifest" "letsencrypt_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = "admin@vivekkumarsingh.online"
        privateKeySecretRef = {
          name = "letsencrypt-prod-private-key"
        }
        solvers = [
          {
            dns01 = {
              route53 = {
                region       = "us-east-1"
                hostedZoneID = data.aws_route53_zone.primary.zone_id
              }
            }
          }
        ]
      }
    }
  }
  depends_on = [helm_release.cert_manager]
}
