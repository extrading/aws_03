provider "aws" {
  alias = "accepter"
}

data "aws_caller_identity" "accepter" {
  provider = "aws.accepter"
  count    = "${var.module_enabled ? 1 : 0}"
}

data "aws_region" "accepter" {
  provider = "aws.accepter"
  count    = "${var.module_enabled ? 1 : 0}"
}

data "aws_vpc" "accepter" {
  provider = "aws.accepter"
  count    = "${var.module_enabled ? 1 : 0}"
  id       = "${var.accepter_vpc_id}"
}

resource "aws_vpc_peering_connection_accepter" "accepter" {
  provider                  = "aws.accepter"
  count                     = "${var.module_enabled ? 1 : 0}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester.*.id[0]}"
  auto_accept               = true
  tags                      = "${merge(local.tags, map("Name", format("vpc-peering-%s", local.workspace)))}"
}

resource "aws_vpc_peering_connection_options" "accepter" {
  provider                  = "aws.accepter"
  count                     = "${var.module_enabled ? 1 : 0}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester.*.id[0]}"

  accepter {
    allow_remote_vpc_dns_resolution = "${data.aws_region.accepter.name == data.aws_region.requester.name ? true : false}"
  }

  depends_on = ["aws_vpc_peering_connection_accepter.accepter"]
}

resource "aws_route" "from_accepter_to_requester" {
  provider                  = "aws.accepter"
  count                     = "${var.module_enabled ? 3 : 0}"
  route_table_id            = "${var.accepter_rts[count.index]}"
  destination_cidr_block    = "${data.aws_vpc.requester.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester.*.id[0]}"
}
