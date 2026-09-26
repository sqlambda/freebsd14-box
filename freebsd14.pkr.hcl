packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1.1"
    }
    vagrant = {
      source  = "github.com/hashicorp/vagrant"
      version = "~> 1.1"
    }
  }
}

# Bumping the release is iso_url, iso_checksum and box_version.
variable "iso_url" {
  type    = string
  default = "https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/14.5/FreeBSD-14.5-RELEASE-amd64-disc1.iso"
}

# From CHECKSUM.SHA256-FreeBSD-14.5-RELEASE-amd64, published alongside the ISO.
variable "iso_checksum" {
  type    = string
  default = "sha256:a7f360c8dbd4727a8d3213ac85f6eb9b51ee4ed2577a2c31aaebbcae3d921d56"
}

variable "box_version" {
  type    = string
  default = "14.5.0"
}

# Time from power-on to the installer's Welcome dialog. The dialog waits
# forever, so err long: keys sent before it is up are lost.
variable "boot_wait" {
  type    = string
  default = "60s"
}

variable "headless" {
  type    = bool
  default = true
}

source "qemu" "freebsd14" {
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  accelerator = "kvm"
  headless    = var.headless
  memory      = 2048
  cpus        = 2

  # virtio-scsi root → da0, the layout the installerconfig and the box's
  # Vagrantfile both assume.
  disk_interface   = "virtio-scsi"
  disk_size        = "32G"
  format           = "qcow2"
  disk_compression = true
  # cleanup.sh's zero-fill turns into holes instead of 28G of real writes.
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  net_device         = "virtio-net"

  output_directory = "build/qemu"
  vm_name          = "freebsd14.qcow2"

  http_directory = "http"
  boot_wait      = var.boot_wait
  # Welcome dialog → Shell (its "s" shortcut) → DHCP → fetch the
  # installerconfig and run it; reboot into the installed system. The live
  # environment already has a writable /tmp, so no single-user detour.
  boot_command = [
    "s<wait5>",
    "dhclient vtnet0<enter><wait10>",
    "fetch -o /tmp/installerconfig http://{{ .HTTPIP }}:{{ .HTTPPort }}/installerconfig",
    " && bsdinstall script /tmp/installerconfig && reboot<enter>",
  ]

  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout      = "30m"
  shutdown_command = "sudo shutdown -p now"
}

build {
  sources = ["source.qemu.freebsd14"]

  provisioner "file" {
    source      = "files/vagrant.pub"
    destination = "/tmp/vagrant.pub"
  }

  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} sh -eux '{{ .Path }}'"
    scripts = [
      "scripts/update.sh",
      "scripts/vagrant.sh",
      "scripts/cleanup.sh",
    ]
  }

  post-processors {
    post-processor "vagrant" {
      output               = "build/sqlambda-freebsd14-${var.box_version}-libvirt-amd64.box"
      vagrantfile_template = "Vagrantfile.box"
    }
    post-processor "checksum" {
      checksum_types = ["sha256"]
      output         = "build/sqlambda-freebsd14-${var.box_version}-libvirt-amd64.box.sha256"
    }
  }
}
