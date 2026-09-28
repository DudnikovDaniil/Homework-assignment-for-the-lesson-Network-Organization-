# ==========================================
# 1. Сервисные аккаунты для K8s
# ==========================================

resource "yandex_iam_service_account" "k8s_sa" {
  name = "k8s-cluster-sa"
}

resource "yandex_iam_service_account" "k8s_node_sa" {
  name = "k8s-node-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster_roles" {
  folder_id = var.folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster_roles_2" {
  folder_id = var.folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_node_role" {
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_node_sa.id}"
}

# ==========================================
# 2. Кластер Kubernetes
# ==========================================
resource "yandex_kubernetes_cluster" "k8s_cluster" {
  name        = "netology-k8s-cluster"
  description = "Kubernetes cluster for Netology homework"
  network_id  = yandex_vpc_network.main.id

  master {
    regional {
      region = "ru-central1"

      location {
        zone      = "ru-central1-a"
        subnet_id = yandex_vpc_subnet.private.id
      }
      location {
        zone      = "ru-central1-b"
        subnet_id = yandex_vpc_subnet.private_b.id
      }
      location {
        zone      = "ru-central1-d"
        subnet_id = yandex_vpc_subnet.private_d.id
      }
    }

    public_ip = true

    security_group_ids = [yandex_vpc_security_group.k8s_main_sg.id]
  }

  service_account_id      = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_node_sa.id

  kms_provider {
    key_id = yandex_kms_symmetric_key.crocodile_key.id
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_cluster_roles,
    yandex_resourcemanager_folder_iam_member.k8s_cluster_roles_2,
    yandex_resourcemanager_folder_iam_member.k8s_node_role,
  ]
}

# ==========================================
# 3. Группа узлов
# ==========================================
resource "yandex_kubernetes_node_group" "k8s_nodes" {
  cluster_id = yandex_kubernetes_cluster.k8s_cluster.id
  name       = "netology-k8s-nodes"

  instance_template {
    platform_id = "standard-v3"

    resources {
      cores  = 2
      memory = 4
    }

    boot_disk {
      size = 30
    }

    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.private.id]

      security_group_ids = [yandex_vpc_security_group.k8s_main_sg.id]
    }
  }

  scale_policy {
    auto_scale {
      min     = 3
      max     = 6
      initial = 3
    }
  }

  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
  }
}
