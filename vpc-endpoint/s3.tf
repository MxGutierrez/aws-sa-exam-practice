resource "aws_s3_bucket" "bucket" {
  bucket = "${local.project_name}-bucket"
  acl    = "private"

  tags = {
    Name = "${local.project_name}-bucket"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
}

// Restrict non vpc endpoint access
resource "aws_s3_bucket_policy" "deny_non_vpce_access" {
  bucket = aws_s3_bucket.bucket.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Access-to-specific-VPCE-only",
      "Principal": {
        "AWS": "${aws_iam_role.s3.arn}"
      },
      "Action": "s3:*",
      "Effect": "Deny",
      "Resource": [
        "${aws_s3_bucket.bucket.arn}",
        "${aws_s3_bucket.bucket.arn}/*"
      ],
      "Condition": {
        "StringNotEquals": {
          "aws:SourceVpce": "${aws_vpc_endpoint.s3.id}"
        }
      }
    }
  ]
}
POLICY
}
