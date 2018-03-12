output "ip" {
  value       = "${aws_eip.ip.public_ip}"
  description = "Public IP address for the bastion"
}

output "bucket_name" {
  value       = "${aws_s3_bucket.bucket.bucket}"
  description = "Bucket that houses the bootstrap resources"
}

output "ssh_command" {
  value       = "ssh -A ${var.global_ssh_user}@${aws_eip.ip.public_ip}"
  description = ""
}
