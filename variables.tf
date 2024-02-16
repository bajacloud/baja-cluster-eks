variable "azs" {
  type        = list(string)
  description = "A list of availability zones in the region."
  default     = ["us-east-1a", "us-east-1b"]
}