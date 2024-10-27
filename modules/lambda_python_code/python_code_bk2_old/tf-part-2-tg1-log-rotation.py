#tf-part-2-tg1-log-rotation
import boto3
import json
import time

# Define constants
TG1_INSTANCE_IDS = []
TG1_ARN = ''
COMMAND = 'sudo sh /tmp/restart-tomcat.sh'
NEXT_FUNCTION_ARN = 'arn:aws:lambda:ap-south-1:308521642984:function:tf-part-3-traffic-route-back-to-tg1'  # Replace with your next Lambda function ARN

# Initialize boto3 clients
ssm_client = boto3.client('ssm')
elb_client = boto3.client('elbv2')
lambda_client = boto3.client('lambda')

def check_health(target_group_arn):
    response = elb_client.describe_target_health(TargetGroupArn=target_group_arn)
    healthy_targets = [target['Target']['Id'] for target in response['TargetHealthDescriptions'] if target['TargetHealth']['State'] == 'healthy']
    request_timeout_targets = [target['Target']['Id'] for target in response['TargetHealthDescriptions'] if target['TargetHealth']['State'] == 'unavailable']
    return healthy_targets, request_timeout_targets

def check_tomcat_status(instance_ids):
    command = 'sudo systemctl status tomcat'
    command_id = run_ssm_command(instance_ids, command)
    statuses = poll_command_status(command_id, instance_ids)
    return all('active (running)' in status['Output'] for status in statuses.values())

def run_ssm_command(instance_ids, command):
    response = ssm_client.send_command(
        InstanceIds=instance_ids,
        DocumentName='AWS-RunShellScript',
        Parameters={'commands': [command]}
    )
    command_id = response['Command']['CommandId']
    return command_id

def run_restart_script(instance_ids, command):
    command_id = run_ssm_command(instance_ids, command)
    return command_id

def poll_command_status(command_id, instance_ids, desired_status='Success'):
    max_retries = 30
    retries = 0
    statuses = {instance_id: None for instance_id in instance_ids}
    while retries < max_retries:
        time.sleep(1)
        command_response = ssm_client.list_command_invocations(
            CommandId=command_id,
            Details=True
        )
        for invocation in command_response['CommandInvocations']:
            instance_id = invocation['InstanceId']
            status = invocation['Status']
            output = invocation.get('CommandPlugins', [{}])[0].get('Output', '')
            statuses[instance_id] = {'Status': status, 'Output': output}
            if status in ['Success', 'Failed']:
                print(f"Instance ID: {instance_id}, Status: {status}, Output: {output}")
        if all(statuses[instance_id]['Status'] == desired_status for instance_id in instance_ids):
            break
        retries += 1
    return statuses

def wait_for_healthy_instances(target_group_arn, instance_count, interval=30, max_attempts=200):
    for attempt in range(max_attempts):
        healthy_targets, request_timeout_targets = check_health(target_group_arn)
        if len(healthy_targets) >= instance_count and not request_timeout_targets:
            print(f"Required healthy instances: {instance_count}, Healthy instances: {len(healthy_targets)}")
            return True
        print(f"Waiting for healthy instances. Current healthy count: {len(healthy_targets)}/{instance_count}, request timeout targets: {len(request_timeout_targets)}")
        time.sleep(interval)
    return False

def lambda_handler(event, context):
    try:
        # Part 1: Check health of TG1 instances
        if not wait_for_healthy_instances(TG1_ARN, len(TG1_INSTANCE_IDS)):
            print("No healthy instances or request timeout in TG1, aborting...")
            return {
                'statusCode': 500,
                'body': json.dumps('No healthy instances or request timeout in TG1.')
            }

        # Part 2: Run restart-tomcat.sh on TG1 servers
        print("Running restart-tomcat.sh on TG1 servers")
        command_id = run_restart_script(TG1_INSTANCE_IDS, COMMAND)
        statuses = poll_command_status(command_id, TG1_INSTANCE_IDS)
        print(f"TG1 restart statuses: {statuses}")

        # Check Tomcat status on TG1 servers
        while not check_tomcat_status(TG1_INSTANCE_IDS):
            print("Tomcat is not running on all TG1 instances, starting...")
            run_ssm_command(TG1_INSTANCE_IDS, 'sudo systemctl start tomcat')
            time.sleep(30)

        # Ensure all TG1 instances are healthy before moving on
        if not wait_for_healthy_instances(TG1_ARN, len(TG1_INSTANCE_IDS)):
            print("Not all TG1 instances became healthy.")
            return {
                'statusCode': 500,
                'body': json.dumps('Not all TG1 instances became healthy.')
            }

        # Trigger next Lambda function if script execution is successful
        if all(status['Status'] == 'Success' for status in statuses.values()):
            lambda_client.invoke(
                FunctionName=NEXT_FUNCTION_ARN,
                InvocationType='Event'
            )
            print("Triggered tf-part-3-traffic-route-back-to-tg1 Lambda function")
        
        return {
            'statusCode': 200,
            'body': json.dumps('restart-tomcat.sh executed on TG1 servers and Tomcat is running.')
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
