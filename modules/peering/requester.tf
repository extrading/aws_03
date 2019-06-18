provider "aws" {
  alias = "requester"
}

data "aws_caller_identity" "requester" {
  provider = "aws.requester"
  count    = "${var.module_enabled ? 1 : 0}"
}

data "aws_region" "requester" {
  provider = "aws.requester"
  count    = "${var.module_enabled ? 1 : 0}"
}

data "aws_vpc" "requester" {
  provider = "aws.requester"
  count    = "${var.module_enabled ? 1 : 0}"
  id       = "${var.requester_vpc_id}"
}

resource "aws_vpc_peering_connection" "requester" {
  provider      = "aws.requester"
  count         = "${var.module_enabled ? 1 : 0}"
  vpc_id        = "${data.aws_vpc.requester.id}"
  peer_vpc_id   = "${data.aws_vpc.accepter.id}"
  peer_owner_id = "${data.aws_caller_identity.accepter.account_id}"
  peer_region   = "${data.aws_region.accepter.name}"
  auto_accept   = false
  tags          = "${merge(local.tags, map("Name", format("vpc-peering-%s", local.workspace)))}"
}

resource "aws_vpc_peering_connection_options" "requester" {
  provider                  = "aws.requester"
  count                     = "${var.module_enabled ? 1 : 0}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester.*.id[0]}"

  requester {
    allow_remote_vpc_dns_resolution = "${data.aws_region.requester.name == data.aws_region.accepter.name ? true : false}"
  }

  depends_on = ["aws_vpc_peering_connection_accepter.accepter"]
}

resource "aws_route" "from_requester_to_accepter" {
  provider                  = "aws.requester"
  count                     = "${var.module_enabled ? 3 : 0}"
  route_table_id            = "${var.requester_rts[count.index]}"
  destination_cidr_block    = "${data.aws_vpc.accepter.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.requester.*.id[0]}"
}
