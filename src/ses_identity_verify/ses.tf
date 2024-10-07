data "aws_route53_zone" "host" {
  name         = local.root_domain_name
}

resource "aws_ses_domain_identity" "system" {
  domain = local.domain_name
}

resource "aws_ses_domain_dkim" "system" {
  domain = aws_ses_domain_identity.system.domain
}

resource "aws_ses_domain_mail_from" "system" {
  domain           = aws_ses_domain_identity.system.domain
  mail_from_domain = "mail.${local.domain_name}"
}

resource "aws_ses_domain_identity_verification" "system" {
  depends_on = [ aws_route53_record.ses_domain_mail_txt, aws_route53_record.ses_mail_from_mx, aws_route53_record.dmarc ]
  domain = aws_ses_domain_identity.system.domain
}

# DKIM CNAME
resource "aws_route53_record" "dkim_record" {
  count   = 3
  zone_id = data.aws_route53_zone.host.zone_id
  name    = "${element(aws_ses_domain_dkim.system.dkim_tokens, count.index)}._domainkey.${local.domain_name}"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.system.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

# SPF for MAIL FROMドメイン
resource "aws_route53_record" "ses_domain_mail_txt" {
  zone_id = data.aws_route53_zone.host.zone_id
  name    = "mail.${local.domain_name}"
  type    = "TXT"
  ttl     = "600"
  records = [
    "v=spf1 include:amazonses.com -all"
  ]
}

# MX record for MAIL FROMドメイン
resource "aws_route53_record" "ses_mail_from_mx" {
  zone_id = data.aws_route53_zone.host.zone_id
  name    = "mail.${local.domain_name}"
  type    = "MX"
  ttl     = "600"
  records = [
    "10 feedback-smtp.${var.aws_region}.amazonses.com"
  ]
}

# DMARC
resource "aws_route53_record" "dmarc" {
  zone_id = data.aws_route53_zone.host.zone_id
  name    = "_dmarc.${local.domain_name}"
  type    = "TXT"
  ttl     = "600"
  records = [
    "v=DMARC1;p=none;"
  ]
}