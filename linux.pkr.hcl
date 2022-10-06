packer {
  required_plugins {
    amazon = {
      version = "<= 1.0.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

/* CodeBuil Enviroment Variables */
variable "AWS_REGION" {
  type    = string
  default = env("AWS_REGION")
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
  ssh_username                = "ubuntu"
  associate_public_ip_address = false
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 35
    volume_type           = "gp2"
    delete_on_termination = true
  }
  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
    }
    owners      = ["099720109477"]
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

  # Update and Upgrade
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y"
    ]
  }

  # Install Docker and Docker-Compose
  provisioner "shell" {
    inline = [
      "sudo apt-get install docker -y",
      "sudo apt-get install docker-compose -y"
    ]
  }

  # Add the Ubuntu user to the docker group
  provisioner "shell" {
    inline = [
      " sudo usermod -aG docker ubuntu",
    ]
  }

  # Pull and run the demo app.
  provisioner "shell" {
    inline = [
      "docker pull jmanzur/demo-lb-app:v1.1",
      "docker run --restart=always -d -p 5000:5000 --name DEMO-LB-APP $(docker images --filter 'reference=jmanzur/demo-lb-app' --format '{{.ID}}')"
    ]
  }
}