resource "aws_alb" "main" {
  name               = "terraform-ecs"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.lb.id}"]
  subnets            = ["${aws_subnet.public.*.id}"]

  idle_timeout       = 30

  # TODO:
  # Change to `true` for production
  enable_deletion_protection = false
}

# A dummy target group is used to setup the ALB to just drop traffic
# initially, before any real service target groups have been added.
resource "aws_alb_target_group" "dummy" {
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "${aws_vpc.main.id}"
  target_type = "ip"

  health_check {
    interval = 6
    path = "/"
    protocol = "HTTP"
    timeout = 4
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

# A target group. This is used for keeping track of all the tasks, and
# what IP addresses / port numbers they have. You can query it yourself,
# to use the addresses yourself, but most often this target group is just
# connected to an application load balancer, or network load balancer, so
# it can automatically distribute traffic across all the targets.
resource "aws_alb_target_group" "app" {
  name        = "${local.aws_ecs_service_name}"
  port        = "${var.container_port}"
  protocol    = "HTTP"
  vpc_id      = "${aws_vpc.main.id}"
  target_type = "ip"
  deregistration_delay = 20

  health_check {
    interval = 6
    path = "/"
    protocol = "HTTP"
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "front_end" {
  load_balancer_arn = "${aws_alb.main.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.dummy.id}"
    type             = "forward"
  }
}

# Create a rule on the load balancer for routing traffic to the target group
resource "aws_lb_listener_rule" "all" {
  listener_arn = "${aws_alb_listener.front_end.arn}"
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.app.arn}"
  }

  condition {
    field  = "path-pattern"
    values = ["*"]
  }
}

output "alb_hostname" {
  value = "${aws_alb.main.dns_name}"
}
