data "aws_availability_zones" "available_azs" {
  state = "available"
}

data "aws_ami" "custom" {
  most_recent = true

  filter {
    name   = "tag:Name"
    values = ["talo-ami-2"]
  }

  # Specify your AWS account ID or use "self" for the current account
  owners = ["self"]
}

module "app_vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "5.8.1"

  name               = "${var.prefix}-vpc-${var.env}"
  cidr               = var.vpc_cidr

  azs                = data.aws_availability_zones.available_azs.names
  private_subnets    = var.vpc_private_subnets
  public_subnets     = var.vpc_public_subnets

  enable_nat_gateway = false

  tags = {
    Name      = "${var.prefix}-vpc-${var.env}"
    Env       = var.env
    Terraform = true
  }
}

/*
 Use resource blocks to define components of your infrastructure.
 A resource might be a physical or virtual component such as an EC2 instance.
 A resource block declares a resource of a given type ("aws_instance") with a given local name ("app_server").
 The name is used to refer to this resource from elsewhere in the same Terraform module, but has no significance outside that module's scope.
 The resource type and name together serve as an identifier for a given resource and so must be unique within a module.

 For full description of this resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
*/
resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.custom.id
  instance_type               = var.app_server_instance_type
  availability_zone           = var.azs[0]
  vpc_security_group_ids      = [aws_security_group.app_server_sg.id]
  key_name                    = var.key_pair_name
  subnet_id                   = module.app_vpc.public_subnets[0]
  iam_instance_profile        = aws_iam_instance_profile.app_server_profile.name
  user_data                   = "${file("./deploy.sh")}"
  associate_public_ip_address = true

  depends_on = [
    aws_s3_bucket.data_bucket
  ]

  tags = {
    Name      = "${var.prefix}-ec2-${var.env}"
    Env       = var.env
    Terraform = true
  }
}

resource "aws_security_group" "app_server_sg" {
  name   = "${var.prefix}-sg-${var.env}"
  vpc_id = module.app_vpc.vpc_id

  # Inbound rules
  ingress {
    from_port   = "8080"
    to_port     = "8080"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.prefix}-sg-${var.env}"
    Env       = var.env
    Terraform = true
  }
}

resource "aws_iam_role" "app_server_role" {
  name               = "${var.prefix}-role-${var.env}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "app_server_profile" {
  name = "${var.prefix}-profile-${var.env}"
  role = aws_iam_role.app_server_role.name
}

####################################################
# Create EBS Volume and attach to EC2 instance
####################################################

resource "aws_ebs_volume" "ebs_volume" {
  availability_zone    = var.azs[0]
  size                 = 5
  type                 = "gp2"
}

resource "aws_volume_attachment" "ebs_attachment" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs_volume.id
  instance_id = aws_instance.app_server.id
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.prefix}-s3-${var.env}"

  tags = {
    Name        = "${var.prefix}-s3-${var.env}"
    Env         = var.env
    Terraform   = true
  }
}