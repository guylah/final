provider "aws" {
    region = "us-east-1"
  
}

resource "aws_vpc" "my_vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
      Name = "my-vpc"
    }
  
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true 
  availability_zone       = "us-east-1a" 

  tags = {
    Name = "public-subnet-1"
  }
}
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true 
  availability_zone       = "us-east-1b" 

  tags = {
    Name = "public-subnet-2"
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


resource "aws_route_table_association" "public_subnet_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}
  
resource "aws_security_group" "sum-sg" {
    name_prefix = "sum-sg-"
    vpc_id = aws_vpc.my_vpc.id

    ingress {
        from_port = 5000
        to_port = 5000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "sum-sg"
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


resource "aws_lb" "prod_lb" {
  name = "prod-lb"
  load_balancer_type = "application"
  subnets = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  security_groups = [aws_security_group.sum-sg.id]
  
}
resource "aws_lb_listener" "prod-listener" {
  load_balancer_arn = aws_lb.prod_lb.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.prod_target.arn
  }
  
}
resource "aws_lb_target_group" "prod_target" {
  name = "prod-target"
  port = "5000"
  protocol = "HTTP"
  vpc_id = aws_vpc.my_vpc.id
  target_type = "instance"

  health_check {
    path = "/"
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
  
}
resource "aws_lb_target_group_attachment" "prod_attach" {
  count = 2
  target_group_arn = aws_lb_target_group.prod_target.arn
  target_id = aws_instance.flask_app[count.index].id
  port = 5000
  
}

resource "aws_launch_configuration" "launch_config" {
  name_prefix = "launch-config"
  image_id = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.sum-sg.id]

  user_data = <<-EOF
#!/bin/bash
echo "Installing dependencies..."
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl start docker
echo "Pulling and running Docker container..."
sudo docker pull guylah/summary:latest
sudo docker run -d -p 5000:5000 guylah/summary:latest
EOF

  lifecycle {
    create_before_destroy = true
  }

}
resource "aws_autoscaling_group" "prod_auto_scaler" {
  name = "prod-auto-scaler"
  launch_configuration = aws_launch_configuration.launch_config.name
  min_size = 2
  max_size = 4
  desired_capacity = 2
  target_group_arns = [aws_lb_target_group.prod_target.arn]
  vpc_zone_identifier = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tag {
    key = "Name"
    value = "flask-app"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
  
}