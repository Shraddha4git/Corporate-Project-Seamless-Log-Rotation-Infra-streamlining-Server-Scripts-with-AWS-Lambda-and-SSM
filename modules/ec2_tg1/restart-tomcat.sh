#!/bin/bash
    # Function to check command existence
    command_exists () {
        type "$1" &> /dev/null ;
    }
    # Install required packages
    if ! command_exists unzip ; then
        sudo yum install -y unzip
    fi

    if ! command_exists zip ; then
        sudo yum install -y zip
    fi
    # Update AWS CLI if it exists, install if it doesn't
    if command_exists aws ; then
        echo "AWS CLI found. Updating..."
        sudo ./aws/install -i /usr/local/aws-cli -b /usr/local/bin --update
    else
        echo "AWS CLI not found. Installing..."
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -o awscliv2.zip
        sudo ./aws/install -i /usr/local/aws-cli -b /usr/local/bin
        rm -rf awscliv2.zip aws
        echo "AWS CLI installed."
    fi
    # Ensure AWS CLI is in the PATH
    export PATH=$PATH:/usr/local/bin:/usr/local/aws-cli/v2/current/bin
    # Ensure AWS CLI is in the PATH
    # Stop Tomcat service
    sudo systemctl stop tomcat
    # Get current timestamp
    timestamp=$(TZ='Asia/Kolkata' date +'%Y-%m-%d_%H:%M')
    # Define the path to catalina.out
    catalina_out_path="/apache-tomcat-9.0.90/logs/catalina.out"  # Update this path
    # Zip catalina.out with timestamp
    zip /apache-tomcat-9.0.90/logs/catalina_${timestamp}_tg1.zip $catalina_out_path
    # Define your S3 bucket
    s3_bucket="s3://tf-ebs-lambda-function-03-10-24/logs/"  # Update this with your S3 bucket details
    # Copy the zipped log file to S3
    aws s3 cp /apache-tomcat-9.0.90/logs/catalina_${timestamp}_tg1.zip $s3_bucket
    # Restart Tomcat service
    sudo systemctl start tomcat