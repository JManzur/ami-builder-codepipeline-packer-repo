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

data "amazon-ami" "linux2" {
  filters = {
    virtualization-type = "hvm"
    name                = "amzn2-ami-hvm*"
    root-device-type    = "ebs"
  }
  owners      = ["amazon"]
  most_recent = true
}


data "amazon-ami" "ubuntu" {
    filters = {
        virtualization-type = "hvm"
        name = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
        root-device-type = "ebs"
    }
    owners = ["099720109477"]
    most_recent = true
}

/* Main AMI Build Definition */
source "amazon-ebs" "linux" {
  ami_name                    = local.ami_name
  instance_type               = var.instance_type["type1"]
  region                      = var.AWS_REGION
  source_ami                  = data.amazon-ami.ubuntu.id
  vpc_id                      = var.VPCID
  subnet_id                   = var.SubnetID
  associate_public_ip_address = true
  ssh_interface               = "public_ip"
  ssh_port                    = 22
  ssh_timeout                 = "15m"
  ssh_clear_authorized_keys   = true
  ssh_username                = "ubuntu"
  ssh_agent_auth              = false
  // temporary_key_pair_type     = "ed25519" #https://discuss.hashicorp.com/t/packer-unable-to-ssh-into-amazon-linux-2022/33519
  communicator                = "ssh"

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
    "source.amazon-ebs.linux"
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

  // # Install Docker
  // provisioner "shell" {
  //   inline = [
  //     "yum update -y",
  //     "yum install jq -y",
  //     "amazon-linux-extras install docker -y",
  //     "service docker start"
  //   ]
  // }

  // # Add the Ubuntu user to the docker group
  // provisioner "shell" {
  //   inline = [
  //     "sudo usermod -aG docker ec2-user"
  //   ]
  // }

  // # Pull and run the demo app.
  // provisioner "shell" {
  //   inline = [
  //     "docker pull jmanzur/demo-lb-app:v1.2",
  //     "docker run --restart=always -d -p 8882:8882 --name DEMO-LB-APP $(docker images --filter 'reference=jmanzur/demo-lb-app' --format '{{.ID}}')"
  //   ]
  // }
}