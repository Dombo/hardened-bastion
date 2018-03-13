data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_autoscaling_group" "asg" {
  availability_zones = ["${data.aws_availability_zones.available.names}"]

  # This forces a new resource each terraform run
  name                 = "${aws_launch_configuration.asg_lc.name}"
  max_size             = 1
  min_size             = 1
  launch_configuration = "${aws_launch_configuration.asg_lc.name}"
  health_check_type    = "EC2"
  force_delete         = true

  // todo Handle both default VPC & best practice configuration VPC [WIP]
  vpc_zone_identifier = "${var.public_subnet_ids}"

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-hardened-bastion"
    propagate_at_launch = true
  }

  tag {
    key                 = "ephemeral_sessions"
    value               = "${var.enable_ephemeral_ssh_sessions}"
    propagate_at_launch = true
  }
}

resource "aws_key_pair" "key" {
  key_name   = "${var.environment}-hardened-bastion-key-0"
  public_key = "${var.secret_0_public_key}"
}

resource "aws_launch_configuration" "asg_lc" {
  name                        = "${var.environment}-hardened-bastion-${uuid()}"
  image_id                    = "${data.aws_ami.ubuntu.id}"
  instance_type               = "t2.micro"
  iam_instance_profile        = "${aws_iam_instance_profile.instance_profile.id}"
  key_name                    = "${aws_key_pair.key.key_name}"
  security_groups             = ["${aws_security_group.sg.id}"]
  associate_public_ip_address = "true"

  user_data = "${data.template_cloudinit_config.bootstrap_config.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

data "template_file" "bootstrap_static_network_address" {
  template = "${file("${path.module}/assets/bootstrap_static_network_address.sh")}"

  vars {
    ip_id  = "${aws_eip.ip.id}"
    region = "${var.region}"
  }
}

data "template_file" "bootstrap_system_configuration" {
  template = "${file("${path.module}/assets/bootstrap_system_configuration.sh")}"

  vars {
    region          = "${var.region}"
    bucket_name     = "${aws_s3_bucket.bucket.id}"
    global_ssh_user = "${var.global_ssh_user}"
    environment     = "${var.environment}"
    payload_name    = "${aws_s3_bucket_object.playbook.key}"
  }

  depends_on = [
    "aws_s3_bucket_object.playbook",
  ]
}

data "template_cloudinit_config" "bootstrap_config" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.bootstrap_static_network_address.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.bootstrap_system_configuration.rendered}"
  }
}

resource "aws_security_group" "sg" {
  name_prefix = "${var.environment}-hardened-bastion-sg-"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = "${var.ssh_port}"
    to_port     = "${var.ssh_port}"
    protocol    = "tcp"
    cidr_blocks = ["${var.ssh_allowed_cidr_block}"]
  }

  egress {
    from_port   = "${var.ssh_port}"
    to_port     = "${var.ssh_port}"
    protocol    = "tcp"
    cidr_blocks = ["${var.ssh_allowed_cidr_block}"]
  }

  ingress {
    from_port   = "${var.ssh_port_knocking_port_range_lower_bound}"
    to_port     = "${var.ssh_port_knocking_port_range_upper_bound}"
    protocol    = "udp"
    cidr_blocks = ["${var.ssh_allowed_cidr_block}"]
  }

  egress {
    from_port   = "${var.ssh_port_knocking_port_range_lower_bound}"
    to_port     = "${var.ssh_port_knocking_port_range_upper_bound}"
    protocol    = "udp"
    cidr_blocks = ["${var.ssh_allowed_cidr_block}"]
  }

  egress {
    from_port = "80"
    to_port   = "80"
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  egress {
    from_port = "443"
    to_port   = "443"
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

resource "aws_eip" "ip" {
  vpc = true
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = "${var.environment}-hardened-bastion-log-group"

  retention_in_days = "${var.bastion_log_retention}"

  tags {
    Environment = "${var.environment}"
    Application = "hardened-bastion"
    Region      = "${var.region}"
  }
}

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = "${var.environment}-hardened-bastion-profile"
  role        = "${aws_iam_role.role.name}"
  path        = "/bastion/"
}

resource "aws_iam_role" "role" {
  name_prefix = "${var.environment}-hardened-bastion-role"
  path        = "/bastion/"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "role_policy" {
  name_prefix = "${var.environment}-hardened-bastion-policy"
  role        = "${aws_iam_role.role.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:AssociateAddress",
        "ec2:DescribeAddresses"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:GetLogEvents",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutRetentionPolicy",
        "logs:PutMetricFilter",
        "logs:CreateLogGroup"
      ],
      "Resource": "${aws_cloudwatch_log_group.log_group.arn}",
      "Effect": "Allow"
    },
    {
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "${aws_s3_bucket.bucket.arn}/*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "${aws_s3_bucket.bucket.arn}",
      "Effect": "Allow"
    }
  ]
}
POLICY
}

data "aws_iam_policy_document" "ephemeral_sessions" {
  statement {
    actions = [
      "ec2:TerminateInstances",
    ]

    effect = "Allow"

    resources = [
      "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/ephemeral_sessions"

      values = [
        "true",
      ]
    }
  }
}

resource "aws_iam_role_policy" "role_policy_ephemeral_sessions" {
  name_prefix = "${var.environment}-hardened-bastion-ephemeral-sessions-policy"
  role        = "${aws_iam_role.role.id}"

  policy = "${data.aws_iam_policy_document.ephemeral_sessions.json}"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "${var.environment}-hardened-bastion-storage"
  acl    = "private"

  tags {
    Name        = "${var.environment}-hardened-bastion-storage"
    Environment = "${var.environment}"
  }
}

data "template_file" "ansible_terraform_bridge_vars" {
  template = "${file("${path.module}/assets/ansible_terraform_bridge_vars.yml")}"

  vars {
    global_ssh_user                                = "${var.global_ssh_user}"
    disable_root_user_ssh                          = "${var.disable_root_user_ssh}"
    disable_bash_history                           = "${var.disable_bash_history}"
    enable_ssh_port_knocking                       = "${var.enable_ssh_port_knocking}"
    ssh_port_knocking_port_range_lower_bound       = "${var.ssh_port_knocking_port_range_lower_bound}"
    ssh_port_knocking_port_range_upper_bound       = "${var.ssh_port_knocking_port_range_upper_bound}"
    ssh_port_knocking_firewall_config_network_cidr = "${var.vpc_cidr}"
    enable_ssh_tfa                                 = "${var.enable_ssh_tfa}"
    enable_ephemeral_ssh_sessions                  = "${var.enable_ephemeral_ssh_sessions}"
    cloudwatch_log_group_name                      = "${aws_cloudwatch_log_group.log_group.name}"
    region                                         = "${var.region}"
    ssh_users                                      = "${var.ssh_users}"
  }
}

resource "local_file" "ansible_terraform_bridged_vars" {
  content  = "${data.template_file.ansible_terraform_bridge_vars.rendered}"
  filename = "${path.module}/assets/ansible_playbook/group_vars/all.yml"
}

data "archive_file" "playbook_payload" {
  type        = "zip"
  source_dir  = "${path.module}/assets/ansible_playbook/"
  output_path = "${path.module}/assets/ansible_playbook.zip"

  depends_on = [
    "local_file.ansible_terraform_bridged_vars",
    "data.template_file.ansible_terraform_bridge_vars",
  ]
}

resource "aws_s3_bucket_object" "playbook" {
  bucket = "${var.environment}-hardened-bastion-storage"

  # We name the object with it's dependent objects md5
  # This is a workaround for a shortcoming in terraforms design (IMO)
  key = "${var.environment}_ansible_playbook_${md5(local_file.ansible_terraform_bridged_vars.content)}.zip"

  source = "${path.module}/assets/ansible_playbook.zip"
  etag   = "${data.archive_file.playbook_payload.output_md5}"
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = "${aws_s3_bucket.bucket.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "ALLOWBASTIONRETRIEVAL",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${aws_iam_role.role.arn}"
        ]
      },
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "${aws_s3_bucket.bucket.arn}/*"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${aws_iam_role.role.arn}"
        ]
      },
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "${aws_s3_bucket.bucket.arn}"
    }
  ]
}
POLICY
}
