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

/* Main AMI Build Definition */
source "amazon-ebs" "linux" {
  ami_name      = local.ami_name
  instance_type = var.instance_type["type1"]
  region        = var.AWS_REGION
  source_ami    = data.amazon-ami.linux2.id
  ssh_username  = "ec2-user"
  communicator  = "ssh"

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

  # Install Docker
  provisioner "shell" {
    inline = [
      "sudo yum update -y",
      "sudo yum install jq -y",
      "sudo amazon-linux-extras install docker -y",
      "sudo service docker start"
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
      "sudo docker pull jmanzur/demo-lb-app:v1.2",
      "sudo docker run --restart=always -d -p 8882:8882 --name DEMO-LB-APP $(docker images --filter 'reference=jmanzur/demo-lb-app' --format '{{.ID}}')"
    ]
  }
}