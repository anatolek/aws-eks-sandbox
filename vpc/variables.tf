variable "aws_region" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "rds_subnet_cidrs" {
  type = list(string)
}

variable "enable_nat_gateway" {
  type = bool
}

variable "single_nat_gateway" {
  type = bool
}

variable "map_public_ip_on_launch" {
  type = bool
}

variable "enable_dns_hostnames" {
  type = bool
}

variable "enable_dns_support" {
  type = bool
}

variable "additional_tags" {
  type = map(string)
}
