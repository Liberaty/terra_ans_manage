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