terraform {
  # Версия terraform
  required_version = "~>0.12.8"
}

provider "google" {
  # Версия провайдера
  version = "~>2.15"

  # ID проекта
  project = var.project

  region = var.region
}

resource "google_compute_project_metadata_item" "default" {
  key     = "ssh-keys"
  value   = "appuser:${file(var.public_key_path)}"
  project = var.project
}

module "vm" {
  source           = "../modules/vm"
  zone             = var.zone
  machine_type     = var.machine_type
  private_key_path = var.private_key_path
  vm_count         = var.vm_count
  vm_disk_image    = var.vm_disk_image
  env              = var.env
  enable_provision = var.enable_provision
  repo_branch      = var.repo_branch
  repo_url         = var.repo_url
  script_to_run    = var.script_to_run

  vm_depends_on = [
    google_compute_project_metadata_item.default,
    module.vpc
  ]
}

module "vpc" {
  source        = "../modules/vpc"
  source_ranges = var.ssh_source_ranges
  env           = var.env
}
