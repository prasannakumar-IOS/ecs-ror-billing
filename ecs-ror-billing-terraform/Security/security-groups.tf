
resource "aws_security_group" "ecs_node_sg" {
  name_prefix = var.security_groups_name
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
