resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tf-log-rotation"
  }
}
data "aws_availability_zones" "available" { 
}
resource "aws_subnet" "public" {
  count             = 2
  vpc_id           = aws_vpc.main.id
  cidr_block       = "10.0.${count.index}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
   tags = {
    Name = "tf-Public-Subnet-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id           = aws_vpc.main.id
  cidr_block       = "10.0.${count.index + 2}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
   tags = {
    Name = "tf-Private-Subnet-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "tf-ig-log-rotation"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id    = aws_subnet.public[0].id
  tags = {
    Name = "tf-nat-log-rotation"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  depends_on = [ aws_internet_gateway.ig ]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }
}

resource "aws_route_table_association" "public" {
  count = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private" {
  count = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Groups
resource "aws_security_group" "alb_sg" {
  name = "tf-alb-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 1
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "tf-alb-sg"
  }
}

resource "null_resource" "detach_enis" {
  provisioner "local-exec" {
    command = <<EOT
      for eni_id in $(aws ec2 describe-network-interfaces --filters Name=attachment.instance-owner-id,Values=amazon-lambda --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text); do
        aws ec2 detach-network-interface --attachment-id $(aws ec2 describe-network-interfaces --network-interface-ids $eni_id --query 'NetworkInterfaces[*].Attachment.AttachmentId' --output text)
        aws ec2 delete-network-interface --network-interface-id $eni_id
      done
    EOT
  }
  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id
  name = "tf-ec2-sg"
  depends_on = [ null_resource.detach_enis ]
/*
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }*/

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [var.bastion_security_group_id] 
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    # security_groups = [aws_security_group.alb_sg.id] # this is requried
     cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 23
    to_port     = 23
    protocol    = "tcp"
    security_groups = [var.bastion_security_group_id] 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "tf-ec2-sg"
  }
}
