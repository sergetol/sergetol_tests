resource "google_compute_instance" "vm" {
  count        = var.vm_count
  name         = "vm${count.index + 1}-${trimspace(var.env)}"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["vm-${trimspace(var.env)}"]

  # Определение загрузочного диска
  boot_disk {
    initialize_params {
      image = var.vm_disk_image
      size  = 10
      type  = "pd-ssd"
    }
  }

  # Определение сетевого интерфейса
  network_interface {
    # Сеть, к которой присоединить данный интерфейс
    network = "default"
    access_config {}
  }

  connection {
    type  = "ssh"
    host  = self.network_interface[0].access_config[0].nat_ip
    user  = "appuser"
    agent = false
    # путь до приватного ключа
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
    content     = var.enable_provision ? (var.script_to_run != "" ? file(var.script_to_run) : "empty content") : "empty content"
    destination = var.enable_provision ? (var.script_to_run != "" ? basename(var.script_to_run) : "/dev/null") : "/dev/null"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/run.sh.tmpl", { repo_branch = var.repo_branch, repo_url = var.repo_url, script_to_run = basename(var.script_to_run) })
    destination = var.enable_provision ? "run.sh" : "/dev/null"
  }

  provisioner "remote-exec" {
    inline = [
      var.enable_provision ? (var.script_to_run != "" ? "echo Script to run: ${abspath(var.script_to_run)} && chmod +x run.sh && chmod +x ${basename(var.script_to_run)} && ./run.sh" : "echo No script to run!") : "echo Provision disabled!"
    ]
  }

  depends_on = [var.vm_depends_on]
}
