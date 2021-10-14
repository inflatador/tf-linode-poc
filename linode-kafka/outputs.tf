output "linode_kafka_kraft_pub_ipv4s" {
  value = linode_instance.kafka_kraft.*.ip_address

}

output "linode_kafka_kraft_pub_ipv6" {
  value = [for ipv6 in linode_instance.kafka_kraft.*.ipv6 :
  split("/", ipv6)[0] ]
}
