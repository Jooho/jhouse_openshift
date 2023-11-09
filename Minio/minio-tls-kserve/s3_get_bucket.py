import boto3
import botocore

# MinIO 서버의 엔드포인트, 액세스 키, 비밀 키 설정
minio_endpoint = 'http://localhost:9000'  # MinIO 서버의 HTTPS 엔드포인트
access_key = 'THEACCESSKEY'  # MinIO 액세스 키
secret_key = 'THEPASSWORD'  # MinIO 비밀 키

# SSL 인증서 검증을 스킵하는 botocore 세션 생성
session = boto3.Session()
config = botocore.config.Config(signature_version='s3v4', s3={'addressing_style': 'path'})
s3 = session.client('s3', endpoint_url=minio_endpoint, aws_access_key_id=access_key,
                   aws_secret_access_key=secret_key, verify=False, config=config)

#s3 = boto3.resource('s3', endpoint_url=minio_endpoint, aws_access_key_id=access_key,
#                   aws_secret_access_key=secret_key, verify=False, config=config)
# 버킷 목록 가져오기
response = s3.list_buckets()

# 버킷 목록 출력
print("Bucket List:")
for bucket in response['Buckets']:
    print(bucket['Name'])

#bucket = s3.Bucket("modelmesh-example-models")
#print(bucket)
