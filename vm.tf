resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name           = "k8s1"
  node_name      = "proxmox1"

  # should be true if qemu agent is not installed / enabled on the VM
  stop_on_destroy = true

  initialization {
    user_account {
      # do not use this in production, configure your own ssh key instead!
      username   = "k8s"
      password   = "s8k"
    }
  }

  cpu {
    cores        = 2
    type         = "x86-64-v2-AES"  # recommended for modern CPUs
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "big-nas"
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 20
  }
}

resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type   = "iso"
  datastore_id   = "local"
  node_name      = "proxmox1"
  url            = "https://cloud-images.ubuntu.com/oracular/current/oracular-server-cloudimg-amd64.img"
}