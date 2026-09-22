resource "aws_s3_bucket" "commifra_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "commifra_bucket" {
  bucket = aws_s3_bucket.commifra_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "commifra_bucket" {
  bucket = aws_s3_bucket.commifra_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "commifra_bucket" {
  bucket = aws_s3_bucket.commifra_bucket.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}



data "aws_iam_policy_document" "deny_non_ssl" {
  statement {
    sid    = "DenyNonSSL"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.commifra_bucket.arn,
      "${aws_s3_bucket.commifra_bucket.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "commifra_bucket" {
  bucket = aws_s3_bucket.commifra_bucket.id
  policy = data.aws_iam_policy_document.deny_non_ssl.json
}

resource "aws_s3_bucket_public_access_block" "commifra_bucket" {
  bucket = aws_s3_bucket.commifra_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
