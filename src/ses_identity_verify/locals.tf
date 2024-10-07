locals {
  env_name         = "test"

  root_domain_name = var.root_domain_name
  domain_name      = "${local.env_name}.${local.root_domain_name}"
}