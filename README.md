# Terraform Proxmox VM Automation 🚀

Этот репозиторий содержит Terraform-конфигурацию для создания и управления виртуальными машинами (VM) в Proxmox VE с помощью провайдера `bpg/proxmox`. Конфигурация поддерживает:

* Клонирование шаблонов VM через Cloud-Init
* Настройку ресурсов (CPU, RAM, сеть, диск)
* Автоматическую генерацию Ansible inventory.yml
* Масштабируемое добавление/изменение множества VM без удаления существующих
* Гибкую настройку статического или DHCP IP
* Использование API-токена для подключения к Proxmox

> **Важно**: проект рассчитан на запуск из каталога, например:
>
> ```
> /home/user/work/terraform/
> ├── main.tf
> ├── variables.tf
> ├── local.tf
> ├── output.tf
> ├── ansible.tf
> ├── inventory.tftpl
> ├── provider.tf
> └── terraform.tfvars
> ```
>
> А соседняя папка `ansible/inventory/` (на том же уровне, что и `terraform/`):
>
> ```
> /home/user/work/ansible/inventory/inventory.yml
> ```
>
> Inventory генерируется в `../ansible/inventory/inventory.yml` относительно `path.root`.

---

## Содержание README

1. [Описание](#описание)
2. [Предпосылки](#предпосылки)
3. [Структура проекта](#структура-проекта)
4. [Переменные и примеры (terraform.tfvars)](#переменные-и-примеры-terraformtfvars)
5. [Провайдер Proxmox (provider.tf)](#провайдер-proxmox-providertf)
6. [Основной ресурс VM (main.tf)](#основной-ресурс-vm-maintf)
7. [Локальные данные и генерация inventory (local.tf + ansible.tf + inventory.tftpl)](#локальные-данные-и-генерация-inventory-localtf--ansibletf--inventorytftpl)
8. [Outputs (output.tf)](#outputs-outputtf)
9. [Запуск Terraform](#запуск-terraform)
10. [Добавление / изменение VM](#добавление--изменение-vm)
11. [Ansible после создания VM](#ansible-после-создания-vm)
12. [Рекомендации по безопасности и state](#рекомендации-по-безопасности-и-state)
13. [Расширение и модули](#расширение-и-модули)
14. [Частые вопросы (FAQ)](#частые-вопросы-faq)
15. [Лицензия](#лицензия)

---

## Описание

Этот проект позволяет:

* Декларативно описывать в Terraform набор ВМ для Proxmox в виде `map` объектов.
* При `terraform apply` создавать/обновлять VM без разрушения уже работающих.
* Генерировать Ansible inventory.yml автоматически по актуальным VM и группам.
* Использовать Cloud-Init через шаблон, либо клонировать готовый cloud-template.
* Настраивать ресурсы CPU/RAM, сетевые параметры (static или DHCP), BIOS/UEFI, QEMU Guest Agent.
* Гибко управлять VMID, именами, группами (для Ansible), хранилищем дисков и шаблонов.

---

## Предпосылки

* Proxmox VE с доступом по API: нужно иметь API URL и токен с правами на создание VM (рекомендовано роль Administrator, либо ограниченная роль с правами на `/vms/*`).
* Terraform (версия = 1.11.3).
* Провайдер `bpg/proxmox` версии `0.78.2`.
* Провайдер `hashicorp/local` версия `2.5.3`.
* На машине, откуда запускается Terraform, должен быть доступ в Proxmox API (network, сертификаты или `insecure = true`).
* Папка Ansible-ситуации рядом с Terraform: `../ansible/inventory/`.
* Готовый шаблон (template VM) уже существует в Proxmox (с Cloud-Init установленным), или вы заранее подготовили образ/диск cloud-image и импортировали.
* SSH-ключи: публичный ключ хранится в шаблоне VM, Ansible-пользователь настроен.

---

## Структура проекта

```
terraform/                         # корень Terraform-проекта
├── provider.tf                    # Настройка провайдера Proxmox через API-токен
├── variables.tf                   # Переменные: API, ansible_user, vms map и др.
├── terraform.tfvars               # Значения переменных (пример)
├── main.tf                        # Ресурс proxmox_virtual_environment_vm с for_each
├── local.tf                       # Локальные вычисления: host_info, grouping
├── ansible.tf                     # Ресурс local_file для inventory.yml
├── inventory.tftpl                # Шаблон inventory для templatefile
├── output.tf                      # Outputs: vm_connections, ansible_inventory_path
└── modules/ (опционально)         # Здесь можно вынести повторно используемые модули
ansible/                           # Соседняя папка для Ansible playbooks
└── inventory/
    └── inventory.yml              # Будет сгенерирован Terraform-ом
```

> **Важно:** относительный путь к `../ansible/inventory/inventory.yml` используется в `ansible.tf`:
>
> ```hcl
> filename = "${path.root}/${var.ansible_inventory_path}"
> ```
>
> где `var.ansible_inventory_path` по умолчанию `../ansible/inventory/inventory.yml`.

---

## Переменные и примеры (terraform.tfvars)

### Переменные (variables.tf)

* `api_token_id` (string, sensitive) — Proxmox API-токен в формате `user@realm!tokenID=secret`.

* `bpg_api_url` (string, sensitive) — URL Proxmox API, например `https://proxmox.example.com:8006`.

* `ansible_user` (string) — SSH-пользователь для Ansible, например `ubuntu`.

* `vms` (map(object({...}))) — ключевая переменная, описывает множество VM.
  Поля внутри объекта:

  * `vm_id` (number) — Proxmox VMID новой VM.
  * `clone_id` (number) — VMID шаблона (cloud-init template) для клонирования.
  * `clone_datastore` (string) — хранилище, где лежит шаблон.
  * `data_store` (string) — хранилище, где будут лежать диски новой VM.
  * `node_name` (string) — Proxmox node, на которой создаётся VM.
  * `group` (string) — имя группы в Ansible inventory, например `"web-servers"`, `"db-servers"`.
  * `address` (string) — IP/маска для статического: `"192.168.1.101/24"`.
  * `gateway` (string) — шлюз сети, например `"192.168.1.1"`.
  * `cores` (number) — число CPU-ядер.
  * `sockets` (number) — число сокетов.
  * `ram_min` (number) — минимальная RAM (balloon) в MB.
  * `ram_max` (number) — максимальная RAM в MB.
  * `vm_name` (string) — имя VM в Proxmox. Обычно совпадает с ключом map, но вынесено для гибкости.

* `ansible_inventory_path` (string) — путь к inventory.yml относительно каталога Terraform (по умолчанию `../ansible/inventory/inventory.yml`).

### Пример terraform.tfvars

```hcl
# Proxmox API
bpg_api_url  = "https://proxmox.example.com:8006"
api_token_id = "terraform@pve!terraform=YOUR_SECRET_TOKEN"

ansible_user = "ubuntu"

# Описание множества VM
vms = {
  "web-01" = {
    vm_id           = 1001
    clone_id        = 9001
    clone_datastore = "local-zfs"
    data_store      = "local-zfs"
    node_name       = "pve"
    group           = "web-servers"
    address         = "192.168.1.101/24"
    gateway         = "192.168.1.1"
    cores           = 2
    sockets         = 1
    ram_min         = 1024
    ram_max         = 2048
    vm_name         = "web-01"
  }
  "db-01" = {
    vm_id           = 1002
    clone_id        = 9002
    clone_datastore = "local-zfs"
    data_store      = "local-zfs"
    node_name       = "pve"
    group           = "db-servers"
    address         = "192.168.1.102/24"
    gateway         = "192.168.1.1"
    cores           = 4
    sockets         = 1
    ram_min         = 2048
    ram_max         = 4096
    vm_name         = "db-01"
  }
  # Для добавления новой VM: просто добавить запись:
  # "it-01" = { vm_id=1003, clone_id=9003, clone_datastore="local-zfs", data_store="local-zfs", node_name="pve", group="it-service", address="192.168.1.103/24", gateway="192.168.1.1", cores=2, sockets=1, ram_min=1024, ram_max=2048, vm_name="it-01" }
}
```

> 🌐 **Совет**: храните `terraform.tfvars` вне публичного репозитория, если там есть чувствительные данные. Можно завести `terraform.tfvars.example` с примерными значениями.

---

## Провайдер Proxmox (provider.tf)

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.78.2"
    }
  }
}

provider "proxmox" {
  endpoint   = var.bpg_api_url
  api_token  = var.api_token_id
  insecure   = true   # при необходимости для self-signed сертификата
}
```

* `endpoint` — URL Proxmox API.
* `api_token` — одна строка `user@realm!tokenID=secret`.
* `insecure = true` отключает проверку TLS (использовать только в ненадёжных окружениях или при self-signed сертификатах).

---

## Основной ресурс VM (main.tf)

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  for_each = local.vm_definitions #💡
  # (Необязательно) Имя виртуальной машины
  name           = each.value.vm_name # 🏷️ Имя VM

  # (Необязательно) Идентификатор виртуальной машины
  vm_id          = each.value.vm_id        # Указываем необходимый vmid

  # Укажите имя Ноды, которому будет назначена VM.
  node_name      = each.value.node_name

  migrate        = true

  # (Необязательно) Описание VM
  description    = "Managed by Terraform"

  # 🤖 Поддержка QEMU Guest Agent
  agent {
    enabled      = true
    trim         = true
    type         = "virtio"
  }

  # 📦 параметры клонирования
  clone {
    datastore_id = each.value.clone_datastore
    vm_id        = each.value.clone_id
    full         = true
  }

  # 🧠 Память с поддержкой ballooning
  memory {
    dedicated    = each.value.ram_max
    floating     = each.value.ram_min
  }

  # 🧠 CPU: 2 ядра, 1 сокет, тип с поддержкой AES
  cpu {
    cores        = each.value.cores
    sockets      = each.value.sockets
    type         = "x86-64-v2-AES"
  }

  # 🌐 Сетевое подключение
  network_device {
    bridge      = "vmbr0"
    # enabled     = true
    # firewall    = false
    # mac_address = 
    model       = "virtio"
    # vlan_id     = each.value.vlan_id # 🏷️ VLAN Tag (раскомментируй при необходимости)
    # trunks      =
  }

  # 🧬 Тип виртуальной машины и BIOS
  bios           = "ovmf"
  machine        = "q35"

  # ☁️ cloud-init для автоматической настройки
  initialization {
    # 
    datastore_id = each.value.data_store
    # interface     = "scsi2"
    # 
    # dns {
    #   domain      = local.vm_domain
    #   servers     = local.vm_dns
    # }
    # 🌐 Статическая сеть
    # IP: если address непустой — ставим static, иначе DHCP
    ip_config {
      ipv4 {
        address  = each.value.address
        gateway  = each.value.gateway
      }
    }
    # Пример: если DHCP: не передавать ip_config, Proxmox выставит DHCP
    
    # user_account {
    #   keys        = [file(local.ssh_key_path)]            # 🔑 Авторизация по SSH
    #   password    = var.vm_password                       # 🔐 Пароль (вводится вручную)
    #   username    = local.ssh_user                        # 👤 Пользователь VM
    # }                                    
  }

  # 🏁 Порядок загрузки
  # boot_order    = ["scsi0", "scsi1"]

  # 💾 Настройка дополнительного диска
  # disk {
  #   aio           = "io_uring"
  #   backup        = true
  #   cache         = "writethrough"
  #   datastore_id  = "local-zfs"
  #   file_format   = "raw"
  #   interface     = "scsi2"
  #   replicate     = true
  #   size          = "40"
  #   ssd           = true
  # }

  # 💽 EFI диск (для UEFI загрузки) раскомментируй если точно знаешь зачем
  # efi_disk {
  #   datastore_id       = "local-zfs"
  #   file_format        = "raw"
  #   type               = "4m"
  #   pre_enrolled_keys  = true
  # }

  # Настройка операционной системы при необходимости
    # l24 - Ядро Linux 2.4.
    # l26 - Ядро Linux 2.6 - 5.X.
    # other - Неуказанная операционная система.
    # solaris - OpenIndiania, OpenSolaris и ядро Solaris.
    # w2k - Windows 2000.
    # w2k3 - Windows 2003.
    # w2k8 - Windows 2008.
    # win7 - Windows 7.
    # win8 — Windows 8, 2012 или 2012 R2.
    # win10 - Windows 10 или 2016.
    # win11 - Windows 11
    # wvista - Windows Vista.
    # wxp - Windows XP.
  # operating_system {
  #   type = "l26"
  # }
  
  # (Необязательно) Устанавливает флаг защиты виртуальной машины. Это отключит удаление виртуальной машины и операций с диском (по умолчанию false).
  # protection = false          # можно удалять

  # (Необязательно) Перезапустите виртуальную машину после первоначального создания (по умолчанию false)
  # reboot        = false       # не перезагружать

  # (Необязательно) При необходимости перезагрузите виртуальную машину после обновления (по умолчанию true).
  # reboot_after_update = true  # перезагрузить
  
  # (Необязательно) Запускать ли виртуальную машину (по умолчанию true)
  # started             = false

  # 🤖 (Необязательно) Тип оборудования SCSI (по умолчанию virtio-scsi-pci)
    # lsi - LSI Logic SAS1068E.
    # lsi53c810 - LSI Logic 53C810.
    # virtio-scsi-pci - VirtIO SCSI.
    # virtio-scsi-single - VirtIO SCSI (с одной очередью).
    # megasas - LSI Logic MegaRAID SAS.
    # pvscsi - Паравиртуальный SCSI в VMware.
  # scsi_hardware   = "virtio-scsi-pci"

  # 🔁 Порядок запуска и отключения
  # startup {
  #   order         = 2
  #   up_delay      = 0
  #   down_delay    = 0
  # }

  # (Необязательно) Включение USB. Это позволяет напрямую использовать физические USB-устройства в гостевой операционной системе (по умолчанию true).
  # tablet_device   = true
}
```

* Используется `for_each = var.vms` (map), чтобы заводить произвольное число ВМ.
* Cloud-init настроен на статический IP.
* При необходимости можно добавить блок `user_account` для создания юзера и SSH-ключей через Cloud-Init в момент первого запуска (если шаблон VM поддерживает).
* `clone` ожидает, что у вас уже есть VM-шаблон (cloud-init template) с VMID = `each.value.clone_id` на хранилище `clone_datastore`.

---

## Локальные данные и генерация inventory (local.tf + ansible.tf + inventory.tftpl)

### local.tf

```hcl
locals {
  # Берём описания из переменной
  vm_definitions = var.vms
}

locals {
  # Собираем информацию о хостах после создания
  host_info = {
    for key, vm in proxmox_virtual_environment_vm.vm :
    key => {
      name  = vm.name
      ip    = vm.ipv4_addresses[1][0]
      group = var.vms[key].group
    }
  }
  group_names = distinct([
    for h in values(local.host_info) : h.group
  ])
  grouped = {
    for g in local.group_names :
    g => [
      for h in values(local.host_info) :
      h if h.group == g
    ]
  }
}
```

* `host_info` — map ключом (`key` из var.vms) → объект с полями `name`, `ip`, `group`.
* `vm.ipv4_addresses[1][0]` — атрибут провайдера для IP.
* `grouped` — map групп → список хостов для каждой группы.

### inventory.tftpl

Шаблон YAML для Ansible inventory:

```gotemplate
all:
  children:
    proxmox:
      hosts:
        localhost:
          ansible_host: 192.168.1.54

%{ for grp, hosts in grouped ~}
    ${grp}:
      hosts:
%{ for h in hosts ~}
        ${h.name}:
          ansible_host: ${h.ip}
          ansible_user: ${ansible_user}
%{ endfor ~}
%{ endfor ~}
```

* Отступы важны: `all:` на нулевом уровне, `children:` под `all`, а группы на уровне `children`.
* `${ansible_user}` передаётся из переменной `var.ansible_user`.

### ansible.tf

```hcl
resource "local_file" "ansible_inventory" {
  filename = "${path.root}/${var.ansible_inventory_path}"

  content  = templatefile("${path.module}/inventory.tftpl", {
    grouped      = local.grouped
    ansible_user = var.ansible_user
  })
}
```

* Путь: `${path.root}/${var.ansible_inventory_path}`, где `var.ansible_inventory_path` обычно `../ansible/inventory/inventory.yml`.
* Перед запуском Terraform убедитесь, что папка `../ansible/inventory/` существует.

---

## Outputs (output.tf)

```hcl
output "vm_connections" {
  description = "SSH connection strings for VMs"
  value = {
    for _, vm in proxmox_virtual_environment_vm.vm :
    vm.name => "${var.ansible_user}@${vm.ipv4_addresses[1][0]}"
  }
}

output "ansible_inventory_path" {
  description = "Path to generated inventory"
  value       = local_file.ansible_inventory.filename
}
```

* `vm_connections` возвращает map: `"vm_name" = "user@IP"`.
* `ansible_inventory_path` — куда записан inventory.yml.

---

## Запуск Terraform

1. Перейдите в каталог Terraform:

   ```bash
   cd /home/user/work/terraform
   ```
2. Подготовьте `terraform.tfvars` с вашим Proxmox API URL, токеном и описанием VM (см. пример выше).
3. Убедитесь, что соседняя папка для inventory существует:

   ```bash
   mkdir -p ../ansible/inventory
   ```
4. Инициализация:

   ```bash
   terraform init
   ```
5. Проверка конфигурации:

   ```bash
   terraform validate
   ```
6. Просмотр плана:

   ```bash
   terraform plan
   ```
7. Применение:

   ```bash
   terraform apply
   ```

   * Terraform создаст (или обновит) VM(s) согласно описанию в `var.vms`.
   * Сгенерируется inventory.yml в `../ansible/inventory/inventory.yml`.
   * Выведется `vm_connections` в формате `{ vm_name = "user@IP", ... }`.

---

## Добавление / изменение VM

* **Добавление** новой VM: в `terraform.tfvars` в map `vms` добавляете новую запись с уникальным ключом (например `"it-01"`) и соответствующими параметрами. Затем `terraform apply` — новая VM создастся, существующие останутся без изменений.
* **Изменение ресурсов**: правите поля `cores`, `ram_max`, `ram_min` и пр. для существующего ключа в `vms`. Terraform обновит конфигурацию VM без удаления.
* **Изменение IP**: для уже созданной VM менять статический IP через Terraform невозможно: Cloud-Init задаёт IP только при первом запуске. Если нужно поменять IP (особюенно в проде), необходимо использовать Ansible playbook для изменения netplan. Можно оставить `address` неизменным, а после первого запуска делать изменение через Ansible. Либо вручную удалить и пересоздать, но это рисковано для prod.
* **Удаление** VM: удалить запись из map `vms` → при следующем `terraform apply` Terraform выполнит destroy этой VM. Если это prod и вы не хотите случайно удалить VM, можно:

  * Добавить блок `lifecycle { prevent_destroy = true }` внутри ресурса, но тогда Terraform будет ругаться при попытке удалить. Либо не убирать запись из map, а “деактивировать” VM через Ansible/ручные действия.
* **State**: храните state удалённо (S3, Terraform Cloud, etc.) с блокировкой, чтобы несколько операторов не путались.

---

## Ansible после создания VM

1. Inventory будет доступен в `../ansible/inventory/inventory.yml`.
2. Первые задачи Ansible (playbook) могут:

   * Установить hostname (`hostname` module).
   * Настроить статическую сеть (шаблон netplan Jinja2).
   * Установить нужные пакеты: `neofetch`, `zabbix-agent`, `htop`, `curl` и др.
   * Перезагрузить VM, чтобы сеть заработала.
3. Playbook может обновить inventory, если IP/hostname изменились.
4. Рекомендуется хранить playbooks рядом: `../ansible/playbooks/`, а inventory генерируется Terraform-ом.

Пример простого playbook (`../ansible/playbooks/setup_vm.yml`):

```yaml
---
- hosts: all
  become: true
  vars:
    netplan_template_src: "../templates/netplan-static.j2"
  tasks:
    - name: Set hostname
      hostname:
        name: "{{ inventory_hostname }}"

    - name: Configure netplan
      template:
        src: "{{ netplan_template_src }}"
        dest: /etc/netplan/01-netcfg.yaml
      notify:
        - Apply netplan

    - name: Install base packages
      apt:
        name:
          - neofetch
          - zabbix-agent
          - htop
          - curl
        state: present
      register: install_pkgs

    - name: Restart if needed
      reboot:
        when: install_pkgs.changed
        msg: "Reboot after package install"
  
  handlers:
    - name: Apply netplan
      command: netplan apply
```

Запускается из каталога `ansible/`:

```bash
ansible-playbook -i inventory/inventory.yml playbooks/setup_vm.yml
```

---

## Рекомендации по безопасности и state

* **Terraform state**: используйте удалённое хранилище (Terraform Cloud, S3+DynamoDB lock, etc.), чтобы избегать конфликтов и потери состояния.
* **API-токен**: храните `terraform.tfvars` вне репозитория, добавьте в `.gitignore`. Можно использовать Vault или CI/CD секреты.
* **SSH-ключи**: публичный ключ можно хранить в шаблоне VM или в отдельном snippet; приватный ключ хранится локально на операторе/CI.
* **insecure = true**: подходит для теста/внутренней сети. В проде лучше настроить проверку TLS: загрузить CA-сертификат Proxmox и указать `cacert` в провайдере, или хранить в переменной окружения.
* **lifecycle.prevent\_destroy**: для prod VM можно добавить, чтобы избежать случайного удаления.

---

## Расширение и модули

* Если у вас несколько окружений (dev/test/prod), можно вынести логику создания VM в модуль `modules/proxmox-vm`, принимающий объект описания VM, и вызывать модуль из разных конфигураций с разными tfvars.
* Можно добавить поддержку дополнительных параметров: дисков дополнительных (disk blocks), VLAN (`vlan_id`), tags, резервное копирование snapshot, firewall и др.
* Добавить input-переменные для шаблона cloud-init (usernames, пароли, SSH keys) и передавать их в block `initialization.user_account`.
* Автоматизировать импорт существующих шаблонов: через Terraform resource import для шаблонных VM.
* CI/CD: оборачивать `terraform plan/apply` в pipeline, проверять formatting (`terraform fmt`), linting (`tflint`), security scan.

---

## Частые вопросы (FAQ)

* **Q:** Как задать статический IP только при первом создании, но не менять его потом?
  **A:** Cloud-Init задаёт IP один раз. После первого запуска не меняет `address` в Terraform. Если нужно изменить сетевые настройки, сделайте это через Ansible (netplan), а Terraform для других задач.
* **Q:** Можно ли управлять несколькими сетевыми интерфейсами?
  **A:** Да: добавьте несколько блоков `network_device` с `id = 0`, `id = 1` и т.д., указывайте нужные bridge/vlan. В `initialization` Cloud-Init может настроить только один интерфейс, дополнительные настраивайте через Ansible.
* **Q:** Как защитить Terraform state?
  **A:** Используйте удалённый backend (Terraform Cloud, AWS S3+lock, GCS, Azure Storage и т.д.).
* **Q:** Нужно ли создавать шаблон вручную?
  **A:** Да: перед клонированием должен быть готов Cloud-Init шаблон VM: обычно создают VM, устанавливают ОС вручную или через autoinstall, настраивают cloud-init пакет, очищают логи, превращают VM в шаблон (`qm template VMID`).
* **Q:** Как добавить диск, VLAN, firewall?
  **A:** Дополните ресурс `proxmox_virtual_environment_vm` блоками `disk`, `network_device` с нужными параметрами. Обратите внимание на синтаксис провайдера bpg/proxmox (см. документацию: [https://github.com/bpg/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox)).
* **Q:** Что делать, если нужно изменить конфигурацию VM, недоступную через Terraform?
  **A:** Либо вручную (GUI или `qm set`), либо через `null_resource`+`local-exec`, либо дождаться обновления провайдера.
* **Q:** Как отлаживать ошибки Proxmox API?
  **A:** Включайте `TF_LOG=DEBUG terraform apply`, смотрите логи API, проверяйте права токена в Proxmox (role, scope).
* **Q:** Как задать hostname VM?
  **A:** Шаблон Cloud-Init не поддерживает поле hostname. В основном hostname задают через Ansible после создания VM.
* **Q:** Что делать, если нужно автоматическое удаление или snapshot?
  **A:** Terraform поддерживает уничтожение при удалении записи из map. Snapshot можно автоматизировать через Proxmox API и Terraform, но часто делают отдельными задачами (Ansible, скрипты).
* **Q:** Можно ли использовать Terraform для управления кластером Proxmox (nodes, storage)?
  **A:** С помощью провайдера bpg/proxmox можно создавать ресурсы VM, контейнеры, возможно network config, но не весь Proxmox cluster. Для сетевых настроек лучше вручную или Ansible. Terraform подходит для VM lifecycle.

---

## Лицензия

Этот проект предоставлен “как есть” без гарантий. Используйте на свой страх и риск.
Вы можете свободно модифицировать README и Terraform-код под свои нужды.

---
