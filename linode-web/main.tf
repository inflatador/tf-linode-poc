// tf and provider info

terraform {
  required_providers {
    linode = {
      source = "linode/linode"
    }
  }
}

// end providers


provider "linode" {
  token = var.linode_token
}

// begin vars

variable "linode_domain_id" {
  description = "domain ID per Linode Domains API"
  type = number
}

variable "instance_count" {
  description = "Number of Linodes to deploy"
  type        = number
  default = 2
}

variable "private_key" {
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

variable "linode_image" {
  description = "Image to build from"
  default = "linode/almalinux8"
}

variable "label" {
  description = "Human-friendly name"
  default = "mediawiki_web"
}

variable "region" {
  description = "Linode region"
  default = "us-southeast"
}

variable "tls_cert" {
  description = "web server TLS certificate"
  type = string

}

variable "tls_key" {
  description = "web server TLS private key"
  type = string
  sensitive = true
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

// end vars

// begin resources

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
    interface {
         purpose = "public"
     // public interfaces cannot have a label
       }
    interface {
      purpose = "vlan"
      label = "boofernet"
        }

    devices {
      sda {
        disk_label = "bootme"
        }
      }
    root_device = "sda"
        }
  provisioner "remote-exec" {
    inline = ["hostnamectl set-hostname ${var.label}_${count.index}"]

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

resource "linode_nodebalancer" "mediawiki_lb" {
  label = "mediawiki_lb"
  region = var.region
  client_conn_throttle = 10
}

resource "linode_nodebalancer_config" "clear_config" {
  nodebalancer_id = linode_nodebalancer.mediawiki_lb.id
  port = 80
  protocol = "http"
  check = "connection"
  check_attempts = 3
  check_interval = 30
  check_timeout = 5
  stickiness = "http_cookie"
  algorithm = "source"

}

resource "linode_nodebalancer_config" "secure_config" {
  nodebalancer_id = linode_nodebalancer.mediawiki_lb.id
  port = 443
  protocol = "https"
  check = "connection"
  check_attempts = 3
  check_interval = 30
  check_timeout = 5
  stickiness = "http_cookie"
  algorithm = "source"
  ssl_cert = var.tls_cert
  ssl_key = var.tls_key
}


resource "linode_nodebalancer_node" "clear_upstreams" {
  count = var.instance_count
  nodebalancer_id = linode_nodebalancer.mediawiki_lb.id
  config_id = linode_nodebalancer_config.clear_config.id
  address ="${element(linode_instance.webhead.*.private_ip_address, count.index)}:80"
  label = "${var.label}_clear_mw_lb"
}

resource "linode_nodebalancer_node" "secure_upstreams" {
  count = var.instance_count
  nodebalancer_id = linode_nodebalancer.mediawiki_lb.id
  config_id = linode_nodebalancer_config.secure_config.id
  address ="${element(linode_instance.webhead.*.private_ip_address, count.index)}:80"
  label = "${var.label}_secure_mw_lb"
}


resource "linode_domain_record" "mediawiki_a_record" {
  domain_id = var.linode_domain_id
  name = "mw"
  record_type = "A"
  target = linode_nodebalancer.mediawiki_lb.ipv4
  }

  resource "linode_domain_record" "mediawiki_aaaa_record" {
    domain_id = var.linode_domain_id
    name = "mw"
    record_type = "AAAA"
    target = linode_nodebalancer.mediawiki_lb.ipv6
    }
