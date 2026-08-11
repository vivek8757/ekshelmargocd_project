data "http" "docdb_ca_bundle" {
  url = "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem"
}

resource "kubernetes_secret" "docdb_credentials" {
  metadata {
    name      = "docdb-credentials"
    namespace = "default"
  }

  data = {
    "mongodb-uri"       = "mongodb://${var.docdb_master_username}:${var.docdb_master_password}@${aws_docdb_cluster.main.endpoint}:27017/eks-demo?tls=true&tlsCAFile=/etc/ssl/certs/global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false&authMechanism=SCRAM-SHA-1"
    "global-bundle.pem" = data.http.docdb_ca_bundle.response_body
  }

  type = "Opaque"
}
