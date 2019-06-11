locals {
  workspace = "${lower(terraform.workspace)}"
  tags      = "${merge(var.tags, map("workspace", local.workspace, "module", "vpc-peering-${local.workspace}"))}"
}

variable "tags" {
  description = "Set of default tags to be used for every resource."
  type        = "map"

  default = {
    env       = "dev"
    managedBy = "Terraform"
  }
}

variable "module_enabled" {
  description = "Enable or Disable vpc peering."
  default     = false
}

variable "accepter_vpc_id" {
  description = "VPC ID of accepter vpc."
}

variable "requester_vpc_id" {
  description = "VPC ID of requester vpc."
}

variable "module_depends_on" {
  description = "Emulation of depends_on for modules"
  type        = "list"
  default     = []
}
