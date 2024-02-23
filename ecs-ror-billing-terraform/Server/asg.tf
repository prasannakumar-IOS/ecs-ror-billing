# --- ECS Launch Template ---

data "aws_ssm_parameter" "ecs_node_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

data "aws_ssm_parameter" "ecs_node_instance_profile_arn" {
  name = "billing1-ecs-node-instance-profile-arn"
}

resource "aws_launch_template" "ecs_ec2" {
  name_prefix            = var.launch_template_name
  image_id               = data.aws_ssm_parameter.ecs_node_ami.value
  instance_type          = var.launch_template_instance_type
  vpc_security_group_ids = [data.aws_ssm_parameter.ecs_node_sg_id.value]

  iam_instance_profile { arn =  data.aws_ssm_parameter.ecs_node_instance_profile_arn.value }
  monitoring { enabled = true }

  user_data = filebase64("${path.module}/ecs.sh")
}

# --- ECS ASG ---

resource "aws_autoscaling_group" "ecs" {
  name_prefix               = var.auto_scaling_group_name
  vpc_zone_identifier       = data.aws_ssm_parameter.subnet_ids.value
  min_size                  = var.auto_scaling_group_min_size
  max_size                  = var.auto_scaling_group_max_size
  health_check_grace_period = 0
  health_check_type         = "EC2"
  protect_from_scale_in     = false

  launch_template {
    id      = aws_launch_template.ecs_ec2.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "billing-ecs-cluster"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
}
