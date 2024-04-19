# az account list-locations | jq ".[] | .name"  | grep eu
variable "azlocation" {
  default     = "northeurope"
  description = "Location of the resource group."
}

variable "ownerref" {
  type        = string
  default     = "jdoe"
  description = "Owner of the project short name for naming resources"
}

variable "owneremail" {
  type        = string
  default     = "john.doe@acmecompany.com"
  description = "Owner of the project email"
}

# can be used identify the customer or the reason why you are building it
# it is mainly used if you want to use 2 different environments for different purposes
variable "project" {
  type        = string
  default     = "test"
  description = "project name"
}

variable "activity" {
  type        = string
  default     = "demo"
  description = "activity"
}

variable "ssh_public_key" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  description = "your ssh key path"
}



locals {
  projectname = format("%s-%s", var.ownerref, var.project)
  tags = {
	    owner = var.owneremail
      activity = var.activity 
	    project = var.project
  }
}
