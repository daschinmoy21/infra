variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "my_ip" {
  description = "Your public IP for SSH access (will be /32 in SG)"
  type        = string
}

variable "repo_url" {
  description = "URL of this repository to clone on the VMs"
  type        = string
  default     = "https://github.com/daschinmoy21/infra.git"
}
