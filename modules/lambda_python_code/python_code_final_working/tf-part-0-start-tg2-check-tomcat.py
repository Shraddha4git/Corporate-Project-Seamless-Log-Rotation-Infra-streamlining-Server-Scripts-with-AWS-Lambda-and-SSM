#tf-part-0-start-tg2-check-tomcat
import boto3
import json
import time
import os

# Define constants
TG2_INSTANCE_IDS = os.getenv("TG2_INSTANCE_IDS", "")
TG2_ARN = os.getenv("TG2_ARN", "")

# Convert the comma-separated string back to a list
TG2_INSTANCE_IDS = [id.strip() for id in TG2_INSTANCE_IDS.split(",") if id.strip()]

COMMANDS_TOMCAT_STATUS = ['sudo systemctl status tomcat']
COMMANDS_TOMCAT_START = [
    'sudo setenforce 0',
    'sudo systemctl enable tomcat',
    'sudo systemctl start tomcat'
]

# Initialize boto3 clients
ec2_client = boto3.client('ec2')
ssm_client = boto3.client('ssm')
elb_client = boto3.client('elbv2')

def check_health(target_group_arn):
    response = elb_client.describe_target_health(TargetGroupArn=target_group_arn)
    healthy_targets = [target['Target']['Id'] for target in response['TargetHealthDescriptions']
                       if target['TargetHealth']['State'] == 'healthy']
    return healthy_targets

def start_instances(instance_ids):
    ec2_client.start_instances(InstanceIds=instance_ids)
    for instance_id in instance_ids:
        waiter = ec2_client.get_waiter('instance_running')
        waiter.wait(InstanceIds=[instance_id])
    print(f"Started instances: {instance_ids}")

def run_ssm_command(instance_ids, commands):
    response = ssm_client.send_command(
        InstanceIds=instance_ids,
        DocumentName='AWS-RunShellScript',
        Parameters={'commands': commands}
    )
    command_id = response['Command']['CommandId']
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

def lambda_handler(event, context):
    # Part 1: Start TG2 instances if not already running
    instances_to_start = []
    for instance_id in TG2_INSTANCE_IDS:
        response = ec2_client.describe_instance_status(InstanceIds=[instance_id])
        if not response['InstanceStatuses'] or response['InstanceStatuses'][0]['InstanceState']['Name'] != 'running':
            instances_to_start.append(instance_id)
    if instances_to_start:
        start_instances(instances_to_start)
        time.sleep(30)  # Wait for instances to start
    
    # Part 2: Check Tomcat status and start if not running
    command_id = run_ssm_command(TG2_INSTANCE_IDS, COMMANDS_TOMCAT_STATUS)
    statuses = poll_command_status(command_id, TG2_INSTANCE_IDS)
    for instance_id, status in statuses.items():
        if 'running' not in status['Output']:
            print(f"Tomcat is not running on instance {instance_id}, starting it...")
            command_id = run_ssm_command([instance_id], COMMANDS_TOMCAT_START)
            poll_command_status(command_id, [instance_id])
    
    # Part 3: Check health status of TG2 instances
    while len(check_health(TG2_ARN)) < len(TG2_INSTANCE_IDS):
        print("Waiting for all TG2 instances to become healthy...")
        time.sleep(30)
    
    print("All TG2 instances are healthy.")
    return {
        'statusCode': 200,
        'body': json.dumps('TG2 instances started and Tomcat is running.')
    }
