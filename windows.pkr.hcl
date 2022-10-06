packer {
  required_plugins {
    amazon = {
      version = ">= 1.1.1"
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
  default = "windows"
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
  user_data_file              = "./scripts/windows/bootstrap_winrm.txt"
  communicator                = "winrm"
  winrm_insecure              = true
  winrm_username              = "Administrator"
  winrm_use_ssl               = true
  associate_public_ip_address = false
  skip_region_validation      = true
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 35
    volume_type           = "gp2"
    delete_on_termination = true
  }
  source_ami_filter {
    filters = {
      name                = "Windows_Server-2022-English-Full-Base-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["801119661308"]
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

  # Bootstrap windows
  provisioner "powershell" {
    script = "./scripts/windows/Bootstrap-Windows.ps1"
  }

  # Install Notepad++
  provisioner "powershell" {
    script = "./scripts/windows/install-notepad.ps1"
  }

  # Execute Sysprep: Removes computer-specific information
  provisioner "powershell" {
    script = "./scripts/windows/syspred.ps1"
  }
}