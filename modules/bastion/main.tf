resource "aws_iam_role" "instance_connect_role" {
  name = "InstanceConnectRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "instance_connect_policy" {
  name        = "instance_connect_policy"
  description = "My test policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:SendSSHPublicKey*",
          "ec2:Describe*",
          "ec2:StopInstances",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListObject"

        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
resource "aws_iam_role_policy_attachment" "attach_instance_connect_policy" {
  policy_arn = aws_iam_policy.instance_connect_policy.arn
  role = aws_iam_role.instance_connect_role.name
}



resource "aws_security_group" "bastion_sg" {
    vpc_id = (var.vpc_id)
   ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  /*
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = element(var.private_subnet_ids)
    # security_groups = [var.private_subnet_ids]
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["13.233.177.0/29"]  # best practice cidr block of bastion 
  }
 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24","10.0.1.0/24"] 
  }
   */
    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "tf-bastion-sg"
  }
}

# Bastion Host server
resource "aws_instance" "bastion" {
  ami = "ami-08718895af4dfa033" # linux2
  instance_type = "t3.medium"# "t2.micro"
  subnet_id = (var.public_subnet_ids[0])
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name = "tf-10-24-test-key-pair"
    # Provisioner to run commands after instance creation
  
  provisioner "remote-exec" {
    inline = [ 
      "mkdir -p ~/.ssh",
      "touch ~/.ssh/tf-10-24-test-key-pair.pem",
      "echo '${file("keys/tf-10-24-test-key-pair.pem")}' > ~/.ssh/tf-10-24-test-key-pair.pem",
      "chmod 700 ~/.ssh/tf-10-24-test-key-pair.pem",
      "chmod 700 ~/.ssh/authorized_keys",
      "chmod 700 ~/.ssh"
     ]
     }

    connection {
      type = "ssh"
      user = "ec2-user"
      private_key = file("keys/tf-10-24-test-key-pair.pem")
      host = self.public_ip
    }

user_data = <<-EOF
  #!/bin/bash
  sudo yum update -y
  sudo yum install telnet -y
  sudo yum install httpd -y
  sudo yum install -y aws cli
EOF
  tags = {
    Name = "tf-bastion-server-32451"
  }
}


output "bastion-server-public_ip" {
  description = "Bastion-server-public-ip"
  value = aws_instance.bastion.public_ip
}
output "bastion_security_group_id" {
  value = aws_security_group.bastion_sg.id
}
variable "private_subnet_ids" {
}
variable "public_subnet_ids" {
}
variable "vpc_id" {
}
/*
resource "aws_instance" "tf-database-server" {
  ami               = ""
  instance_type     =  "t2.micro" #
  # security_groups    = [var.ec2_security_group_id] (Optional, EC2-Classic and default VPC only) List of security group names to associate with.
  subnet_id         = (var.private_subnet_ids[0])
  vpc_security_group_ids = [var.ec2_security_group_id]
  associate_public_ip_address = true
  key_name = "tf-10-24-test-key-pair"  
  tags = {
    Name = "tf-database-server"
  }
}
variable "ec2_security_group_id" {
}*/