 Complete Flow Project



prerequisites:

1. github secrets
2. role for th ec2 with right permissions such as : AmazonEC2ContainerRegistryReadOnly,AmazonSSMManagedInstanceCore,ec2-ssm-extra
3. ecr repo
4. s3 bucket for tfstate file and dynamo db table for locking
5. iam user for GHA with permissions such as:
AmazonDynamoDBFullAccess,AmazonEC2ContainerRegistryFullAccess,AmazonEC2FullAccess,AmazonS3FullAccess,AmazonSSMFullAccess,IAMFullAccess


