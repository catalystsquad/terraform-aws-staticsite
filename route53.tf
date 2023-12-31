locals {
  hosted_zone_name = var.hosted_zone_name != "" ? var.hosted_zone_name : var.website_domain
}

data "aws_route53_zone" "hosted_zone" {
  count    = (!var.create_hosted_zone && (var.create_acm_certificate || var.create_site_records)) ? 1 : 0
  provider = aws.main
  name     = local.hosted_zone_name
}

resource "aws_route53_zone" "hosted_zone" {
  count    = (var.create_hosted_zone && (var.create_acm_certificate || var.create_site_records)) ? 1 : 0
  provider = aws.main
  name     = local.hosted_zone_name
  tags     = var.tags
}

locals {
  existing_hosted_zone_id = (
    (!var.create_hosted_zone && !var.create_acm_certificate && !var.create_site_records) ?
    "" : data.aws_route53_zone.hosted_zone[0].id
  )
  hosted_zone_id = var.create_hosted_zone ? aws_route53_zone.hosted_zone[0].id : local.existing_hosted_zone_id

  dns_records = concat([var.website_domain], var.extra_cloudfront_aliases)
  dns_records_to_create = var.create_site_records ? {
    for record in local.dns_records : record => {
      name = record
    }
  } : {}
}

resource "aws_route53_record" "website" {
  for_each = local.dns_records_to_create
  provider = aws.main
  zone_id  = local.hosted_zone_id
  name     = each.value.name
  type     = "A"
  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}
