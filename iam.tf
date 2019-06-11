resource "random_pet" "stack_name" {}

resource "aws_iam_instance_profile" "this" {
  provider = "aws.lab_vpc"
  name     = "${random_pet.stack_name.id}"
  role     = "${aws_iam_role.this.name}"
}

resource "aws_iam_role" "this" {
  provider           = "aws.lab_vpc"
  name               = "role_${random_pet.stack_name.id}"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  provider = "aws.lab_vpc"

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "this" {
  provider = "aws.lab_vpc"
  name     = "${random_pet.stack_name.id}"
  path     = "/"
  policy   = "${data.aws_iam_policy_document.this.json}"
}

resource "aws_iam_role_policy_attachment" "this" {
  provider   = "aws.lab_vpc"
  role       = "${aws_iam_role.this.name}"
  policy_arn = "${aws_iam_policy.this.arn}"
}

data "aws_iam_policy_document" "this" {
  provider = "aws.lab_vpc"

  statement {
    actions = ["ssm:*"]

    resources = [
      "arn:aws:ssm:*:*:parameter/inventory-app/*",
    ]
  }
}
