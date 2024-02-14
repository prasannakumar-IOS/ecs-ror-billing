region = "eu-north-1"
launch_template_name = "billing1-ecs-ec2"
launch_template_instance_type = "t3.medium"
auto_scaling_group_name = "billing1-ecs-asg"
auto_scaling_group_min_size = 1
auto_scaling_group_max_size = 2
ecs_capacity_provider_name = "billing1-ecs-ec2"
ecs_task_definition_family_name = "billing1-terra-app"
ecs_task_definition_family_cpu = 1024
ecs_task_definition_family_memory = 3072
ecs_service_name = "ror-new-structure"
ecs_alb_name = billing1-alb