resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }
  depends_on = [aws_eks_node_group.system]
}
