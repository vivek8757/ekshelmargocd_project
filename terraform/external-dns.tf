resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns"
  chart            = "external-dns"
  namespace        = "external-dns"
  create_namespace = true

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "aws.zoneType"
    value = "public"
  }

  set {
    name  = "domainFilters[0]"
    value = "vivekkumarsingh.online"
  }

  set {
    name  = "txtOwnerId"
    value = "eks-demo-cluster-owner"
  }

  set {
    name  = "policy"
    value = "upsert-only"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_dns.arn
  }

  set {
    name  = "extraArgs[0]"
    value = "--zone-id-filter=${data.aws_route53_zone.primary.zone_id}"
  }

  depends_on = [aws_eks_node_group.system]
}
