# Настройка подключения к Proxmox через API с использованием токена
#######################################
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.78.2" # 🧩 Актуальная стабильная версия провайдера
    }
  }
}

provider "proxmox" {
  endpoint   = var.bpg_api_url   # 🌐 URL API Proxmox
  api_token  = var.api_token_id  # ✅ Одна строка, формат: id=secret
  insecure   = true              # ⚠️ Отключаем проверку TLS (для self-signed сертификатов)
}
