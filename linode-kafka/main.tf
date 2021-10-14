// begin tf and provider info

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

// end providers

// begin resources

resource "linode_sshkey" "homekey" {
  label = "foo"
  ssh_key = chomp(file("~/.ssh/id_ed25519.pub"))
}

resource "random_string" "rootpw" {
  length = 32
  special = true
}

resource "random_integer" "private_ip_var" {
  min = 5
  max = 240
}

// begin kafka zookeeper

// resource "linode_instance" "kafka_zk" {
//   count = 1
//   group = var.group
//   tags = var.tags
//   label = "${var.zk_label}_${count.index}"
//   // image = var.linode_image
//   // packer-built private image
//   region = var.region
//   type = var.instance_type
//   // stackscripts not permitted on custom imags
//   // stackscript_id = var.stackscript_id
//   private_ip = true
//   disk {
//     label = "bootme"
//     image = var.linode_image
//     size = var.linode_disk_size
//     authorized_keys = [linode_sshkey.homekey.ssh_key]
//     root_pass = random_string.rootpw.result
//   }
//
//   config {
//     label = "linode_boot_config"
//     kernel = "linode/grub2"
//     interface {
//       purpose = "public"
//   // public interfaces cannot have a label
//     }
//     interface {
//       purpose = "vlan"
//       label = "boofernet"
//       ipam_address = "172.24.109.2${count.index}/24"
//       // ipam_address = "172.24.109.${random_integer.private_ip_var.result}/24"
//         }
//     devices {
//       sda {
//         disk_label = "bootme"
//         }
//       }
//     root_device = "sda"
//         }
//   provisioner "remote-exec" {
//     inline = ["hostnamectl set-hostname ${var.zk_label}_${count.index}"]
//
//     connection {
//       host = self.ip_address
//       type = "ssh"
//       user = "root"
//       private_key = file(var.private_key)
//
//     }
//   }
//
//   provisioner "local-exec" {
//     command = "sleep 100; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u root -i ',${self.ip_address}' /Users/gizzmonic/code/riichilab/ansible-roles/linode-kafka-zk.yml"
//
//   }
//
//   boot_config_label = "linode_boot_config"
// }
// end kafka zookeeper


// begin kafka kraft
resource "linode_instance" "kafka_kraft" {
  count = 3
  group = var.group
  tags = var.tags
  label = "${var.kraft_label}_${count.index}"
  // image = var.linode_image

  region = var.region
  type = var.instance_type
  // stackscripts not permitted on custom images
  // stackscript_id = var.stackscript_id
  private_ip = true
  disk {
    label = "bootme"
  // packer-built private image
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
      label = "inside"
      ipam_address = "172.17.147.1${count.index}/24"
        }
    devices {
      sda {
        disk_label = "bootme"
        }
      }
    root_device = "sda"
        }
  provisioner "remote-exec" {
    inline = ["hostnamectl set-hostname ${var.kraft_label}_${count.index}"]

    connection {
      host = self.ip_address
      type = "ssh"
      user = "root"
      private_key = file(var.private_key)

    }
  }

  provisioner "local-exec" {
    command = "sleep 100; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u root -i ',${self.ip_address}' /Users/gizzmonic/code/riichilab/ansible-roles/linode-kafka-kraft.yml"

  }

  boot_config_label = "linode_boot_config"
}

// end kafka kraft

// begin DNS resources

// resource "linode_domain_record" "kafka_zk_a_records" {
//   count = length(linode_instance.kafka_zk)
//   domain_id = var.linode_domain_id
//   name = "${element(linode_instance.kafka_zk.*.label, count.index)}"
//   record_type = "A"
//   target = "${element(linode_instance.kafka_zk.*.ip_address, count.index)}"
//   }
//
// resource "linode_domain_record" "kafka_zk_aaaa_records" {
//   count = length(linode_instance.kafka_kraft)
//   domain_id = var.linode_domain_id
//   name = "${element(linode_instance.kafka_zk.*.label, count.index)}"
//   record_type = "AAAA"
//   target = split("/", "${element(linode_instance.kafka_zk.*.ipv6, count.index)}").0
//   }

resource "linode_domain_record" "kafka_kraft_a_records" {
  count = var.instance_count
  domain_id = var.linode_domain_id
  name = "${element(linode_instance.kafka_kraft.*.label, count.index)}"
  record_type = "A"
  target = "${element(linode_instance.kafka_kraft.*.ip_address, count.index)}"
  }

resource "linode_domain_record" "kafka_kraft_aaaa_records" {
  count = var.instance_count
  domain_id = var.linode_domain_id
  name = "${element(linode_instance.kafka_kraft.*.label, count.index)}"
  record_type = "AAAA"
  target = split("/", "${element(linode_instance.kafka_kraft.*.ipv6, count.index)}").0
  }


// end DNS resources
