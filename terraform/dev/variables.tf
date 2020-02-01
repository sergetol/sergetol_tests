variable "project" {
  description = "Project ID"
}

variable "region" {
  description = "Region"
  # Значение по умолчанию
  default = "europe-north1"
}

variable "zone" {
  description = "Zone"
  default     = "europe-north1-a"
}

variable "machine_type" {
  description = "Machine type"
  default     = "f1-micro"
}

variable "public_key_path" {
  # Описание переменной
  description = "Path to the public key used for ssh access"
}

variable "private_key_path" {
  description = "Path to the private key used for ssh access"
}

variable "vm_count" {
  description = "VM count"
  default     = 1
}

variable "vm_disk_image" {
  description = "Disk image for VM"
  default     = "ubuntu-1604-lts"
}

variable "enable_provision" {
  default = true
}

variable "ssh_source_ranges" {
  description = "Allowed IP addresses"
  default     = ["0.0.0.0/0"]
}

variable "env" {
  description = "Environment name: e.g., stage, prod"
  default     = ""
}

variable "repo_branch" {
  description = "Repository branch to clone"
  default     = "master"
}

variable "repo_url" {
  description = "Repository URL to clone"
  default     = ""
}

variable "script_to_run" {
  description = "Path to script to run on VM"
  default     = ""
}
