provider "aws" {
  shared_credentials_file = "/home/austin/.aws/credentials"
  profile                 = "personal"
  region                  = "ap-southeast-2"
}

# Imagine you wanted a static entrypoint to your bastion, persistent across scaling events
//resource "aws_route53_record" "bastion" {
//  zone_id = "..."
//  name    = "bastion.example.com"
//  type    = "A"
//  ttl     = "3600"
//  records = ["${module.bastion.ip}"]
//}

# Any keys added to this level of the bucket will be granted access to the global_ssh_user
# Bad for traceability, you don't need to use these you can instead do what is done below
resource "aws_s3_bucket_object" "employee_a_key" {
  bucket = "${module.bastion.bucket_name}"
  key    = "keys/employee_a_key.pub"
  source = "keys/employee_a_key.pub"
  etag   = "${md5(file("keys/employee_a_key.pub"))}"
}

data "local_file" "ssh_users" {
  filename = "${path.module}/users.yml"
}

module "bastion" {
  source   = "../"
  vpc_id   = "vpc-a564cec2"  # The VPC ID into which you want to deploy this bastion
  vpc_cidr = "172.31.0.0/16" # The corresponding CIDR block for that VPC - the bastion will only be able to communicate with hosts inside it's VPC/CIDR block

  public_subnet_ids = [
    "subnet-381e7871", # The public subnets in the VPC that the bastion can be created in
    "subnet-458aff22",
    "subnet-cf0cfa97",
  ]

  secret_0_public_key           = "${file("/home/austin/.ssh/id_rsa.pub")}" # The SSH public key you want uploaded to EC2 as a keypair, if all else fails this will always have access
  bastion_log_retention         = 14                                        # The number of days you want to retain logs that are centralised from the host
  disable_root_user_ssh         = "true"                                    # Prevents the default sudo user from SSHing in
  enable_ssh_port_knocking      = "true"                                    # Configures the system to require you broadcast a UDP packet to the host before it becomes visible on the internet
  enable_ssh_tfa                = "false"                                   # Configures the system to require TFA as part of the SSH authentication
  disable_bash_history          = "false"                                   # If enabled, configures the system not to record any user actions on the system
  enable_ephemeral_ssh_sessions = "false"                                   # If enabled, at the end of the SSH session the host will terminate and another will come back in it's place

  # The range between which a SPA packet will be accepted
  ssh_port_knocking_port_range_lower_bound = "62201"
  ssh_port_knocking_port_range_upper_bound = "62209"

  ssh_users = "${data.local_file.ssh_users.content}" # This is the file that configures the Users on the system, note secrets for TFA/Port Knocking are only required if they're enabled above

  # NOTE: The users file is effectively a secrets file, it should not be version controlled
}

output "ssh_command" {
  value = "${module.bastion.ssh_command}"
}
