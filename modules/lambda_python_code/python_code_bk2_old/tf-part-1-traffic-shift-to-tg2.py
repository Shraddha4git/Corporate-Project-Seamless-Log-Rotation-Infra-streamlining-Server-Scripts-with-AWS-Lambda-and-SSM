#tf-part-1-traffic-shift-to-tg2
import boto3
import json
import time

# Define constants
TG1_ARN = ''
TG2_ARN = ''
ALB_LISTENER_ARN = ''
STEPS = 3
INTERVAL = 3  # Time interval in seconds
NEXT_FUNCTION_ARN = 'arn:aws:lambda:ap-south-1:308521642984:function:tf-part-2-tg1-log-rotation'  # Replace with your next Lambda function ARN

# Initialize boto3 clients
client = boto3.client('elbv2')
lambda_client = boto3.client('lambda')

def check_health(target_group_arn):
    response = client.describe_target_health(TargetGroupArn=target_group_arn)
    healthy_targets = [target['Target']['Id'] for target in response['TargetHealthDescriptions']
                       if target['TargetHealth']['State'] == 'healthy']
    return healthy_targets

def traffic_shift_to_tg2(steps, interval):
    listener = client.describe_listeners(ListenerArns=[ALB_LISTENER_ARN])['Listeners'][0]
    current_weights = {tg['TargetGroupArn']: tg.get('Weight', 0) for tg in listener['DefaultActions'][0]['ForwardConfig']['TargetGroups']}
    
    from_tg_weight = current_weights.get(TG1_ARN, 0)
    to_tg_weight = current_weights.get(TG2_ARN, 0)
    
    # If traffic is already on TG2, exit
    if from_tg_weight == 0 and to_tg_weight == 100:
        print("Traffic is already routed to TG2, no action needed.")
        return
    
    for i in range(steps + 1):
        from_weight = max(0, 100 - (i * (100 // steps)))  # Decrease traffic to TG1
        to_weight = min(100, i * (100 // steps))  # Increase traffic to TG2
        print(f"Shifting traffic to TG2: TG1 = {from_weight}%, TG2 = {to_weight}%")
        client.modify_listener(
            ListenerArn=ALB_LISTENER_ARN,
            DefaultActions=[
                {
                    'Type': 'forward',
                    'ForwardConfig': {
                        'TargetGroups': [
                            {
                                'TargetGroupArn': TG1_ARN,
                                'Weight': from_weight
                            },
                            {
                                'TargetGroupArn': TG2_ARN,
                                'Weight': to_weight
                            }
                        ]
                    }
                }
            ]
        )
        time.sleep(interval)  # Wait before the next step

def lambda_handler(event, context):
    # Check health of TG2
    if not check_health(TG2_ARN):
        print("No healthy instances in TG2, aborting traffic shift.")
        return {
            'statusCode': 500,
            'body': json.dumps('No healthy instances in TG2.')
        }

    # Perform traffic shift
    print("Starting Part 1: Gradual Traffic Shift from TG1 to TG2")
    traffic_shift_to_tg2(STEPS, INTERVAL)
    print("Completed Part 1: Traffic shifted to TG2")

    # Trigger next Lambda
    lambda_client.invoke(
        FunctionName=NEXT_FUNCTION_ARN,
        InvocationType='Event'
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps('Traffic shift to TG2 completed successfully.')
    }
