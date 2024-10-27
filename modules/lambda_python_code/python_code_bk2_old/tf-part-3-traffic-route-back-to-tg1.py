#tf-part-3-traffic-route-back-to-tg1
import boto3
import json
import time

# Define constants
TG1_ARN = ''
TG2_ARN = ''
TG1_INSTANCE_IDS = []
ALB_LISTENER_ARN = ''
STEPS = 3
INTERVAL = 3  # Time interval in seconds
NEXT_FUNCTION_ARN = 'arn:aws:lambda:ap-south-1:308521642984:function:tf-part-4-tg2-log-rotation-stop-servers'

# Initialize boto3 clients
client = boto3.client('elbv2')
lambda_client = boto3.client('lambda')

# Check the health of target group instances
def check_health(target_group_arn):
    response = client.describe_target_health(TargetGroupArn=target_group_arn)
    healthy_targets = [target['Target']['Id'] for target in response['TargetHealthDescriptions'] if target['TargetHealth']['State'] == 'healthy']
    request_timeout_targets = [target['Target']['Id'] for target in response['TargetHealthDescriptions'] if target['TargetHealth']['State'] == 'unavailable']
    return healthy_targets, request_timeout_targets

# Wait until the desired number of instances are healthy in the target group
def wait_for_healthy_instances(target_group_arn, desired_count, interval=30, max_attempts=200):
    for attempt in range(max_attempts):
        healthy_targets, request_timeout_targets = check_health(target_group_arn)
        
        if len(healthy_targets) >= desired_count and not request_timeout_targets:
            print(f"Required healthy instances: {desired_count}, Healthy instances: {len(healthy_targets)}")
            return True
        
        print(f"Waiting for healthy instances. Current healthy count: {len(healthy_targets)}/{desired_count}, request timeout targets: {len(request_timeout_targets)}")
        time.sleep(interval)
    return False

# Shift traffic from TG2 to TG1
def traffic_shift_to_tg1(steps, interval):
    listener = client.describe_listeners(ListenerArns=[ALB_LISTENER_ARN])['Listeners'][0]
    current_weights = {tg['TargetGroupArn']: tg.get('Weight', 0) for tg in listener['DefaultActions'][0]['ForwardConfig']['TargetGroups']}
    
    from_tg_weight = current_weights.get(TG2_ARN, 0)
    to_tg_weight = current_weights.get(TG1_ARN, 0)
    
    if from_tg_weight == 0 and to_tg_weight == 100:
        print("Traffic is already routed to TG1, no action needed.")
        return
    
    for i in range(steps + 1):
        from_tg_weight = max(0, 100 - (100 // steps) * i)
        to_tg_weight = min(100, (100 // steps) * i)
        
        client.modify_listener(
            ListenerArn=ALB_LISTENER_ARN,
            DefaultActions=[{
                'Type': 'forward',
                'ForwardConfig': {
                    'TargetGroups': [
                        {'TargetGroupArn': TG2_ARN, 'Weight': from_tg_weight},
                        {'TargetGroupArn': TG1_ARN, 'Weight': to_tg_weight}
                    ]
                }
            }]
        )
        
        print(f"Step {i+1}/{steps}: TG1 Weight = {to_tg_weight}, TG2 Weight = {from_tg_weight}")
        time.sleep(interval)

# Lambda handler function
def lambda_handler(event, context):
    try:
        # Ensure all TG1 instances are healthy before routing traffic
        if not wait_for_healthy_instances(TG1_ARN, desired_count=len(TG1_INSTANCE_IDS)):
            print("No healthy instances or request timeout in TG1, aborting traffic shift.")
            return {
                'statusCode': 500,
                'body': json.dumps('No healthy instances or request timeout in TG1.')
            }
        
        # Perform traffic shift
        print("Starting Part 3: Gradual Traffic Shift from TG2 to TG1")
        traffic_shift_to_tg1(STEPS, INTERVAL)
        print("Completed Part 3: Traffic shifted to TG1")
        
        # Trigger the next Lambda function
        lambda_client.invoke(
            FunctionName=NEXT_FUNCTION_ARN,
            InvocationType='Event'
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps('Traffic shift to TG1 completed successfully.')
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
