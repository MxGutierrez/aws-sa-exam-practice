# VPC endpoint test

An EC2 instance is created in a private subnet with internet access through a NAT Gateway in order to be able to pull api docker image.

A VPC endpoint is created to access S3.

The S3 bucket has restricted acccess from EC2 role through non VPC endpoint to make sure access to S3 is effectively going through VPC endpoint. Try removing the VPC endpoint route table association and check what happens.
