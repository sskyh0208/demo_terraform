resource "aws_iam_role" "role_job_python_shell" {
  name                = "${var.product_name}-${local.env_name}-role-job-python-shell"
  assume_role_policy  = data.aws_iam_policy_document.assume_job_python_shell.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole",
    aws_iam_policy.custom_job_python_shell.arn
  ]
}

data "aws_iam_policy_document" "assume_job_python_shell" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "custom_job_python_shell" {
  name        = "${var.product_name}-${local.env_name}-custom-policy-job-python-shell"
  description = "Custom policy for Glue job (Python shell)"
  path        = "/"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListObjects"
        ]
        Resource = [
          aws_s3_bucket.bucket_glue.arn,
          "${aws_s3_bucket.bucket_glue.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket" "bucket_glue" {
  bucket = "${var.product_name}-${local.env_name}-bucket-glue"

  force_destroy = true
}

resource "null_resource" "upload_job_python_shell" {
  depends_on = [aws_s3_bucket.bucket_glue]
  triggers = {
    code_diff = filebase64("${path.module}/glue/job_python_shell/script.py")
  }

  provisioner "local-exec" {
    command = "aws --profile ${local.env_name} s3 cp ${path.module}/glue s3://${aws_s3_bucket.bucket_glue.bucket} --recursive"
  }
}

resource "aws_glue_job" "job_python_shell" {
  depends_on = [null_resource.upload_job_python_shell]
  name = "${var.product_name}-${local.env_name}-job-python-shell"
  role_arn = aws_iam_role.role_job_python_shell.arn

  command {
    name = "pythonshell"
    python_version = "3.9"
    script_location = "s3://${aws_s3_bucket.bucket_glue.bucket}/job_python_shell/script.py"
  }
}