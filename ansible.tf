resource "local_file" "ansible_inventory" {
  # path.root указывает на "/home/user/work/terraform"
  # ../ansible/... приведёт к "/home/user/work/ansible/inventory/inventory.yml"
  filename = "${path.root}/${var.ansible_inventory_path}"

  content  = templatefile("${path.module}/inventory.tftpl", {
    grouped      = local.grouped
    ansible_user = var.ansible_user
  })
}