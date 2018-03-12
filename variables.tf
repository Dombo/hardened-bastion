variable "vpc_id" {
  type        = "string"
  description = "(Required) The VPC ID you are deploying into"
}

variable "vpc_cidr" {
  type        = "string"
  default     = "172.31.0.0/16"
  description = "(Required if Port Knocking enabled) The CIDR range of the VPC this is being deployed into, this is used in the on-host firewall configuration"
}

variable "public_subnet_ids" {
  type        = "list"
  description = "(Required) The public subnets the bastions can deploy into"
}

variable "secret_0_public_key" {
  type        = "string"
  description = "(Required) The public key to create an EC2 KeyPair from & load the bastions with"
}

variable "global_ssh_user" {
  type        = "string"
  default     = "ubuntu"
  description = "The username $(whoami) of the user that runs the SSHd"
}

variable "disable_root_user_ssh" {
  type        = "string"
  default     = "false"
  description = "Whether or not to disable SSH access for the default sudo user"
}

variable "disable_bash_history" {
  type        = "string"
  default     = "false"
  description = "Whether or not to disable the bash history on the host, limits exfiltration opportunities for a compromised host"
}

variable "ssh_users" {
  type        = "string"
  default     = ""
  description = "The users map you want to create within the bastion - contains usernames & public keys"
}

variable "enable_ssh_tfa" {
  type        = "string"
  default     = "false"
  description = "Whether or not to configure & require TFA for SSH authentication"
}

variable "enable_ssh_port_knocking" {
  type        = "string"
  default     = "false"
  description = "Whether or not to configure single packet authorization to initially expose SSH communication"
}

variable "enable_ephemeral_ssh_sessions" {
  type        = "string"
  default     = "false"
  description = "Whether or not to configure the system to kill itself after an SSH session exits, increasing complexity for attackers"
}

variable "keys_update_frequency" {
  type        = "string"
  default     = "0 * * * *"
  description = "How frequently (crontab expression) to fetch the public keys from the bucket if enabled"
}

variable "ssh_port" {
  type        = "string"
  default     = "22"
  description = "The Port to expose SSH on"
}

variable "ssh_allowed_cidr_block" {
  type        = "string"
  default     = "0.0.0.0/0"
  description = "(Recommended) An explicit CIDR block to restrict external access to"
}

variable "ssh_port_knocking_port_range_lower_bound" {
  type        = "string"
  default     = "62201"
  description = "(Recommended to change) Lower boundary of the port knocking port range, it's advisable to change the default"
}

variable "ssh_port_knocking_port_range_upper_bound" {
  type        = "string"
  default     = "62209"
  description = "(Recommended to change) Upper boundary of the port knocking port range, it's advisable to change the default"
}

variable "region" {
  type        = "string"
  default     = "ap-southeast-2"
  description = "The region to deploy into"
}

variable "environment" {
  type        = "string"
  default     = "prod"
  description = "The environment you are deploying for"
}

variable "bastion_log_retention" {
  type        = "string"
  default     = "14"
  description = "How many days to store bastion logs for in Cloudwatch"
}
