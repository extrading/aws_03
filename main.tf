provider "aws" {
  alias  = "lab_vpc"
  region = "eu-central-1"
}

provider "aws" {
  alias  = "shared_vpc"
  region = "eu-central-1"
}

module "shared_vpc" {
  providers = {
    aws = "aws.shared_vpc"
  }

  source                = "./modules/vpc/"
  vpc_cidr              = "10.5.0.0/21"
  whitelist_cidr_blocks = ["10.5.0.0/32"]
}

module "lab_vpc" {
  providers = {
    aws = "aws.lab_vpc"
  }

  source                = "./modules/vpc/"
  vpc_cidr              = "10.0.0.0/21"
  whitelist_cidr_blocks = ["10.0.0.0/32"]
}

module "vpc_peering" {
  providers = {
    aws.requester = "aws.lab_vpc"
    aws.accepter  = "aws.shared_vpc"
  }

  source           = "./modules/peering/"
  module_enabled   = true
  accepter_vpc_id  = "${module.shared_vpc.vpc_id}"
  requester_vpc_id = "${module.lab_vpc.vpc_id}"

  module_depends_on = [
    "${module.lab_vpc.public_route_table}",
    "${module.lab_vpc.private_route_table}",
    "${module.shared_vpc.public_route_table}",
    "${module.shared_vpc.private_route_table}",
  ]
}

resource "aws_security_group" "app" {
  provider    = "aws.lab_vpc"
  name        = "App-SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${module.lab_vpc.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  provider    = "aws.shared_vpc"
  name        = "DB-SG"
  description = "Allow DB access"
  vpc_id      = "${module.shared_vpc.vpc_id}"

  ingress {
    description     = "Application accessing ports of MYSQL/Aurora"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.app.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "this" {
  provider   = "aws.shared_vpc"
  name       = "${random_pet.stack_name.id}"
  subnet_ids = ["${module.shared_vpc.private_subnets}"]
}

resource "aws_db_instance" "this" {
  provider               = "aws.shared_vpc"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  identifier             = "inventory-db"
  name                   = "inventory"
  username               = "master"
  password               = "lab-password"
  db_subnet_group_name   = "${aws_db_subnet_group.this.name}"
  vpc_security_group_ids = ["${aws_security_group.db.id}"]
  multi_az               = false
  skip_final_snapshot    = true
  apply_immediately      = true
}

# resource "random_string" "better_way" {
#   length = 16
#   special = true
# }

# resource "aws_db_instance" "example" {
#   password = "${random_string.better_way.result}"
# }

data "aws_ami" "this" {
  provider    = "aws.lab_vpc"
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "template_file" "user_data" {
  template = "${file("${path.module}/user-data.sh")}"
}

resource "aws_instance" "web" {
  provider                    = "aws.lab_vpc"
  ami                         = "${data.aws_ami.this.id}"
  instance_type               = "t2.micro"
  subnet_id                   = "${element(module.lab_vpc.public_subnets, 0)}"
  vpc_security_group_ids      = ["${aws_security_group.app.id}"]
  user_data                   = "${data.template_file.user_data.rendered}"
  key_name                    = "${aws_key_pair.this.key_name}"
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.this.id}"

  tags = {
    Name = "App Server"
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  provider   = "aws.lab_vpc"
  key_name   = "${random_pet.stack_name.id}"
  public_key = "${tls_private_key.this.public_key_openssh}"
}
