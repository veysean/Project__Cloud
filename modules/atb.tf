# Internet-facing Application Load Balancer (ELB). Resolves to a public
# *.elb.amazonaws.com DNS name; HTTP listener forwards to the app on EC2.
resource "aws_lb" "app_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  idle_timeout       = 120

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# The Target Group (Where the ASG puts the instances)
# name_prefix (≤6 chars) + create_before_destroy lets Terraform create the replacement TG
# first, repoint the listener, then delete the old TG. A fixed `name` would block replacement
# when port/protocol changes (ResourceInUse: target group in use by a listener).
resource "aws_lb_target_group" "app_tg" {
  name_prefix = substr(md5(var.project_name), 0, 6)
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    interval            = 15
    timeout             = 6
    healthy_threshold   = 2
    unhealthy_threshold = 5
    matcher             = "200"
  }
}

# The Listener (Hears traffic on Port 80 and sends to Target Group)
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}