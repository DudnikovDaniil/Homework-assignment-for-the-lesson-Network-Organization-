output "public_vm_ip" {
  value       = yandex_compute_instance.public_vm.network_interface[0].nat_ip_address
  description = "Публичный IP публичной ВМ"
}

output "private_vm_ip" {
  value       = yandex_compute_instance.private_vm.network_interface[0].ip_address
  description = "Внутренний IP приватной ВМ"
}

output "nat_instance_ip" {
  value       = yandex_compute_instance.nat.network_interface[0].ip_address
  description = "Внутренний IP NAT-инстанса"
}


output "bucket_name" {
  value       = yandex_storage_bucket.crocodile.bucket
  description = "Имя бакета"
}

output "crocodile_url" {
  value       = "https://storage.yandexcloud.net/${yandex_storage_bucket.crocodile.bucket}/crocodile.jpg"
  description = "Публичная ссылка на картинку"
}

output "nlb_ip" {
  value = [
    for listener in yandex_lb_network_load_balancer.lamp_nlb.listener : [
      for spec in listener.external_address_spec : spec.address
    ]
  ][0][0]
  description = "Публичный IP сетевого балансировщика"
}
