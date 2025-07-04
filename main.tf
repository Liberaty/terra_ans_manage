# Описание полной конфигурации виртуальной машины Ubuntu
#######################################
# Документация: https://github.com/bpg/terraform-provider-proxmox/blob/main/docs/resources/virtual_environment_vm.md
#######################################
resource "proxmox_virtual_environment_vm" "vm" {
  for_each = local.vm_definitions
  # (Необязательно) Имя виртуальной машины
  name           = each.value.vm_name

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

  # 🏁 Порядок загрузки: сначала ISO, затем диск
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

  # 💽 EFI диск (для UEFI загрузки)
  # efi_disk {
  #   datastore_id       = "local-zfs"
  #   file_format        = "raw"
  #   type               = "4m"
  #   pre_enrolled_keys  = true
  # }

  # Настройка операционной системы
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
