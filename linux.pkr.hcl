packer {
  required_plugins {
    amazon = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/amazon" #Ref.: https://github.com/hashicorp/packer-plugin-amazon
    }
  }
}

/* CodePipeline Enviroment Variables */
variable "AWS_REGION" {
  type    = string
  default = env("AWS_REGION")
}

variable "VPCID" {
  type    = string
  default = env("VPCID")
}

variable "SubnetID" {
  type    = string
  default = env("SubnetID")
}

/* Locals Enviroment Variables */
variable "ami_name_prefix" {
  type    = string
  default = "linux"
}

#Use: instance_type = var.instance_type["type1"]
variable "instance_type" {
  type = map(string)
  default = {
    "type1" = "t2.micro"
    "type2" = "t2.small"
    "type3" = "t2.medium"
  }
}

locals {
  ami_name      = join("-", [var.ami_name_prefix, formatdate("MMDDYYYY-hmmss", timestamp())])
  tag_timestamp = formatdate("MM-DD-YYYY hh:mm:ss", timestamp())
}

/* Main AMI Build Definition */
source "amazon-ebs" "main" {
  ami_name                    = local.ami_name
  instance_type               = var.instance_type["type1"]
  region                      = var.AWS_REGION
  ssh_username                = "ec2-user"
  ssh_interface               = "session_manager"
  communicator                = "ssh"
  associate_public_ip_address = false
  skip_region_validation      = true
  temporary_iam_instance_profile_policy_document {
    Statement {
      Effect = "Allow"
      Action = [
        "ssm:StartSession",
        "ssm:DescribeAssociation",
        "ssm:GetDeployablePatchSnapshotForInstance",
        "ssm:GetDocument",
        "ssm:DescribeDocument",
        "ssm:GetManifest",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:ListAssociations",
        "ssm:ListInstanceAssociations",
        "ssm:PutInventory",
        "ssm:PutComplianceItems",
        "ssm:PutConfigurePackageResult",
        "ssm:UpdateAssociationStatus",
        "ssm:UpdateInstanceAssociationStatus",
        "ssm:UpdateInstanceInformation",
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
        "ec2messages:AcknowledgeMessage",
        "ec2messages:DeleteMessage",
        "ec2messages:FailMessage",
        "ec2messages:GetEndpoint",
        "ec2messages:GetMessages",
        "ec2messages:SendReply"
      ]
      Resource = ["*"]
    }
    Version = "2012-10-17"
  }
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 35
    volume_type           = "gp2"
    delete_on_termination = true
  }
  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name                = "amzn2-ami-hvm*"
      root-device-type    = "ebs"
    }
    owners      = ["amazon"]
    most_recent = true
  }
  aws_polling {
    delay_seconds = 30
    max_attempts  = 120
  }
  tags = {
    Name            = local.ami_name
    CreatedBy       = "CodeBuild - AMI-Builder"
    AMICreationDate = local.tag_timestamp
    Base_AMI_ID     = "{{ .SourceAMI }}"
    Base_AMI_Name   = "{{ .SourceAMIName }}"
  }
}

/* Build Execution */
build {
  sources = [
    "source.amazon-ebs.main"
  ]

  provisioner "shell" {
    environment_vars = [
      "AWS_REGION=${var.AWS_REGION}",
      "VPCID=${var.VPCID}",
      "SubnetID=${var.SubnetID}",
    ]
    inline = [
      "echo AWS Region: $AWS_REGION",
      "echo VPC ID: $VPCID",
      "echo Private Subnet ID: $SubnetID"
    ]
  }

  # Install Docker
  provisioner "shell" {
    inline = [
      "yum update -y",
      "yum install jq -y",
      "amazon-linux-extras install docker -y",
      "service docker start"
    ]
  }

  # Add the Ubuntu user to the docker group
  provisioner "shell" {
    inline = [
      "sudo usermod -aG docker ec2-user"
    ]
  }

  # Pull and run the demo app.
  provisioner "shell" {
    inline = [
      "docker pull jmanzur/demo-lb-app:v1.2",
      "docker run --restart=always -d -p 8882:8882 --name DEMO-LB-APP $(docker images --filter 'reference=jmanzur/demo-lb-app' --format '{{.ID}}')"
    ]
  }
}