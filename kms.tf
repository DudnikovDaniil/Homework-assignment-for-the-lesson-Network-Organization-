# KMS-ключ для шифрования бакета
resource "yandex_kms_symmetric_key" "crocodile_key" {
  name              = "crocodile-bucket-key"
  description       = "Ключ для шифрования содержимого бакета с крокодилом"
  default_algorithm = "AES_128"
  rotation_period   = "8760h"  # 1 год

  lifecycle {
    prevent_destroy = false
  }
}

