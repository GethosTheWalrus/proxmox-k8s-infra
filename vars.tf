variable "username" { type=string }
variable "password" { type=string }

variable "example_remote_state_address" {
  type = string
  description = "Gitlab remote state file address"
}

variable "example_username" {
  type = string
  description = "Gitlab username to query remote state"
}

variable "example_access_token" {
  type = string
  description = "GitLab access token to query remote state"
}