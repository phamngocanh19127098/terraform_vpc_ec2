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


# # 1. Create vpc

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "production"
  }
} 

# # 2. Create Internet Gateway

resource "aws_internet_gateway"  "gw" {
    vpc_id = aws_vpc.prod-vpc.id
    
    tags = {
      "Name" = "prod-gw"
    }
}

# # 3. Create Custom Route Table

resource "aws_route_table" "prod-route-table" {
    vpc_id = aws_vpc.prod-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id 
    }

    route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.gw.id
    }
}

# # 4. Create a Subnet
resource "aws_subnet" "prod-subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-southeast-1a"

    tags = {
      "Name" = "prod-subnet"
    }
}

# # 5 Associate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.prod-subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# # 6 Create a security group
resource "aws_security_group" "allow_web" {
    name = "allow_web_traffic"    
    description = "Allow web inbound traffic"
    vpc_id = aws_vpc.prod-vpc.id

    ingress {
        description = "HTTPS traffic"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTP traffic"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SSH traffic"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
    tags = {
      Name = "Allow web"
    }
}

# #7 Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "web-server-nic" {
    subnet_id = aws_subnet.prod-subnet-1.id
    private_ips = ["10.0.1.50"]
    security_groups = [aws_security_group.allow_web.id]
}

# #8 Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc = true
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.gw
  ]
}

# # 9 Create an Ubuntu Server and install/ enable apache2
resource "aws_instance" "my-ec2-instance" {
    ami = "ami-0a72af05d27b49ccb"
    instance_type = "t2.micro"
    key_name = "my_payment"
  
    network_interface {
        device_index =  0
        network_interface_id = aws_network_interface.web-server-nic.id
    }
  
    user_data = <<-EOF
        #!/bin/bash
        sudo apt update -y
        sudo apt install apache2 -y
        sudo systemctl start apache2
        sudo bash -c 'echo your verify web server > /var/www/html/index.html'
        EOF

    tags = {
        Name = "MEME"
    }
}

