data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical's AWS account
}

resource "tls_private_key" "deploy_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-ssh-key"
  public_key = tls_private_key.deploy_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.deploy_key.private_key_pem
  filename        = "${path.root}/${var.project_name}-key.pem"
  file_permission = "0400"
}

# JSON config as base64 in user_data avoids bash interpreting characters like $ in DB_PASSWORD.
locals {
  app_runtime_config_b64 = base64encode(jsonencode({
    DB_HOST            = aws_db_instance.app_db.address
    DB_USER            = aws_db_instance.app_db.username
    DB_PASSWORD        = aws_db_instance.app_db.password
    DB_NAME            = aws_db_instance.app_db.db_name
    DB_SSLMODE         = "prefer"
    ATTACHMENTS_BUCKET = aws_s3_bucket.attachments.bucket
    AWS_REGION         = var.aws_region
  }))
}

resource "aws_launch_template" "app_tpl" {
  name_prefix   = "${var.project_name}-tpl-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    device_index                = 0
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
  }

  depends_on = [aws_s3_object.app_zip_upload]

  user_data = base64encode(<<-EOF
#!/bin/bash
# ASG bootstrap:
#   1) Install Node.js 20 + npm
#   2) Install package.json dependencies
#   3) Run init_db.js
#   4) Start server.js on 0.0.0.0:8080 (via systemd)
set -euo pipefail

APP_DIR=/home/ubuntu/app

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y wget ca-certificates curl unzip awscli postgresql-client

# SSM Agent
wget -qO /tmp/amazon-ssm-agent.deb "https://amazon-ssm-${var.aws_region}.s3.${var.aws_region}.amazonaws.com/latest/debian_amd64/amazon-ssm-agent.deb"
dpkg -i /tmp/amazon-ssm-agent.deb || apt-get install -f -y
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent || true

if command -v ufw >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive ufw --force disable || true
fi

# 1) Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

mkdir -p "$APP_DIR"
chown ubuntu:ubuntu "$APP_DIR"

# App artifact
sudo -u ubuntu -H bash -c "cd '$APP_DIR' && aws s3 cp s3://${aws_s3_bucket.deploy.bucket}/app.zip . && unzip -o app.zip"

# 2) NPM Install
sudo -u ubuntu -H bash -c "cd '$APP_DIR' && npm install"

echo '${local.app_runtime_config_b64}' | base64 -d > "$APP_DIR/app_config.json"
chmod 600 "$APP_DIR/app_config.json"
chown ubuntu:ubuntu "$APP_DIR/app_config.json"

until pg_isready -h ${aws_db_instance.app_db.address} -p 5432 -U ${aws_db_instance.app_db.username} -d ${aws_db_instance.app_db.db_name} -t 5; do
  echo "Waiting for PostgreSQL..."
  sleep 10
done

# 3) init_db.js
sudo -u ubuntu -H bash -c "cd '$APP_DIR' && node init_db.js"

# 4) Node.js on :3000 (systemd)
cat <<'SERVICE' > /etc/systemd/system/app.service
[Unit]
Description=Node.js Express app (port 3000)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/app
Environment=NODE_ENV=production
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable app
systemctl start app

for attempt in $(seq 1 60); do
  if curl -sfS --max-time 5 http://127.0.0.1:3000/health >/dev/null; then
    echo "ALB health path OK: GET /health on :3000 (attempt $attempt)"
    exit 0
  fi
  sleep 5
done

echo "Node.js did not serve /health on 3000 — diagnostics:"
systemctl status app --no-pager || true
journalctl -u app -n 120 --no-pager || true
ss -tlnp || true
exit 1
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-asg-node"
    }
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name             = "${var.project_name}-asg-v4"
  desired_capacity = 2
  max_size         = 4
  min_size         = 1

  # Delays *Auto Scaling* from replacing instances that fail ELB checks; the ALB still
  # routes only to targets that pass its own health checks (503 until at least one is healthy).
  health_check_grace_period = 900

  # Launch instances in PUBLIC subnets
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  launch_template {
    id      = aws_launch_template.app_tpl.id
    version = aws_launch_template.app_tpl.latest_version
  }
  target_group_arns = [aws_lb_target_group.app_tg.arn]

  # Keep at least one healthy target behind the ALB during template/AMI refreshes.
  # min_healthy_percentage = 0 can deregister all targets at once → HTTP 503.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }
}

resource "aws_iam_role" "ec2_s3_access_role" {
  name = "${var.project_name}-ec2-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "s3_least_privilege" {
  name = "${var.project_name}-s3-least-privilege"
  role = aws_iam_role.ec2_s3_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.deploy.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.attachments.arn,
          "${aws_s3_bucket.attachments.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-instance-profile"
  role = aws_iam_role.ec2_s3_access_role.name
}
