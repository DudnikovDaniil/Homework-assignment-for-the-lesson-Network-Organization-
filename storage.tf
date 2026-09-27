# Бакет Object Storage с шифрованием через KMS
resource "yandex_storage_bucket" "crocodile" {
  bucket        = var.bucket_name
  force_destroy = true

  # Шифрование объектов по умолчанию через KMS
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.crocodile_key.id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

# Публичный доступ к бакету на чтение
resource "yandex_storage_bucket_grant" "crocodile_grant" {
  bucket = yandex_storage_bucket.crocodile.bucket

  grant {
    type        = "Group"
    permissions = ["READ"]
    uri         = "http://acs.amazonaws.com/groups/global/AllUsers"
  }
}

# Загрузка картинки в бакет
resource "yandex_storage_object" "crocodile_image" {
  bucket       = yandex_storage_bucket.crocodile.bucket
  key          = "crocodile.jpg"
  source       = "crocodile.jpg"
  acl          = "public-read"
  content_type = "image/jpeg"

  depends_on = [yandex_storage_bucket_grant.crocodile_grant]
}
