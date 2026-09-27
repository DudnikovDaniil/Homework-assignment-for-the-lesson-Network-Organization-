# Бакет Object Storage
resource "yandex_storage_bucket" "crocodile" {
  bucket        = var.bucket_name
  force_destroy = true
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
