resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "attachments" {
  bucket = "${var.project_name}-attachments-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "Task Attachments"
  }
}

resource "aws_s3_bucket" "deploy" {
  bucket = "${var.project_name}-deploy-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "App Deployment Bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "attachments_ownership" {
  bucket = aws_s3_bucket.attachments.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
