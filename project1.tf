provider "aws" {
    region = "us-east-1"
    access_key = ""
    secret_key = ""
}

# 1. Create VPC
# 2. Create Internet Gateway within VPC
# 3. Create a custom route table
# 4. Create a subnet
# 5. Associate subnet with Route Table
# 6. Create security group to allow port 22, 80, 443 (Determines what traffic can enter your EC2 instance)
# 7. Create a network interface with an IP in the subnet that was created in step 4
# 8. Assign an elastic IP to the network interface created in step 7
# 9. Create ubuntu server and install/enable apache2

# first step is to create a key pair in AWS console, which will allow us to connect to these devices

# create a vpc
resource "aws_vpc" "prodVPC" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# create the internet gateway
resource "aws_internet_gateway" "GW1" {
  vpc_id = aws_vpc.prodVPC.id
}

# create a custom route table
resource "aws_route_table" "RT1" {
  vpc_id = aws_vpc.prodVPC.id

# route for ipv4
  route {
    cidr_block = "0.0.0.0/0" # create a default route, this will send all ipv4 traffic wherever this route points
    gateway_id = aws_internet_gateway.GW1.id
  }

# route for ipv6
  route {
    ipv6_cidr_block = "::/0"
    egress_only_gateway_id = aws_internet_gateway.GW1.id
  }

  tags = {
    Name = "production"
  }
}


# create a subnet for the web server to reside on
resource "aws_subnet" "subnet1" {
  vpc_id = aws_vpc.prodVPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prodSubnet"
  }
}

# assign subnet to route table
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.subnet1.id
  route_table_id = aws_route_table.RT1.id
}

# create a security group
resource "aws_security_group" "allowWeb" {
  name = "allowWebTraffic"
  description = "Allow TLS inbound traffic"
  vpc_id = aws_vpc.prodVPC.id

  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1" # means any protocol
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allowWeb"
  }
}

resource "aws_network_interface" "webServerNic" {
    # this creates the private IP address for the web server
    subnet_id = aws_subnet.subnet1.id
    private_ips = ["10.0.1.50"]
    security_groups = [aws_security_group.allowWeb.id]
}

# create a public IP for the web server
# deploying an elastic IP requires an internet gateway
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.webServerNic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.GW1 ] # reference the whole object not just the ID
}

# create ubuntu server and install/enable apache2
resource "aws_instance" "webServerInstance" {
  ami = "ami-0230bd60aa48260c6"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "KP1"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.webServerNic.id
  }

  # tell terraform to run a few commands on this server after it's spun up
  # this will be a bash script
  user_data = <<-EOF
            !#/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c 'echo your very first web server > /var/www/html/index.html'
            EOF
  tags = {
    Name = "webServer"
  }
}




# aws doesn't let you make a stop each time you're about to spend money
# a solution to this is, at least for terraform code is to just test it and not actually run it

# for some reason the shell isn't recognizing terraform
# I think it's cause I fucked up my original path variable, how to reset it?

# end active AWS services 
# def make sure not getting charged for more shit