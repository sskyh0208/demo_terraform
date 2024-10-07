variable "aws_region" {
  type        = string
  description = "リソースを作成するリージョン"
  default     = "ap-northeast-1"
}

variable "product_name" {
  type        = string
  description = "リソース名に使用される、プロダクト名(3~4文字推奨)"
  default     = "demo"
}

variable "root_domain_name" {
  type        = string
  description = "ドメイン名"
}