variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

provider "aws" {
  region = "ap-southeast-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}


resource "aws_security_group_rule" "allow_ssh" {
  type = "ingress"
  security_group_id = "${data.aws_security_group.example.id}"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}


resource "aws_vpc" "public" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "name" {
   cidr_block = "10.0.1.0/24"
   vpc_id = aws_vpc.public.id

}

data "aws_security_group" "example" {
  vpc_id      = aws_vpc.public.id
}


resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.public.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.public.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.name.id
  route_table_id = aws_route_table.public.id

}

resource "aws_instance" "ec2" {
  ami = "ami-0e2e292a9c4fb2f29"
  instance_type = "t2.micro"
  key_name      = "my_payment"
  subnet_id     = aws_subnet.name.id
  associate_public_ip_address = true
  security_groups = [data.aws_security_group.example.id]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/home/anhpham/Downloads/my_payment.pem")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y update",
      "sudo yum -y install httpd",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd"
    ]
  }
}
