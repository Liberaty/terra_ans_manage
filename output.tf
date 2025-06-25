output "vm_connections" {
  description = "SSH connection strings for VMs"
  value = {
    for _, vm in proxmox_virtual_environment_vm.ubuntu_clone :
    vm.name => "${var.ansible_user}@${vm.ipv4_addresses[1][0]}"
  }
}