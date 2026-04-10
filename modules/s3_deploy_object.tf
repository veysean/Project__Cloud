data "archive_file" "app_zip" {
  type        = "zip"
  source_dir  = "${path.root}/app"
  output_path = "${path.module}/app.zip"
}

resource "aws_s3_object" "app_zip_upload" {
  bucket = aws_s3_bucket.deploy.bucket
  key    = "app.zip"
  source = data.archive_file.app_zip.output_path
  etag   = filemd5(data.archive_file.app_zip.output_path)
}
