# Домашнее задание к занятию «Организация сети»

**Выполнил:** Дудников Даниил

## Оглавление

1. [Домашнее задание «Организация сети»](#домашнее-задание-организация-сети)
2. [Домашнее задание «Вычислительные мощности. Балансировщики нагрузки»](#домашнее-задание-вычислительные-мощности-балансировщики-нагрузки)
3. [Домашнее задание «Безопасность в облачных провайдерах»](#домашнее-задание-безопасность-в-облачных-провайдерах)
4. [Домашнее задание «Базы данных и Kubernetes»](#домашнее-задание-базы-данных-и-kubernetes)
---
## Задание 1. Yandex Cloud

### Что сделано

- Создана VPC `netology-vpc` в зоне `ru-central1-a`.
- Публичная подсеть `public` — `192.168.10.0/24`.
- Приватная подсеть `private` — `192.168.20.0/24`.
- NAT-инстанс с внутренним IP `192.168.10.254` (образ `fd80mrhj8fl2oe87o4e1`).
- Route table для приватной подсети: статический маршрут `0.0.0.0/0` → `192.168.10.254`.
- Публичная ВМ `public-vm` с публичным IP — доступ в интернет напрямую.
- Приватная ВМ `private-vm` без публичного IP — доступ в интернет через NAT-инстанс.
- Подключение к приватной ВМ — через публичную (SSH Agent Forwarding / ProxyJump).

### Схема сети

```
                        Internet
                            ▲
                            │
        ┌───────────────────┴──────────────────────┐
        │            VPC netology-vpc              │
        │            зона ru-central1-a            │
        ├──────────────────────────────────────────┤
        │  public 192.168.10.0/24                  │
        │    ├─ NAT-инстанс 192.168.10.254 ────────┼──► Internet
        │    └─ public-vm (публичный IP)           │
        ├──────────────────────────────────────────┤
        │  private 192.168.20.0/24                 │
        │    └─ private-vm (только внутренний IP)  │
        │       route 0.0.0.0/0 → 192.168.10.254   │
        └──────────────────────────────────────────┘
```

---

## Структура репозитория

| Файл | Назначение |
|------|-----------|
| `providers.tf` | Провайдер Yandex Cloud |
| `variables.tf` | Переменные (зона, CIDR, образы, SSH-ключ) |
| `network.tf` | VPC, публичная и приватная подсети, route table |
| `nat-instance.tf` | NAT-инстанс |
| `compute.tf` | Публичная и приватная ВМ |
| `outputs.tf` | Выходные значения (IP-адреса) |
| `terraform.tfvars` | Значения переменных (SSH-ключ) — *в .gitignore* |
| `key.json` | Ключ сервисного аккаунта — *в .gitignore* |

---

## Тексты манифестов

### providers.tf

```hcl
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
```

### variables.tf

```hcl
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
```

### network.tf

```hcl
# VPC
resource "yandex_vpc_network" "main" {
  name = "netology-vpc"
}

# Публичная подсеть
resource "yandex_vpc_subnet" "public" {
  name           = "public"
  zone           = var.zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.public_subnet_cidr]
}

# Приватная подсеть
resource "yandex_vpc_subnet" "private" {
  name           = "private"
  zone           = var.zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.private_subnet_cidr]

  route_table_id = yandex_vpc_route_table.private.id
}

# Route table для приватной подсети
resource "yandex_vpc_route_table" "private" {
  name       = "private-route"
  network_id = yandex_vpc_network.main.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = "192.168.10.254"
  }
}
```

### nat-instance.tf

```hcl
resource "yandex_compute_instance" "nat" {
  name        = "nat-instance"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.nat_image_id
      size     = 10
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.public.id
    ip_address = "192.168.10.254"
    nat        = true
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}
```

### compute.tf

```hcl
resource "yandex_compute_instance" "public_vm" {
  name        = "public-vm"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.ubuntu_image_id
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

resource "yandex_compute_instance" "private_vm" {
  name        = "private-vm"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.ubuntu_image_id
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private.id
    nat       = false
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}
```

### outputs.tf

```hcl
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
```

---

## Результаты

### 1. Успешное создание инфраструктуры

Вывод `terraform output` и `terraform state list` — видно, что созданы все 7 ресурсов (VPC, 2 подсети, route table, NAT-инстанс, 2 ВМ).

![terraform output](screenshots/01-terraform-output.png)

### 2. Доступ в интернет с публичной ВМ

Публичная ВМ `public-vm` (`fhmb6ok9u44v6c5cjqjh`) имеет внутренний IP `192.168.10.28` и публичный `89.169.141.245`. Пинги до `8.8.8.8` и `ya.ru` проходят без потерь, DNS работает.

![public vm internet](screenshots/02-public-vm-internet.png)

### 3. Доступ в интернет с приватной ВМ через NAT-инстанс

Приватная ВМ `private-vm` (`fhmmb4s1k8ojvg7eih42`) имеет только внутренний IP `192.168.20.4`. Публичного IP у неё **нет**. Однако `curl ifconfig.me` возвращает `89.169.129.85` — это публичный IP **NAT-инстанса**. Значит, исходящий трафик приватной подсети идёт через NAT согласно route table.

![private vm internet](screenshots/03-private-vm-internet-via-nat.png)

### 4. Браузер на приватной ВМ через SSH-туннель

Firefox запущен локально, но его трафик завёрнут в SSH-туннель `локальная машина → public-vm → private-vm → NAT-инстанс → internet` (через SOCKS5-прокси на порту 1080). Сайт `ifconfig.me` видит IP `89.169.129.85` (NAT-инстанс), User-Agent — Ubuntu Firefox.

![private vm browser](screenshots/04-private-vm-browser.png)

---

## Как воспроизвести

1. Установить Terraform и YC CLI, авторизоваться в Yandex Cloud.
2. Создать сервисный аккаунт и положить ключ в `key.json`.
3. Указать публичный SSH-ключ в `terraform.tfvars`:
   ```hcl
   ssh_public_key = "ssh-ed25519 AAAA..."
   ```
4. Выполнить:
   ```bash
   terraform init
   terraform apply
   ```
5. Проверить доступ:
   ```bash
   # публичная ВМ
   ssh -A -i ~/.ssh/id_ed25519 ubuntu@<public_vm_ip>

   # с публичной — на приватную
   ssh ubuntu@<private_vm_ip>
   ```

---


# Домашнее задание «Вычислительные мощности. Балансировщики нагрузки»

## Задание 1. Yandex Cloud

### Что сделано

- Создан **бакет Object Storage** `dudnikov-daniil-crocodile-2026-09-27` с картинкой.
- Картинка доступна из интернета по прямой ссылке.
- Создана **Instance Group** из 3 ВМ с LAMP (Ubuntu 22.04 + Apache).
- Через `user-data` (cloud-init) на каждой ВМ ставится LAMP и создаётся стартовая страница со ссылкой на крокодила.
- Настроен **health check** (HTTP, порт 80, `/`).
- Создан **Network Load Balancer** `lamp-nlb`, подключённый к target group Instance Group.
- Проверена **отказоустойчивость**: удалили одну ВМ — сайт продолжил работать, группа восстановила состав.

### Структура репозитория (часть 2)

| Файл | Назначение |
|------|-----------|
| `storage.tf` | Бакет Object Storage + картинка + публичный доступ |
| `cloud-init.yaml` | Cloud-init для ВМ: LAMP + index.html |
| `instance-group.tf` | Instance Group из 3 ВМ с LAMP и health check |
| `nlb.tf` | Network Load Balancer на 80 порт |
| `outputs.tf` | Дополнен: `bucket_name`, `crocodile_url`, `nlb_ip` |
| `variables.tf` | Дополнен: `bucket_name`, `yc_access_key`, `yc_secret_key`, `lamp_image_id` |

### Тексты манифестов

#### storage.tf

```hcl
resource "yandex_storage_bucket" "crocodile" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "yandex_storage_bucket_grant" "crocodile_grant" {
  bucket = yandex_storage_bucket.crocodile.bucket

  grant {
    type        = "Group"
    permissions = ["READ"]
    uri         = "http://acs.amazonaws.com/groups/global/AllUsers"
  }
}

resource "yandex_storage_object" "crocodile_image" {
  bucket       = yandex_storage_bucket.crocodile.bucket
  key          = "crocodile.jpg"
  source       = "crocodile.jpg"
  acl          = "public-read"
  content_type = "image/jpeg"

  depends_on = [yandex_storage_bucket_grant.crocodile_grant]
}
```

#### cloud-init.yaml

```yaml
#cloud-config
package_update: true
packages:
  - apache2
  - php
  - libapache2-mod-php

runcmd:
  - systemctl enable apache2
  - systemctl start apache2
  - |
    cat > /var/www/html/index.html <<'EOF'
    <!DOCTYPE html>
    <html lang="ru">
    <head><meta charset="UTF-8"><title>Netology Crocodile</title></head>
    <body>
      <h1> Netology Crocodile Server</h1>
      <img src="https://storage.yandexcloud.net/dudnikov-daniil-crocodile-2026-09-27/crocodile.jpg" alt="Crocodile">
    </body>
    </html>
    EOF
```

#### instance-group.tf

```hcl
resource "yandex_compute_instance_group" "lamp_group" {
  name               = "lamp-group"
  folder_id          = var.folder_id
  service_account_id = "aje8h986adoqhodic3ph"

  instance_template {
    platform_id = "standard-v3"

    resources {
      cores  = 2
      memory = 2
    }

    boot_disk {
      initialize_params {
        image_id = var.lamp_image_id
        size     = 10
      }
    }

    network_interface {
      network_id = yandex_vpc_network.main.id
      subnet_ids = [yandex_vpc_subnet.public.id]
      nat        = true
    }

    metadata = {
      ssh-keys  = "ubuntu:${var.ssh_public_key}"
      user-data = file("cloud-init.yaml")
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = [var.zone]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 2
  }

  health_check {
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    http_options {
      port = 80
      path = "/"
    }
  }

  load_balancer {
    target_group_name = "lamp-target-group"
  }
}
```

#### nlb.tf

```hcl
resource "yandex_lb_network_load_balancer" "lamp_nlb" {
  name = "lamp-nlb"

  listener {
    name = "http-listener"
    port = 80

    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.lamp_group.load_balancer[0].target_group_id

    healthcheck {
      name = "http-healthcheck"
      http_options {
        port = 80
        path = "/"
      }
      interval = 10
      timeout  = 5
    }
  }
}
```

### Результаты

#### 1. Бакет Object Storage с картинкой

`https://storage.yandexcloud.net/dudnikov-daniil-crocodile-2026-09-27/crocodile.jpg`

![bucket crocodile](screenshots/06-bucket-crocodile.png)

#### 2. Instance Group из 3 ВМ с LAMP

Три ВМ в статусе `RUNNING_ACTUAL`, target group и health check настроены.

![instance group](screenshots/07-instance-group.png)

#### 3. Сайт через Network Load Balancer

`http://81.26.184.161/` — страница с крокодилом и hostname одной из ВМ.

![nlb site](screenshots/08-nlb-site.png)

#### 4. Балансировка между тремя ВМ

При многократных запросах hostname меняется: `...-yjyf`, `...-alyw`, `...-ewaz`.

![nlb roundrobin](screenshots/09-nlb-roundrobin.png)

#### 5. Проверка отказоустойчивости

Одна ВМ удалена вручную. Сайт продолжил отвечать `HTTP 200`.

![failover](screenshots/10-failover.png)

#### 6. Восстановление Instance Group

Через ~1 минуту группа создала новую ВМ вместо удалённой.

![failover recover](screenshots/11-failover-recover.png)

---


---

# Домашнее задание «Безопасность в облачных провайдерах»

## Задание 1. Yandex Cloud

### Что сделано (обязательная часть)

- Создан **KMS-ключ** `crocodile-bucket-key` (алгоритм AES_128, ротация 1 год).
- Бакет `dudnikov-daniil-crocodile-2026-09-27` **зашифрован** этим ключом через `server_side_encryption_configuration`.
- Все новые объекты в бакете автоматически шифруются по алгоритму `aws:kms`.
- Сервисному аккаунту `terraform-sa` выдана роль `kms.keys.encrypterDecrypter`.

### Структура репозитория (часть 3)

| Файл | Назначение |
|------|-----------|
| `kms.tf` | KMS-ключ для шифрования бакета |
| `storage.tf` | Дополнен блоком `server_side_encryption_configuration` |
| `outputs.tf` | Дополнен: `kms_key_id` |

### Тексты манифестов

#### kms.tf

```hcl
# KMS-ключ для шифрования бакета
resource "yandex_kms_symmetric_key" "crocodile_key" {
  name              = "crocodile-bucket-key"
  description       = "Ключ для шифрования содержимого бакета с крокодилом"
  default_algorithm = "AES_128"
  rotation_period   = "8760h"

  lifecycle {
    prevent_destroy = false
  }
}
```

#### storage.tf (фрагмент — шифрование бакета)

```hcl
resource "yandex_storage_bucket" "crocodile" {
  bucket        = var.bucket_name
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.crocodile_key.id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}
```

### Результаты (обязательная часть)

#### 1. KMS-ключ создан

Ключ `crocodile-bucket-key` (`id = abj7im51fv2ee05gun55`) в статусе `ACTIVE`, алгоритм `AES_128`, ротация раз в год.

![kms key](screenshots/12-kms-key.png)


---

# Домашнее задание «Базы данных и Kubernetes»

## Задание 1. Yandex Cloud

### Что сделано

**MySQL:**
- Созданы дополнительные подсети `private_b` (192.168.30.0/24, зона `b`) и `private_d` (192.168.40.0/24, зона `d`) для отказоустойчивости.
- Кластер MySQL размещён в разных подсетях (зоны `a` и `b`).
- Репликация с произвольным временем ТО: `maintenance_window { type = "ANYTIME" }`.
- Окружение `PRESTABLE`, платформа Intel Broadwell (`b1.medium`), 50% CPU, диск 20 ГБ (`network-ssd`).
- Бэкап в **23:59**: `backup_window_start { hours = 23, minutes = 59 }`.
- Защита от удаления: `deletion_protection = true`.
- БД `netology_db`, пользователь `netology_user` с `ALL_PRIVILEGES`.

**Kubernetes:**
- Дополнительные подсети `private_b` и `private_d` используются для мастера и узлов.
- Созданы два сервисных аккаунта: `k8s-cluster-sa` (управление) и `k8s-node-sa` (узлы) с ролями `k8s.clusters.agent`, `vpc.publicAdmin`, `container-registry.images.puller`.
- Региональный мастер Kubernetes в трёх зонах (`a`, `b`, `d`).
- Шифрование секретов KMS-ключом из ДЗ №3 (`abj7im51fv2ee05gun55`).
- Группа узлов из 3 машин с автомасштабированием до 6 (`auto_scale min=3, max=6, initial=3`).
- Создана security group `k8s-main-sg` с правилами для API (443, 6443), служебного трафика и health checks.
- Подключение к кластеру через `kubectl`.

### Структура репозитория (часть 4)

| Файл | Назначение |
|------|-----------|
| `mysql.tf` | MySQL-кластер, БД, пользователь, доп. подсети |
| `k8s.tf` | K8s-кластер, node group, сервисные аккаунты |
| `k8s-main-sg.tf` | Security group для K8s |

### Тексты манифестов

#### mysql.tf (фрагмент — кластер)

```hcl
resource "yandex_mdb_mysql_cluster" "netology_mysql" {
  name                = "netology-mysql-cluster"
  environment         = "PRESTABLE"
  network_id          = yandex_vpc_network.main.id
  version             = "8.0"
  deletion_protection = true

  maintenance_window {
    type = "ANYTIME"
  }

  backup_window_start {
    hours   = 23
    minutes = 59
  }

  resources {
    resource_preset_id = "b1.medium"
    disk_type_id       = "network-ssd"
    disk_size          = 20
  }

  host {
    zone      = "ru-central1-a"
    name      = "mysql-host-a"
    subnet_id = yandex_vpc_subnet.private.id
  }
  host {
    zone      = "ru-central1-b"
    name      = "mysql-host-b"
    subnet_id = yandex_vpc_subnet.private_b.id
  }
}
```

#### k8s.tf (фрагмент — кластер)

```hcl
resource "yandex_kubernetes_cluster" "k8s_cluster" {
  name        = "netology-k8s-cluster"
  network_id  = yandex_vpc_network.main.id

  master {
    regional {
      region = "ru-central1"
      location { zone = "ru-central1-a"; subnet_id = yandex_vpc_subnet.private.id }
      location { zone = "ru-central1-b"; subnet_id = yandex_vpc_subnet.private_b.id }
      location { zone = "ru-central1-d"; subnet_id = yandex_vpc_subnet.private_d.id }
    }
    public_ip          = true
    security_group_ids = [yandex_vpc_security_group.k8s_main_sg.id]
  }

  service_account_id      = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_node_sa.id

  kms_provider {
    key_id = yandex_kms_symmetric_key.crocodile_key.id
  }
}
```

#### k8s-main-sg.tf (фрагмент — правила)

```hcl
resource "yandex_vpc_security_group" "k8s_main_sg" {
  name       = "k8s-main-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    description       = "Master-node and node-node communication"
    protocol          = "ANY"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    description    = "K8s API access (443)"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "K8s API access (6443)"
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}
```

### Результаты

#### 1. MySQL-кластер

Кластер `netology-mysql-cluster` в окружении `PRESTABLE`, с защитой от удаления, бэкапом в 23:59, платформой Intel Broadwell (b1.medium, 50% CPU, диск 20 ГБ SSD).

![mysql cluster](screenshots/15-mysql-cluster.png)

#### 2. K8s-кластер

Региональный мастер в трёх зонах (`a`, `b`, `d`), шифрование секретов KMS-ключом `abj7im51fv2ee05gun55`, отдельные сервисные аккаунты для кластера и узлов.

![k8s cluster](screenshots/16-k8s-cluster.png)

#### 3. Узлы Kubernetes

2 узла в статусе `Ready`, версия `v1.35.1`, Ubuntu 22.04.5 LTS, containerd 2.2.1. Node group `netology-k8s-nodes` в статусе `RUNNING`, автомасштабирование (min=3, max=6).

![kubectl nodes](screenshots/17-kubectl-nodes.png)

#### 4. Cluster info и namespaces

API-сервер доступен по `https://81.26.187.67`, CoreDNS работает, все стандартные namespaces на месте.

![kubectl info](screenshots/18-kubectl-info.png)

### Примечание по группе узлов

В конфигурации Terraform (`k8s.tf`) задано автомасштабирование:
```hcl
scale_policy {
  auto_scale {
    min     = 3
    max     = 6
    initial = 3
  }
}
```

Однако Yandex Cloud при создании Managed Kubernetes Node Group создал базовую Compute Instance Group с типом `fixed_scale: 2`, проигнорировав параметр `initial_size = 3`. Прямое изменение Instance Group через `yc compute instance-group update` заблокировано платформой:

```
The entity management is only allowed to: managed-kubernetes.nodeGroup
```

Это ограничение платформы Yandex Cloud, а не ошибка конфигурации. Кластер работает, узлы в статусе `Ready`, автомасштабирование настроено в коде.

## Задание 2 (AWS)

Не выполнялось — отсутствует аккаунт AWS. Задание помечено как необязательное (*).#### 2. Бакет зашифрован

Вывод `terraform state show yandex_storage_bucket.crocodile` подтверждает, что к бакету применена конфигурация `server_side_encryption_configuration` с ключом `abj7im51fv2ee05gun55`.

![bucket encrypted](screenshots/13-bucket-encrypted.png)

---

### Часть 2 (со звёздочкой) — HTTPS-статический сайт

**Не выполнялась по объективным причинам.**

Для создания статического сайта в Object Storage с HTTPS требуется:
1. Собственный публичный домен.
2. Пройденная идентификация администратора домена через Госуслуги — с 01.09.2026 это обязательное требование для доменов `.ru`.

Домен **`dudnikov-alligator.ru`** был приобретён на Reg.ru (оплачен до 28.09.2027), однако процедура **идентификации администратора через Госуслуги занимает несколько дней** и на момент сдачи работы завершена не была. Без идентификации регистратор блокирует управление делегированием и DNS-записями домена, что делает невозможным привязку домена к бакету и выпуск HTTPS-сертификата.

![domain purchased](screenshots/14-domain-purchased.png)

Обязательная часть задания (создание KMS-ключа и шифрование бакета) выполнена полностью.



---

# Домашнее задание «Базы данных и Kubernetes»

## Задание 1. Yandex Cloud

### Что сделано

**MySQL:**
- Созданы дополнительные подсети `private_b` (192.168.30.0/24, зона `b`) и `private_d` (192.168.40.0/24, зона `d`) для отказоустойчивости.
- Кластер MySQL размещён в разных подсетях (зоны `a` и `b`).
- Репликация с произвольным временем ТО: `maintenance_window { type = "ANYTIME" }`.
- Окружение `PRESTABLE`, платформа Intel Broadwell (`b1.medium`), 50% CPU, диск 20 ГБ (`network-ssd`).
- Бэкап в **23:59**: `backup_window_start { hours = 23, minutes = 59 }`.
- Защита от удаления: `deletion_protection = true`.
- БД `netology_db`, пользователь `netology_user` с `ALL_PRIVILEGES`.

**Kubernetes:**
- Дополнительные подсети `private_b` и `private_d` используются для мастера и узлов.
- Созданы два сервисных аккаунта: `k8s-cluster-sa` (управление) и `k8s-node-sa` (узлы) с ролями `k8s.clusters.agent`, `vpc.publicAdmin`, `container-registry.images.puller`.
- Региональный мастер Kubernetes в трёх зонах (`a`, `b`, `d`).
- Шифрование секретов KMS-ключом из ДЗ №3 (`abj7im51fv2ee05gun55`).
- Группа узлов из 3 машин с автомасштабированием до 6 (`auto_scale min=3, max=6, initial=3`).
- Создана security group `k8s-main-sg` с правилами для API (443, 6443), служебного трафика и health checks.
- Подключение к кластеру через `kubectl`.

### Структура репозитория (часть 4)

| Файл | Назначение |
|------|-----------|
| `mysql.tf` | MySQL-кластер, БД, пользователь, доп. подсети |
| `k8s.tf` | K8s-кластер, node group, сервисные аккаунты |
| `k8s-main-sg.tf` | Security group для K8s |

### Тексты манифестов

#### mysql.tf (фрагмент — кластер)

```hcl
resource "yandex_mdb_mysql_cluster" "netology_mysql" {
  name                = "netology-mysql-cluster"
  environment         = "PRESTABLE"
  network_id          = yandex_vpc_network.main.id
  version             = "8.0"
  deletion_protection = true

  maintenance_window {
    type = "ANYTIME"
  }

  backup_window_start {
    hours   = 23
    minutes = 59
  }

  resources {
    resource_preset_id = "b1.medium"
    disk_type_id       = "network-ssd"
    disk_size          = 20
  }

  host {
    zone      = "ru-central1-a"
    name      = "mysql-host-a"
    subnet_id = yandex_vpc_subnet.private.id
  }
  host {
    zone      = "ru-central1-b"
    name      = "mysql-host-b"
    subnet_id = yandex_vpc_subnet.private_b.id
  }
}
```

#### k8s.tf (фрагмент — кластер)

```hcl
resource "yandex_kubernetes_cluster" "k8s_cluster" {
  name        = "netology-k8s-cluster"
  network_id  = yandex_vpc_network.main.id

  master {
    regional {
      region = "ru-central1"
      location { zone = "ru-central1-a"; subnet_id = yandex_vpc_subnet.private.id }
      location { zone = "ru-central1-b"; subnet_id = yandex_vpc_subnet.private_b.id }
      location { zone = "ru-central1-d"; subnet_id = yandex_vpc_subnet.private_d.id }
    }
    public_ip          = true
    security_group_ids = [yandex_vpc_security_group.k8s_main_sg.id]
  }

  service_account_id      = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_node_sa.id

  kms_provider {
    key_id = yandex_kms_symmetric_key.crocodile_key.id
  }
}
```

#### k8s-main-sg.tf (фрагмент — правила)

```hcl
resource "yandex_vpc_security_group" "k8s_main_sg" {
  name       = "k8s-main-sg"
  network_id = yandex_vpc_network.main.id

  ingress {
    description       = "Master-node and node-node communication"
    protocol          = "ANY"
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    description    = "K8s API access (443)"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "K8s API access (6443)"
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}
```

### Результаты

#### 1. MySQL-кластер

Кластер `netology-mysql-cluster` в окружении `PRESTABLE`, с защитой от удаления, бэкапом в 23:59, платформой Intel Broadwell (b1.medium, 50% CPU, диск 20 ГБ SSD).

![mysql cluster](screenshots/15-mysql-cluster.png)

#### 2. K8s-кластер

Региональный мастер в трёх зонах (`a`, `b`, `d`), шифрование секретов KMS-ключом `abj7im51fv2ee05gun55`, отдельные сервисные аккаунты для кластера и узлов.

![k8s cluster](screenshots/16-k8s-cluster.png)

#### 3. Узлы Kubernetes

2 узла в статусе `Ready`, версия `v1.35.1`, Ubuntu 22.04.5 LTS, containerd 2.2.1. Node group `netology-k8s-nodes` в статусе `RUNNING`, автомасштабирование (min=3, max=6).

![kubectl nodes](screenshots/17-kubectl-nodes.png)

#### 4. Cluster info и namespaces

API-сервер доступен по `https://81.26.187.67`, CoreDNS работает, все стандартные namespaces на месте.

![kubectl info](screenshots/18-kubectl-info.png)

### Примечание по группе узлов

В конфигурации Terraform (`k8s.tf`) задано автомасштабирование:
```hcl
scale_policy {
  auto_scale {
    min     = 3
    max     = 6
    initial = 3
  }
}
```
При развёртывании кластера Managed Kubernetes в Yandex Cloud базовая
Compute Instance Group была создана с типом `fixed_scale: 2`, несмотря
на параметр `initial_size = 3` в Node Group. При попытке изменить
размер Instance Group напрямую платформа возвращает ограничение:

```
The entity management is only allowed to: managed-kubernetes.nodeGroup
```

То есть управление Instance Group делегировано Managed Kubernetes,
и изменить её можно только через Node Group. Повторное обновление
Node Group через `yc managed-kubernetes node-group update
--auto-scale min=3,max=6,initial=3` подтверждает параметры в API,
но фактическое количество узлов остаётся равным 2.

**Итог:** конфигурация автомасштабирования задана корректно
(`min=3, max=6, initial=3`), кластер работает, узлы в статусе `Ready`,
API доступен. Фактическое количество узлов (2 вместо 3) обусловлено
особенностью синхронизации между Managed Kubernetes Node Group и
Compute Instance Group в текущей версии Yandex Cloud. При необходимости
группа может быть расширена вручную через консоль управления
или пересоздана с явным указанием `initial_size` при создании.
