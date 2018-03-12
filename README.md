## AWS Terraform'd Hardened Bastion with easy access management

I often see security practices referred to as hard or an afterthought, here's my attempt to make managing them reasonably straight forward inside a moderately sized team.

#### Features

A terraform module and example implementation to deploy a hardened bastion host, optional **features** include:

* Support for individual users on the bastion (great for who did what) public key authentication mechanism with support for TFA
* Access to the bastion requires a TFA token upon authentication
* Bastion kills itself on SSH session end, a compromised host is only compromised for the duration of the schedule
* Single Packet Authorisation over UDP exposes the SSH port, otherwise the bastion is not network accessible nor can it be port scanned
* Static public IP exposed, persistent across host lifecycle (compatible with a DNS A record)
* System hardened using Ansible playbook
* Users permissions & security requirements managed via a single YAML file
* Operations performed on bastion are centralized and stripped from the host, limiting the blast radius of a compromised bastion & enabling auditing

#### Getting started

Head to the example folder - you'll need an IAM User with credentials setup as a profile on your local machine.
You'll also need terraform installed locally.
If this is your first time using terraform I'd recommend reading the [getting started guide](https://www.terraform.io/intro/getting-started/build.html)

You can see a sample `users.yml` file in the example. This file controls access to the bastion as in what users to create, what permissions they have and what level of access controls are enforced for them.

The `bastion.tf` file contains a series of configuration directives which enable different parts of the system configuration, I've attempted to document them [in the example module](example/bastion.tf).

![demo](https://github.com/Dombo/hardened-bastion/raw/master/demo-bastion.gif)

#### Usage

```hcl
provider "aws" {
  shared_credentials_file = "/home/dom/.aws/credentials"
  profile                 = "personal-tfcli"
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
  vpc_id   = "vpc-63d46406"  # The VPC ID into which you want to deploy this bastion
  vpc_cidr = "172.31.0.0/16" # The corresponding CIDR block for that VPC - the bastion will only be able to communicate with hosts inside it's VPC/CIDR block

  public_subnet_ids = [
    "subnet-2fe45c58", # The public subnets in the VPC that the bastion can be created in
    "subnet-f85fcc9d",
    "subnet-a99bcaef",
  ]

  secret_0_public_key           = "${file("/home/dom/.ssh/id_rsa.pub")}" # The SSH public key you want uploaded to EC2 as a keypair, if all else fails this will always have access
  bastion_log_retention         = 14                                     # The number of days you want to retain logs that are centralised from the host
  disable_root_user_ssh         = "true"                                 # Prevents the default sudo user from SSHing in
  enable_ssh_port_knocking      = "true"                                 # Configures the system to require you broadcast a UDP packet to the host before it becomes visible on the internet
  enable_ssh_tfa                = "true"                                 # Configures the system to require TFA as part of the SSH authentication
  disable_bash_history          = "false"                                # If enabled, configures the system not to record any user actions on the system
  enable_ephemeral_ssh_sessions = "false"                                # If enabled, at the end of the SSH session the host will terminate and another will come back in it's place

  # The range between which a SPA packet will be accepted
  ssh_port_knocking_port_range_lower_bound = "62201"
  ssh_port_knocking_port_range_upper_bound = "62209"

  ssh_users = "${data.local_file.ssh_users.content}" # This is the file that configures the Users on the system, note secrets for TFA/Port Knocking are only required if they're enabled above

  # NOTE: The users file is effectively a secrets file, it should not be version controlled
}

output "ssh_command" {
  value = "${module.bastion.ssh_command}"
}
```

#### Contributing and Discussions

I'm open to maintaining & supporting this. If you wish to contribute and have an idea that's great, if you don't see below:

* [idea] Enable tracing of who authenticated and did what - currently we have both logged but not in a way that they can be traced - see the cloudwatch logs after a few sessions as an example
* [idea] Support organisations practicing ChatOps by sending a message to a room when an authentication is made - who logged in to what user from where
* [idea] Implement fail2ban against SSH public key authentications
* [idea] PGP sign the Single Packet Authorisation transmission datagram
* [idea] Configure a syslog log forwarding daemon so fwknop (the SSH single packet authorisation daemon) logs can be centralised
* [idea] Support for U2F two factor tokens such as a yubikey instead of just T/HOTP i.e. Google Authenticator
* [idea] There is a brief window of ~120 seconds where none of the secondary authentication mechanisms work, limit connections at this point somehow
* [bug] Pretty sure the eventual consistency of S3 leads to occasional errors to retrieve the zipped payload on bootstrap during development

[todo] Graph or blast radius?

#### Further Reading

[Author of the Single Packet Authorisation implementation](http://cipherdyne.org/blog/2015/04/nat-and-single-packet-authorization.html)
