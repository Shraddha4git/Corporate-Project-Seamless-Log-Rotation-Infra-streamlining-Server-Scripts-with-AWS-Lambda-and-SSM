# EC2 Instances for TG2
resource "aws_instance" "tg2_instance" {
  count             = 3
  iam_instance_profile = (var.iam_instance_profile_name)
  ami               = "ami-06fdd095145a1fd48"#"ami-08adadd5fc6f510cd"
  instance_type     =  "c6a.xlarge" # "t2.micro" #
  vpc_security_group_ids = [var.ec2_security_group_id]
  subnet_id         = element(var.private_subnet_ids, count.index % 2)
  associate_public_ip_address = false
  key_name = "tf-10-24-test-key-pair"
  tags = {
    Name = "tf-tg2-instance-${count.index + 1}"
  }
  lifecycle {
   #  prevent_destroy = true # This prevents accidental destruction of instances.
   prevent_destroy = false # for testing purpose
   # ignore_changes = [ "ami", "instance_type", "instance_state" ]
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
                background-color: #b1f7a6;
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
            <h1> Instance $((${count.index} + 1)) is running in the Target Group 2 </h1>
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
    #while true; do
    echo "\$(date +'%Y-%m-%d %H:%M:%S') Random log entry: \$(shuf -i 1-1000 -n 1) Random Text: \$(tr -dc A-Za-z0-9 </dev/urandom | head -c 18)" >> "\$LOG_FILE"
    #sleep 60  # Adjust the interval as needed
    #done
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
    
    # Make the log rotation script executable
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

/*
resource "aws_eip" "tg2-eip" {
  count = 3
}
resource "aws_eip_association" "tg2-eip-associate" {
  count = 3
  instance_id = aws_instance.tg2_instance[count.index].id
  allocation_id = aws_eip.tg2-eip[count.index].id
}*/

/*
resource "null_resource" "stop-ec2-tg2-instances-on-creation" {
  provisioner "local-exec" {
     command = "aws ec2 stop-instances --instance-ids ${join(" ", aws_instance.tg2_instance[*].id)}"
     
  }
  provisioner "local-exec" {
    command = "sleep 10"
  }
  depends_on = [ aws_instance.tg2_instance ]
}*/

# Target Group Attachment for TG2
resource "aws_lb_target_group_attachment" "tg2_attachment" {
  count              = 3
  target_group_arn   = var.tg2_arn
  target_id          = aws_instance.tg2_instance[count.index].id
}
/*
resource "aws_autoscaling_group" "tg2_asg" {
  desired_capacity     = 3
  max_size             = 3
  min_size             = 1
  launch_template {
    id      = aws_launch_template.tg2_template.id
    version = "$Latest"
  }
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.tg2_arn]
}
*/
