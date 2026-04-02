data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical's AWS account
}

resource "aws_launch_template" "app_tpl" {
  name_prefix   = "${var.project_name}-tpl-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # This replaces vpc_security_group_ids and subnet_id in the old resource
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
  }

  # Your existing script, now inside the template
  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apache2
              systemctl start apache2
              systemctl enable apache2
              echo "Hello from Scalable Ubuntu EC2!" > /var/www/html/index.html
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
  name                = "${var.project_name}-asg"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  
  # This launches instances in BOTH zones
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  launch_template {
    id      = aws_launch_template.app_tpl.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.app_tg.arn]

  # This ensures every instance created by the ASG gets a tag
  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }
}