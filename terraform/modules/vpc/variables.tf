variable "source_ranges" {
  description = "Allowed IP addresses"
  default     = ["0.0.0.0/0"]
}

variable "env" {
  description = "Environment name: e.g., stage, prod"
  default     = ""
}
