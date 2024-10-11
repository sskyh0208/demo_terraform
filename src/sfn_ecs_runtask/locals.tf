locals {
  env_name         = "test"
  aws_account_id   = data.aws_caller_identity.current.account_id
}