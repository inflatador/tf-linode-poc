// tf and provider info

terraform {
  required_providers {
    linode = {
      source = "linode/linode"
    }
  }
}

provider "linode" {
  token = var.linode_token
}

// vars

variable private_key {
  description = "private key file location"
  type = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "linode_token" {
  description = "access token"
  type = string
}

variable "linode_disk_size" {
  type = number
  default = 50000
}

variable "instance_count" {
  description = "Number of Linodes to deploy"
  type        = number
  default = 2
}

variable "linode_image" {
  description = "Image to build from"
  default = "linode/almalinux8"
}

variable "label" {
  description = "Human-friendly name"
  default = "mediawiki-web"
}

variable "region" {
  description = "Linode region"
  default = "us-southeast"
}

variable "type" {
  description = "Cloud server flavor"
  default = "g6-standard-1"
}

variable "stackscript_id" {
  description = "provisioning script ID"
  type = number
  default = 909122
}

// resources

resource "linode_sshkey" "homekey" {
  label = "foo"
  ssh_key = chomp(file("~/.ssh/id_ed25519.pub"))
}

resource "random_string" "rootpw" {
  length = 32
  special = true
}

resource "linode_instance" "webhead" {
  count = var.instance_count
  label = "${var.label}-${count.index}"
  // image = var.linode_image
  // packer-built private image
  region = var.region
  type = var.type
  // stackscripts not permitted on custom imags
  // stackscript_id = var.stackscript_id
  private_ip = true
  disk {
    label = "bootme"
    image = var.linode_image
    size = var.linode_disk_size
    authorized_keys = [linode_sshkey.homekey.ssh_key]
    root_pass = random_string.rootpw.result
  }
  config {
    label = "linode_boot_config"
    kernel = "linode/grub2"
    devices {
      sda {
        disk_label = "bootme"
        }
      }
    root_device = "sda"

  }
  provisioner "remote-exec" {
    inline = ["hostnamectl set-hostname ${var.label}-${count.index}"]

    connection {
      host = self.ip_address
      type = "ssh"
      user = "root"
      private_key = file(var.private_key)

    }
  }

  provisioner "local-exec" {
    command = "sleep 100; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u root -i ',${self.ip_address}' ~/code/riichilab/ansible-roles/linode-web.yml"

  }

  boot_config_label = "linode_boot_config"
}

resource "linode_nodebalancer" "mediawiki-lb" {
  label = "mediawiki-lb"
  region = var.region
  client_conn_throttle = 10
}

resource "linode_nodebalancer_config" "web_config" {
  nodebalancer_id = linode_nodebalancer.mediawiki-lb.id
  port = 80
  protocol = "http"
  check = "http"
  check_path = "/"
  check_attempts = 3
  check_timeout = 30
  stickiness = "http_cookie"
  algorithm = "source"

}

resource "linode_nodebalancer_node" "upstreams" {
  count = var.instance_count
  nodebalancer_id = linode_nodebalancer.mediawiki-lb.id
  config_id = linode_nodebalancer_config.web_config.id
  address ="${element(linode_instance.webhead.*.private_ip_address, count.index)}:80"
  label = "${var.label}-mediawiki-lb"
}
