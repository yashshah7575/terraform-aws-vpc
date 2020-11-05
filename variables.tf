variable "aws_region" {
  description = "The AWS region to create things in."
  #default     = "ca-central-1"
  #default = "us-east-1"
  #default = "us-west-2"
  default = "ap-south-1"
}

variable "name"{
  default = "ManageUser"
}

variable "environment"{
  default = "Dev"
}


variable "subnet_count" {
  default = 3
}

variable "subnet_cidr_size" {
  default = 26
}

variable "default_tags" {
  default     = { ApplicationName = "Manage User Applcation", Environment = "Dev" }
  description = "Additional resource tags"
  type        = map(string)
}


#hub_default_route = tgw = true
#service_rail_route = tgw = true
#on_prem_route = tgw = false