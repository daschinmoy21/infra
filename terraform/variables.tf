variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-south-1-a"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "asia-south-1-a"
}

variable "machine_type" {
  description = "VM machine type"
  type        = string
  default     = "e2-medium"
}

variable "my_ip" {
  description = "Your public IP for SSH access (will be /32 in firewall)"
  type        = string
}

variable "repo_url" {
  description = "URL of this repository to clone on the VMs"
  type        = string
  default     = "https://github.com/Alchemyst-ai/hiring.git"
}


