terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.140"
    }
  }
  required_version = ">= 1.5"
}

provider "yandex" {
  service_account_key_file = "key.json"
  cloud_id                 = "b1g39i7hv0f9r41b8vpv"
  folder_id                = "b1g6a8ilj1m6pl5so99m"
  zone                     = "ru-central1-a"
}
