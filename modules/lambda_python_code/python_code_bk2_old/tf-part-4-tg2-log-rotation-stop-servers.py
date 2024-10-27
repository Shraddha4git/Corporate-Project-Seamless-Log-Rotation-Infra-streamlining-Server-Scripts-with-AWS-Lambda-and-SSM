#tf-part-4-tg2-log-rotation-stop-servers
import boto3
import json
import time

# Define constants
TG2_INSTANCE_IDS = []
COMMAND = 'sudo sh /tmp/restart-tomcat.sh'

# Initialize boto3 clients
ssm_client = boto3.client('ssm')
ec2_client = boto3.client('ec2')

def run_restart_script(instance_ids):
    response = ssm_client.send_command(
        InstanceIds=instance_ids,
        DocumentName='AWS-RunShellScript',
        Parameters={'commands': [COMMAND]}
    )
    command_id = response['Command']['CommandId']
    return command_id

def poll_command_status(command_id, instance_ids):
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
        if all(statuses[instance_id]['Status'] in ['Success', 'Failed'] for instance_id in instance_ids):
            break
        retries += 1
    return statuses

def lambda_handler(event, context):
    try:
        # Run restart-tomcat.sh on TG2 servers
        print("Running restart-tomcat.sh on TG2 servers")
        command_id = run_restart_script(TG2_INSTANCE_IDS)
        statuses = poll_command_status(command_id, TG2_INSTANCE_IDS)
        print(f"TG2 restart statuses: {statuses}")

        # Check if script execution was successful
        if all(status['Status'] == 'Success' for status in statuses.values()):
            print("All TG2 servers executed restart-tomcat.sh successfully. Proceeding to stop instances.")
            
            # Stop TG2 servers
            ec2_client.stop_instances(InstanceIds=TG2_INSTANCE_IDS)
            print(f"Stopped TG2 servers: {TG2_INSTANCE_IDS}")

        return {
            'statusCode': 200,
            'body': json.dumps('restart-tomcat.sh executed on TG2 servers and TG2 servers stopped.')
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
