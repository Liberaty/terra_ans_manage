# Переменная для 🔑 пароля
#######################################
variable "api_token_id" {
  type        = string
  description = "ID и Token для Proxmox"
  sensitive   = true
}

variable bpg_api_url {
  type        = string
  description = "Proxmox API URL"
  sensitive   = true
}

variable ansible_user {
  type        = string
  description = "Пользователь для подключений Ansible по SSH"
}

variable "vms" {
  description = "Словарь описаний ВМ, ключ — уникальное имя (идентификатор), значение — объект с параметрами"
  type = map(object({
    vm_id         = number      # Proxmox VMID
    clone_id      = number      # VMID шаблона или параметры клонирования
    clone_datastore = string    # хранилище шаблона
    data_store    = string      # хранилище для дисков новой VM
    node_name     = string      # node в кластере
    group         = string      # имя группы для Ansible inventory (например "web-servers", "db", "it-service")
    address       = string      # IP/маска, например "192.168.1.101/24"; или пустая строка/спец.значение для DHCP
    gateway       = string      # шлюз
    cores         = number
    sockets       = number
    ram_min       = number
    ram_max       = number
    vm_name       = string      # хотя ключ map может совпадать с именем, вынес в значение для гибкости
  }))
}