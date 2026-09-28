resource "yandex_vpc_security_group" "k8s_main_sg" {
  name        = "k8s-main-sg"
  description = "Basic security group for K8s cluster and nodes"
  network_id  = yandex_vpc_network.main.id

  # Служебный трафик: мастер-узел и узел-узел
  ingress {
    description       = "Master-node and node-node communication"
    protocol          = "ANY"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  # Проверки балансировщика
  ingress {
    description       = "Load balancer health checks"
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }

  # Доступ к API K8s (443)
  ingress {
    description    = "K8s API access (443)"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Доступ к API K8s (6443)
  ingress {
    description    = "K8s API access (6443)"
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # ICMP из внутренних подсетей
  ingress {
    description    = "ICMP from internal subnets"
    protocol       = "ICMP"
    v4_cidr_blocks = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"]
  }

  # Весь исходящий трафик
  egress {
    description    = "Allow all outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}
