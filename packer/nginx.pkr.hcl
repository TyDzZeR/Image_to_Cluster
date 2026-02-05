packer {
  required_plugins {
    docker = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

variable "image_name" {
  type    = string
  default = "steve-nginx"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

source "docker" "nginx" {
  image  = "nginx:alpine"
  commit = true
  changes = [
    "EXPOSE 80",
    "CMD [\"nginx\", \"-g\", \"daemon off;\"]"
  ]
}

build {
  name = "steve-nginx-build"
  
  sources = ["source.docker.nginx"]

  provisioner "file" {
    source      = "../index.html"
    destination = "/usr/share/nginx/html/index.html"
  }

  post-processor "docker-tag" {
    repository = var.image_name
    tags       = [var.image_tag]
  }
}
