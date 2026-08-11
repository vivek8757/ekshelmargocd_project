resource "helm_release" "kong" {
  name             = "kong"
  repository       = "https://charts.konghq.com"
  chart            = "kong"
  namespace        = "kong"
  create_namespace = true

  set {
    name  = "ingressController.installCRDs"
    value = "false"
  }

  set {
    name  = "proxy.type"
    value = "LoadBalancer"
  }

  set {
    name  = "admin.enabled"
    value = "false"
  }

  depends_on = [aws_eks_node_group.system]
}
