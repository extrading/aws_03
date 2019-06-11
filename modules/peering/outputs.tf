output "peering_connection_id" {
  value = "${element(concat(aws_vpc_peering_connection.requester.*.id, aws_vpc_peering_connection_accepter.accepter.*.id, list("")), 0)}"
}
