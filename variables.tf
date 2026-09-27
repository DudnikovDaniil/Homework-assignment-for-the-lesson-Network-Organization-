variable "zone" {
  description = "Зона доступности"
  type        = string
  default     = "ru-central1-a"
}

variable "folder_id" {
  description = "ID каталога"
  type        = string
  default     = "b1g6a8ilj1m6pl5so99m"
}

variable "cloud_id" {
  description = "ID облака"
  type        = string
  default     = "b1g39i7hv0f9r41b8vpv"
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ"
  type        = string
}

variable "nat_image_id" {
  description = "Образ для NAT-инстанса"
  type        = string
  default     = "fd80mrhj8fl2oe87o4e1"
}

variable "ubuntu_image_id" {
  description = "Образ Ubuntu 22.04 LTS"
  type        = string
  default     = "fd8vmcue7aajpmeo39kk"
}

variable "public_subnet_cidr" {
  type    = string
  default = "192.168.10.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "192.168.20.0/24"
}
