# ==========================================
# 1. Дополнительные подсети для MySQL (отказоустойчивость)
# ==========================================
resource "yandex_vpc_subnet" "private_b" {
  name           = "private-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["192.168.30.0/24"]
}

resource "yandex_vpc_subnet" "private_d" {
  name           = "private-d"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["192.168.40.0/24"]
}

# ==========================================
# 2. Кластер MySQL
# ==========================================
resource "yandex_mdb_mysql_cluster" "netology_mysql" {
  name                = "netology-mysql-cluster"
  environment         = "PRESTABLE" # Требование: Prestable
  network_id          = yandex_vpc_network.main.id
  version             = "8.0"
  deletion_protection = true # Требование: Защита от удаления

  # Требование: Репликация с произвольным временем ТО
  maintenance_window {
    type = "ANYTIME"
  }

  # Требование: Бэкап в 23:59
  backup_window_start {
    hours   = 23
    minutes = 59
  }

  # Требование: Intel Broadwell, 50% CPU, диск 20 Гб
  # b1.medium = Intel Broadwell, 2 ядра, 4 ГБ RAM
  # core_fraction = 50 означает 50% CPU
  resources {
    resource_preset_id = "b1.medium"
    disk_type_id       = "network-ssd"
    disk_size          = 20
  }

  # Требование: Ноды в разных подсетях (в разных зонах)
  host {
    zone      = "ru-central1-a"
    name      = "mysql-host-a"
    subnet_id = yandex_vpc_subnet.private.id # Из прошлого ДЗ
  }

  host {
    zone      = "ru-central1-b"
    name      = "mysql-host-b"
    subnet_id = yandex_vpc_subnet.private_b.id
  }

}

# ==========================================
# 3. База данных и пользователь
# ==========================================
resource "yandex_mdb_mysql_database" "netology_db" {
  cluster_id = yandex_mdb_mysql_cluster.netology_mysql.id
  name       = "netology_db"
}

resource "yandex_mdb_mysql_user" "netology_user" {
  cluster_id = yandex_mdb_mysql_cluster.netology_mysql.id
  name       = "netology_user"
  password   = "NetologyPass123!" # Пароль для БД

  permission {
    database_name = yandex_mdb_mysql_database.netology_db.name
    roles         = ["ALL"]
  }
}
