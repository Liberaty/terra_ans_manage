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