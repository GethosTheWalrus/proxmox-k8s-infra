resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name            = "k8s1"
  node_name       = var.pve_node
  stop_on_destroy = true
  initialization {
    user_account {
      username    = var.os_user
      password    = var.os_password
    }
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.dedicated_memory
  }

  disk {
    datastore_id = var.datastore_id
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.disk_size
  }
}

resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name            = "k8s2"
  node_name       = var.pve_node
  stop_on_destroy = true
  initialization {
    user_account {
      username    = var.os_user
      password    = var.os_password
    }
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.dedicated_memory
  }

  disk {
    datastore_id = var.datastore_id
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.disk_size
  }
}

resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name            = "k8s3"
  node_name       = var.pve_node
  stop_on_destroy = true
  initialization {
    user_account {
      username    = var.os_user
      password    = var.os_password
    }
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.dedicated_memory
  }

  disk {
    datastore_id = var.datastore_id
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.disk_size
  }
}

resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type   = "iso"
  datastore_id   = var.os_image_datastore_id
  node_name      = var.pve_node
  url            = var.os_image
}