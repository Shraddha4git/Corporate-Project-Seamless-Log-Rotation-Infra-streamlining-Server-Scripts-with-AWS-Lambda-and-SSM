resource "aws_iam_role" "ec2_role" {
  name = "ec2-access-s3-and-ssm"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_policy" "ec2_policy" {
  name        = "ec2-s3-ssm-policy"
  description = "Policy for EC2 to access S3 and SSM"
  policy      = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:ListBucket",
          "ssm:DescribeInstanceInformation",
          "ssm:ListCommandInvocations",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommands",
          "ssm:DescribeInstanceStatus",
          "ssm:PutInventory",
          "ssm:GetInventory",
          "ssm:UpdateInstanceInformation",
          "ssmmessages:*",
          "ec2messages:*",
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:StartInstances",
          "ec2:StopInstances"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ec2_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}
# EC2 Instances for TG1
resource "aws_instance" "tg1_instance" {
  count             = 3
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  ami               = "ami-06fdd095145a1fd48" # "ami-08adadd5fc6f510cd"
  instance_type     =  "c6a.xlarge" # "t2.micro" #
  subnet_id         = element(var.private_subnet_ids, count.index % 2)
  vpc_security_group_ids = [var.ec2_security_group_id]
  associate_public_ip_address = false
  key_name = "tf-10-24-test-key-pair"  
  tags = {
    Name = "tf-tg1-instance-${count.index + 1}"
  }

  lifecycle {
    create_before_destroy = true
  }
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
    sudo systemctl enable amazon-ssm-agent
    sudo systemctl start amazon-ssm-agent
    sudo systemctl status amazon-ssm-agent

    # Disable SELinux temporarily for testing (use with caution)
    setenforce 0

    # Create index.html in Tomcat's ROOT directory
    cat <<EOL > /apache-tomcat-9.0.90/webapps/ROOT/index.html
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Instance Status</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                color: #ffffff;
                background-color: #f76f93;
                text-align: center;
                padding: 90px;
            }
            .container {
                background-color: #55435c;
                border-radius: 10px;
                padding: 30px;
                display: inline-block;
            }
            h1 {
                color: #ffffff;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1> Instance $((${count.index} + 1)) is running in the Target Group 1 </h1>
        </div>
    </body>
    </html>
    EOL

    # Update and install Apache Tomcat
    # Assuming the tomcat service is already installed and configured

    # Create a log generation script
    cat <<'EOL' > /tmp/generate_logs.sh
    #!/bin/bash
    LOG_FILE="/apache-tomcat-9.0.90/logs/catalina.out"
    # Check if the log file is writable and add a random log entry
    # while true; do
    echo "\$(date +'%Y-%m-%d %H:%M:%S') Random log entry: \$(shuf -i 1-1000 -n 1) Random Text: \$(tr -dc A-Za-z0-9 </dev/urandom | head -c 18)" >> "\$LOG_FILE"
    # sleep 60  # Adjust the interval as needed
    # done
    EOL
    # Make the script executable
    chmod +x /tmp/generate_logs.sh
    # sudo sh /tmp/generate_logs.sh
    
    # Add the script to crontab to run every minute
    (crontab -l 2>/dev/null; echo "* * * * * /tmp/generate_logs.sh") | crontab -

    # Copy the restart-tomcat.sh script from the Terraform module to /tmp
    cat <<'EOL' > /tmp/restart-tomcat.sh
    ${file("${path.module}/restart-tomcat.sh")}
    EOL

    # Make restart-tomcat.sh executable
    chmod +x /tmp/restart-tomcat.sh

    # Wait for 30 seconds before starting Tomcat to ensure the system is fully up
    sleep 30
    systemctl start tomcat.service
EOF
  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("keys/tf-10-24-test-key-pair.pem")
    host = self.public_ip 
  }
}

# Target Group Attachment for TG1
resource "aws_lb_target_group_attachment" "tg1_attachment" {
  count              = 3
  target_group_arn   = var.tg1_arn
  target_id          = aws_instance.tg1_instance[count.index].id
}
