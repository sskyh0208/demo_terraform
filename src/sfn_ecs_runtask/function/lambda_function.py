
import boto3
import os
import json
import hashlib

from datetime import datetime, timedelta

SFN_STATE_MACHINE_ARN = os.getenv('SFN_STATE_MACHINE_ARN')

FORMAT_SFN_EXECUTION_ID = '{target_date}-{file_id}-{executed_count}'

sfn = boto3.client('stepfunctions')

def get_today_date() -> str:
    today = datetime.now() + timedelta(hours=9)
    return today.strftime('%Y%m%d')

def create_sfn_execution_id(obj_key: str, etag: str) -> str:
    '''ステップ関数のIDを生成する
    '''
    target_date = get_today_date()
    file_id = hashlib.sha256(f'{obj_key}-{etag}'.encode()).hexdigest()
    count = 1
    while True:
        execution_id = FORMAT_SFN_EXECUTION_ID.format(
            target_date=target_date,
            file_id=file_id,
            executed_count=str(count).zfill(2)
        )
        if not check_executed_sfn(execution_id):
            return execution_id
        count += 1

def check_executed_sfn(id: str) -> bool:
    '''ステップ関数が実行済みか確認する
    '''
    split_sfn_arn = SFN_STATE_MACHINE_ARN.split(':')
    split_sfn_arn[-2] = 'execution'
    target_arn = f'{":".join(split_sfn_arn)}:{id}'
    print(f'check_id: {id}')
    try:
        res = sfn.describe_execution(
            executionArn=target_arn
        )
        status = res.get('status')
        print(f'{id}: {status}')
        return True
    except Exception as e:
        print(e)
        return False

def execute_sfn(execute_id: str, input: dict) -> str:
    '''ステップ関数を実行する
    '''
    res = sfn.start_execution(
        stateMachineArn=SFN_STATE_MACHINE_ARN,
        name=execute_id,
        input=json.dumps(input)
    )
    res_id = res['executionArn']
    return res_id

def lambda_handler(event, context):
    body = json.loads(event['Records'][0]['body'])
    
    s3_info = body['Records'][0]['s3']
    bucket_name = s3_info['bucket']['name']
    obj_key = s3_info['object']['key']
    etag = s3_info['object']['eTag']
    
    execution_id = create_sfn_execution_id(obj_key, etag)
    print(f'execution_id: {execution_id}')
    
    input = {
        'execution_id': execution_id,
        'commands': [
            # pythonのコマンドを実行する
            'python',
            '-c',
            f'bucket_name = "{bucket_name}"; obj_key = "{obj_key}"; etag = "{etag}"; print(bucket_name, obj_key, etag)'
        ]
    }

    executed_id = execute_sfn(execution_id, input)
    print(f'executed_id: {executed_id}')
    
    return True