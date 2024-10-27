data "archive_file" "tf-part-0-start-tg2-check-tomcat_zip" {
  type = "zip"
  source_file =  "${path.module}/python_code/tf-part-0-start-tg2-check-tomcat.py"
  output_path =   "${path.module}/python_code/tf-part-0-start-tg2-check-tomcat.zip"
}
data "archive_file" "tf-part-1-traffic-shift-to-tg2_zip" {
  type = "zip"
  source_file =  "${path.module}/python_code/tf-part-1-traffic-shift-to-tg2.py"
  output_path =   "${path.module}/python_code/tf-part-1-traffic-shift-to-tg2.zip"
}
data "archive_file" "tf-part-2-tg1-log-rotation_zip" {
  type = "zip"
  source_file =  "${path.module}/python_code/tf-part-2-tg1-log-rotation.py"
  output_path =   "${path.module}/python_code/tf-part-2-tg1-log-rotation.zip"
}
data "archive_file" "tf-part-3-traffic-route-back-to-tg1_zip" {
  type = "zip"
  source_file =  "${path.module}/python_code/tf-part-3-traffic-route-back-to-tg1.py"
  output_path =   "${path.module}/python_code/tf-part-3-traffic-route-back-to-tg1.zip"
}
data "archive_file" "tf-part-4-tg2-log-rotation-stop-servers_zip" {
  type = "zip"
  source_file =  "${path.module}/python_code/tf-part-4-tg2-log-rotation-stop-servers.py"
  output_path =   "${path.module}/python_code/tf-part-4-tg2-log-rotation-stop-servers.zip"
}

resource "aws_s3_bucket" "s3_lambda_function_files" {
  bucket = "tf-ebs-lambda-function-03-10-24"
  force_destroy = true
  
  tags = {
    Name        = "App Deployment Bucket"
    Environment = "Dev"
  }
}
resource "aws_s3_object" "logs_folder" {
  bucket = aws_s3_bucket.s3_lambda_function_files.bucket
  key    = "logs/"  # This creates a 'folder' in S3
  acl    = "private"
}
resource "aws_s3_object" "tf-part-0-start-tg2-check-tomcat_upload" {
  bucket = aws_s3_bucket.s3_lambda_function_files.bucket
  key = "tf-part-0-start-tg2-check-tomcat.zip"
  source = "${path.module}/python_code/tf-part-0-start-tg2-check-tomcat.zip"
}
resource "aws_s3_object" "tf-part-1-traffic-shift-to-tg2_upload" {
  bucket = aws_s3_bucket.s3_lambda_function_files.bucket
  key = "tf-part-1-traffic-shift-to-tg2.zip"
  source = "${path.module}/python_code/tf-part-1-traffic-shift-to-tg2.zip"
}
resource "aws_s3_object" "tf-part-2-tg1-log-rotation_upload" {
  bucket = aws_s3_bucket.s3_lambda_function_files.bucket
  key = "tf-part-2-tg1-log-rotation.zip"
  source = "${path.module}/python_code/tf-part-2-tg1-log-rotation.zip"
}
resource "aws_s3_object" "tf-part-3-traffic-route-back-to-tg1_upload" {
  bucket = aws_s3_bucket.s3_lambda_function_files.bucket
  key = "tf-part-3-traffic-route-back-to-tg1.zip"
  source = "${path.module}/python_code/tf-part-3-traffic-route-back-to-tg1.zip"
}
resource "aws_s3_object" "tf-part-4-tg2-log-rotation-stop-servers_upload" {
  bucket = aws_s3_bucket.s3_lambda_function_files.bucket
  key = "tf-part-4-tg2-log-rotation-stop-servers.zip"
  source = "${path.module}/python_code/tf-part-4-tg2-log-rotation-stop-servers.zip"
}

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_exec" {
  name = "tf-lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{

      Effect = "Allow"
      Action = [
         "sts:AssumeRole"],
         Principal= {
          Service = "lambda.amazonaws.com"
         }
    } ]
  })
}
 resource "aws_iam_role_policy" "lambda_polivy" {
   name = "tf-lambda_role_policy"
   role = aws_iam_role.lambda_exec.id
   
policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "lambda:InvokeFunction",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DetachNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:ListBucket",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "ssm:SendCommand",
          "ssm:ListCommandInvocations"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": "lambda:InvokeFunction",
        "Resource": [
        "arn:aws:lambda:ap-south-1:308521642984:function:tf-part-0-start-tg2-check-tomcat",
        "arn:aws:lambda:ap-south-1:308521642984:function:tf-part-1-traffic-shift-to-tg2",
        "arn:aws:lambda:ap-south-1:308521642984:function:tf-part-2-tg1-log-rotation",
        "arn:aws:lambda:ap-south-1:308521642984:function:tf-part-3-traffic-route-back-to-tg1",
        "arn:aws:lambda:ap-south-1:308521642984:function:tf-part-4-tg2-log-rotation-stop-servers"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "tf-part-0-start-tg2-check-tomcat" {
  depends_on = [aws_s3_object.tf-part-0-start-tg2-check-tomcat_upload]
  function_name    = "tf-part-0-start-tg2-check-tomcat"
  handler          = "tf-part-0-start-tg2-check-tomcat.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 850
  s3_bucket = "tf-ebs-lambda-function-03-10-24"
  s3_key = "tf-part-0-start-tg2-check-tomcat.zip"
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.ec2_security_group_id]
  }
  environment {
    variables = {
      TG2_INSTANCE_IDS = join(", ", var.tg2_instance_ids)
      TG2_ARN          = var.tg2_arn
    }
  }
}
 
resource "aws_lambda_function" "tf-part-1-traffic-shift-to-tg2" {
  depends_on = [aws_s3_object.tf-part-1-traffic-shift-to-tg2_upload]
  function_name    = "tf-part-1-traffic-shift-to-tg2"
  handler          = "tf-part-1-traffic-shift-to-tg2.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 850
  s3_bucket = "tf-ebs-lambda-function-03-10-24"
  s3_key = "tf-part-1-traffic-shift-to-tg2.zip"
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.ec2_security_group_id]
  }
  environment {
    variables = {
      TG1_ARN          = var.tg1_arn
      TG2_ARN          = var.tg2_arn
      ALB_LISTENER_ARN     = var.listener_arn
    }
  }
}
 
resource "aws_lambda_function" "tf-part-2-tg1-log-rotation" {
  depends_on = [aws_s3_object.tf-part-2-tg1-log-rotation_upload]
  function_name    = "tf-part-2-tg1-log-rotation"
  handler          = "tf-part-2-tg1-log-rotation.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 850
  s3_bucket = "tf-ebs-lambda-function-03-10-24"
  s3_key = "tf-part-2-tg1-log-rotation.zip"
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.ec2_security_group_id]
  }
  environment {
    variables = {
      TG1_ARN          = var.tg1_arn
      TG1_INSTANCE_IDS = join(", ", var.tg1_instance_ids)
    }
  }  
}
 
resource "aws_lambda_function" "tf-part-3-traffic-route-back-to-tg1" {
  depends_on = [ aws_s3_object.tf-part-3-traffic-route-back-to-tg1_upload]
  function_name    = "tf-part-3-traffic-route-back-to-tg1"
  handler          = "tf-part-3-traffic-route-back-to-tg1.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 850
  s3_bucket = "tf-ebs-lambda-function-03-10-24"
  s3_key = "tf-part-3-traffic-route-back-to-tg1.zip"
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.ec2_security_group_id]
  }
  environment {
    variables = {
      TG1_ARN          = var.tg1_arn
      TG1_INSTANCE_IDS = join(", ", var.tg1_instance_ids)
      TG2_ARN          = var.tg2_arn
      ALB_LISTENER_ARN     = var.listener_arn
    }
  }
}

resource "aws_lambda_function" "tf-part-4-tg2-log-rotation-stop-servers" {
  depends_on = [ aws_s3_object.tf-part-4-tg2-log-rotation-stop-servers_upload]
  function_name    = "tf-part-4-tg2-log-rotation-stop-servers"
  handler          = "tf-part-4-tg2-log-rotation-stop-servers.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 850
  s3_bucket = "tf-ebs-lambda-function-03-10-24"
  s3_key = "tf-part-4-tg2-log-rotation-stop-servers.zip"
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.ec2_security_group_id]
  }
  environment {
    variables = {
      TG2_INSTANCE_IDS = join(", ", var.tg2_instance_ids)
    }
  }
}

# CloudWatch Event Rules for scheduled triggers
resource "aws_cloudwatch_event_rule" "schedule_tf-part-0-start-tg2-check-tomcat" {
  name                = "tf-part-0-start-tg2-check-tomcat"
  schedule_expression = "cron(40 23,17,18 * * ? *)" # "cron(10 18,2,10 * * ? *)" # This is schedules 20 min before Log Rotation.
}
 
resource "aws_cloudwatch_event_rule" "schedule_tf-part-1-traffic-shift-to-tg2" {
  name                = "tf-part-1-traffic-shift-to-tg2"
  schedule_expression = "cron(25 14 * * ? *)" # "cron(30 18,2,11 * * ? *)" #CloudWatch Events only accept UTC, IST is 24:00, 8:00, 16:00 
}

# CloudWatch Event Targets
resource "aws_cloudwatch_event_target" "tf-part-0-start-tg2-check-tomcat_target" {
  rule      = aws_cloudwatch_event_rule.schedule_tf-part-0-start-tg2-check-tomcat.name
  target_id = "tf-part-0-start-tg2-check-tomcat"
  arn       = aws_lambda_function.tf-part-0-start-tg2-check-tomcat.arn
}

resource "aws_cloudwatch_event_target" "tf-part-1-traffic-shift-to-tg2_target" {
  rule      = aws_cloudwatch_event_rule.schedule_tf-part-1-traffic-shift-to-tg2.name
  target_id = "tf-part-1-traffic-shift-to-tg2"
  arn       = aws_lambda_function.tf-part-1-traffic-shift-to-tg2.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_part-1" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tf-part-1-traffic-shift-to-tg2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule_tf-part-1-traffic-shift-to-tg2.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_part-0" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tf-part-0-start-tg2-check-tomcat.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule_tf-part-0-start-tg2-check-tomcat.arn
}