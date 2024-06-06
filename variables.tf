variable "env" {
    description = "Deployment environment"
    type        = string
}

variable "region" {
    description = "Deployment region"
    type        = string
}

variable "ami_id" {
    description = "EC2 Image"
    type        = string
}

variable "app_server_instance_type" {
    description = "Instance Type"
    type        = string
}

variable "key_pair_name" {
    description = "Key file name"
    type        = string
}

variable "prefix" {
    description = "Name added to all resources"
    type        = string
}

variable "resource_alias" {
    description = "My name"
    type        = string
}