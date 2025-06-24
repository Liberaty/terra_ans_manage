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


variable vm_name {
  type        = string
  description = "Имя создаваемой VM"
}

variable vmid {
  type        = number
  default     = 101
  description = "Присвоенный ID в Proxmox"
}


variable node {
  type        = string
  default     = "pve"
  description = "Нода на которой создавать VM"
}

variable ram_max {
  type        = number
  default     = 2048
  description = "Максимальное число выделенной RAM"
}

variable ram_min {
  type        = number
  default     = 1024
  description = "Минимальное число выделенной RAM"
}

variable cores {
  type        = number
  default     = 1
  description = "Количество ядер новой VM"
}

variable sockets {
  type        = number
  default     = 2
  description = "Количество потоков новой VM"
}

variable data_store {
  type        = string
  default     = "local-zfs"
  description = "Хранилище расположения VM"
}

variable address {
  type        = string
  default     = "192.168.1.101/24"
  description = "IP адрес и маска подстеи новой VM"
}


variable vm_gateway {
  type        = string
  default     = "192.168.1.1"
  description = "Шлюз подсети новой VM"
}



