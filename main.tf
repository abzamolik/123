variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "public_key" {}

provider "aws" {
  region = "ap-south-1" 
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Creating Data source for Elastic IP (
data "aws_eip" "existing_eip" {
  public_ip = "3.111.71.29" 
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "main_vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}


# Create a Subnet
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "main_subnet"
  }
}

resource "aws_security_group" "main" {
  vpc_id = aws_vpc.main.id
  egress = [
    {
      cidr_blocks      = [ "0.0.0.0/0", ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
 ingress                = [
   {
     cidr_blocks      = [ "0.0.0.0/0", ]
     description      = ""
     from_port        = 22
     ipv6_cidr_blocks = []
     prefix_list_ids  = []
     protocol         = "tcp"
     security_groups  = []
     self             = false
     to_port          = 22
  }
  ]
}


resource "aws_key_pair" "deployer" {
  key_name   = "aws_key"
  public_key = var.public_key
}

# Create an S3 Bucket
resource "aws_s3_bucket" "bucket" {
  bucket_prefix = "my-bucket"
  tags = {
    Name = "my_bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "example" {
  depends_on = [aws_s3_bucket_ownership_controls.example]
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}


# Create an EFS File System
resource "aws_efs_file_system" "efs" {
  tags = {
    Name = "my_efs"
  }
}

# Create EFS Mount Target
resource "aws_efs_mount_target" "mount_target" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_subnet.main.id
}


resource "aws_instance" "ec2_example" {
    ami = "ami-0522ab6e1ddcc7055"  
    instance_type = "t2.micro" 
    key_name= "aws_key"
    vpc_security_group_ids = [aws_security_group.main.id]

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y amazon-efs-utils",
      "sudo mkdir -p /data/test",
      "sudo mount -t efs ${aws_efs_file_system.efs.id}:/ /data/test"
    ]
  }
  connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file("/Users/abhijeetamolik/aws/keys/aws_key")
      timeout     = "4m"
   }
}

