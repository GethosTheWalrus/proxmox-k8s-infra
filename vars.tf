variable "username" { type=string }
variable "password" { type=string }
variable "cpu_cores" {
    type=number
    default=2
}
variable "cpu_type" {
    type=string
    default="x86-64-v2-AES"
}
variable "dedicated_memory" {
    type=number
    default=2048
}
variable "disk_size" {
    type=number
    default=20
}
variable "datastore_id" {
    type=string
    default="big-nas"
}
variable "os_image" {
    type=string
    default="https://cloud-images.ubuntu.com/minimal/releases/oracular/release/ubuntu-24.10-minimal-cloudimg-amd64.img"
}
variable "pve_node" {
    type=string
    default="proxmox1"
}
variable "os_user" {
    type=string
    default="k8s"
}
variable "os_password" {
    type=string
    default="s8k"
}
variable "os_image_datastore_id" {
    type=string
    default="local"
}