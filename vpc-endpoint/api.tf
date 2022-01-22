resource "aws_lb_target_group" "api" {
  name     = "${local.project_name}-api-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_security_group" "sg" {
  name   = "${local.project_name}-api-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon_2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
  owners = ["amazon"]
}

resource "aws_instance" "api" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.amazon_2.id
  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id              = aws_subnet.privates[0].id
  iam_instance_profile   = aws_iam_instance_profile.s3_access.name
  user_data              = <<EOF
#!/bin/bash

sudo amazon-linux-extras install docker -y
sudo service docker start
sudo docker pull mxgutierrez/go-s3
sudo docker run -d -p 80:80 -e AWS_REGION='${data.aws_region.current.name}' -e BUCKET_NAME='${aws_s3_bucket.bucket.id}' mxgutierrez/go-s3
EOF

  tags = {
    Name = "${local.project_name}-ec2"
  }
}

resource "aws_lb_target_group_attachment" "instance" {
  target_group_arn = aws_lb_target_group.api.arn
  target_id        = aws_instance.api.id
  port             = 80
}

resource "aws_iam_role" "s3" {
  name = "${local.project_name}-s3-access"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "s3_access" {
  name = "${local.project_name}-s3-access"
  role = aws_iam_role.s3.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.bucket.arn}"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "s3_access" {
  name = "${local.project_name}-s3-access"
  role = aws_iam_role.s3.id
}
