output "vm_info_connection" {
  description = "SSH connection string for the new VM"
  value = {
    vm-name = proxmox_virtual_environment_vm.ubuntu_clone.name
    vm-ssh-address = "${var.ansible_user}@${proxmox_virtual_environment_vm.ubuntu_clone.ipv4_addresses[1][0]}"
  }
}