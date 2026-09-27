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
