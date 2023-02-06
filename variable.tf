variable "availability_zones" {
  type = list(string)

  default = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c",
  ]
}


variable "domain_name" {
    default = "timilehinadebayo.me"
    description = "domain-name"
    type = string
  
}


variable "sub_domain_name" {
    default = "www"
    description = "sub_domain_name"
    type = string
  
}