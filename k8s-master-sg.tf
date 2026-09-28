resource "yandex_vpc_security_group" "k8s_master_sg" {
  name        = "k8s-master-sg"
  description = "Security group for K8s master API access"
  network_id  = yandex_vpc_network.main.id

  ingress {
    description    = "K8s API access 443"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "K8s API access 6443"
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow all outgoing"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}
