provider "aws" {
    region = "us-east-1"
  
}

resource "aws_vpc" "my_vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
      Name = "my-vpc"
    }
  
}

resource "aws_subnet" "public_dev_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true 
  availability_zone       = "us-east-1a" 

  tags = {
    Name = "public-dev-subnet"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "internet-gateway"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}


resource "aws_route_table_association" "public_subnet_assoc" {
  subnet_id      = aws_subnet.public_dev_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

data "http" "my_ip" {
  url = "http://icanhazip.com"

}

resource "aws_security_group" "sum-sg" {
    name_prefix = "sum-sg-"
    vpc_id = aws_vpc.my_vpc.id

    ingress {
        from_port = 5000
        to_port = 5000
        protocol = "tcp"
        cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"]
    }

    tags = {
      Name = "dev_sg"
    }

}
data "aws_ami" "ubuntu" {
    most_recent = true
    owners = ["099720109477"]

    filter {
      name = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }

    filter {
      name = "virtualization-type"
      values = ["hvm"]
    }
  
}
resource "aws_instance" "flask_app" {
    ami = data.aws_ami.ubuntu.id
    instance_type = var.instance_type
    subnet_id = aws_subnet.public_dev_subnet.id
    vpc_security_group_ids = [aws_security_group.dev_sg.id]
    key_name = "eurokey"

    user_data = <<-EOF
#!/bin/bash
echo "Installing dependencies..."
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl start docker
echo "Pulling and running Docker container..."
sudo docker pull guylah/final_dev:latest
sudo docker run -d -p 5000:5000 guylah/final_dev:latest
EOF

    tags = {
      Name = "flask-app-dev"
    }
  
}