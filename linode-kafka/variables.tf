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

variable "kraft_label" {
  description = "Human-friendly name"
  default = "bigbag_kafka_kraft"
}

variable "zk_label" {
  description = "Human-friendly name"
  default = "bigbag_kafka_zk"
}

variable "region" {
  description = "Linode region"
  default = "us-southeast"
}

variable "tags" {
  description = "linode tags"
  type = list
  default = ["kafka"]
}

variable "group" {
  description = "linode instance grouping"
  type = string
  default = "kafka"
}


variable "instance_type" {
  description = "Cloud server flavor"
  default = "g6-standard-1"
}

variable "stackscript_id" {
  description = "provisioning script ID"
  type = number
  default = 909122
}

// end vars
