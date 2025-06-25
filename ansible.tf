# resource "local_file" "ansible_inventory" {
#   filename = "${path.root}/ansible/inventory/inventory.yml"
#   content  = templatefile("${path.module}/inventory.tftpl", {
#     vm_name      = local.vm.name
#     vm_ip        = local.vm.default_ipv4_address
#     ansible_user = var.ansible_user
#   })
# }