provider "aws" {
  alias                    = "cloud_providers"
  region                   = var.region
  shared_credentials_files = [var.shared_credentials_file]
  profile                  = "default"
}


# Create VPC
resource "aws_vpc" "jenkins-vpc" {
  provider             = aws.cloud_providers
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true" #gives you an internal domain name
  enable_dns_hostnames = "true" #gives you an internal host name
  instance_tenancy     = "default"
}

# Create Public Subnet for EC2
resource "aws_subnet" "jenkins-public-subnet" {
  vpc_id                  = aws_vpc.jenkins-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true" //it makes this a public subnet
  availability_zone       = var.AZ1

}


# Create IGW for internet connection 
resource "aws_internet_gateway" "jenkins-igw" {
  vpc_id = aws_vpc.jenkins-vpc.id

}

# Creating Route table 
resource "aws_route_table" "jenkins-public-rt" {
  vpc_id = aws_vpc.jenkins-vpc.id

  route {
    //associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"
    //CRT uses this IGW to reach internet
    gateway_id = aws_internet_gateway.jenkins-igw.id
  }

}


# Associating route tabe to public subnet
resource "aws_route_table_association" "jenkins-public-rt-and-jenkins-public-subnet" {
  subnet_id      = aws_subnet.jenkins-public-subnet.id
  route_table_id = aws_route_table.jenkins-public-rt.id
}

//security group for EC2
resource "aws_security_group" "ec2_allow_rule" {
  vpc_id = aws_vpc.jenkins-vpc.id
  tags = {
    Name = "allow_ssh_http_https"
  }

  ingress = [
    {
      from_port        = 8081
      to_port          = 8081
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Jenkins"
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      from_port        = 9000
      to_port          = 9000
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "Sonarcube"
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "SSH"
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      description      = "All traffic"
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
  ]
}


// Sends your public key to the instance
resource "aws_key_pair" "jenkins-key-pair" {
  key_name   = "jenkins-key-pair"
  public_key = file(var.PUBLIC_KEY_PATH)
}


# Create EC2
resource "aws_instance" "VM" {
  provider               = aws.skaletek # Use the correct provider alias
  count                  = length(var.VM-name)
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.jenkins-public-subnet.id
  vpc_security_group_ids = ["${aws_security_group.ec2_allow_rule.id}"]

  key_name = var.VM-name[count.index] == "jenkins_instance" ? aws_key_pair.jenkins-key-pair.id : null

  tags = {
    Name = var.VM-name[count.index]
  }
}

# Copy the jenkins public IP after VM creation to the host_template.tpl file
data "template_file" "hosts" {
  depends_on = [aws_instance.VM]
  template   = file("${path.module}/hosts_template.tpl")

  vars = {
    instance_ip_public = aws_instance.VM[0].public_ip
    ansible_ssh_user   = "ubuntu"
  }
}

# Save host file content to local file into ansible directory
resource "local_file" "hosts-rendered-file" {
  content  = data.template_file.hosts.rendered
  filename = "./ansible/hosts"
}

output "INFO" {
  value = join("\n", [
    for i, vm_name in var.VM-name :
    vm_name == "jenkins_instance" ? "Jenkins instance: http://${aws_instance.VM[i].public_ip}" :
    vm_name == "k8s-master" ? "K8s master instance: http://${aws_instance.VM[i].public_ip}" :
    vm_name == "k8s-worker" ? "K8s node instance: http://${aws_instance.VM[i].public_ip}" :
    null
  ])
}




resource "null_resource" "jenkins_instance_setup_usingn_ansible" {

  triggers = {
    instance_public_ip = aws_instance.VM[index(var.VM-name, "jenkins_instance")].public_ip
  }


  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.PRIV_KEY_PATH)
    host        = aws_instance.VM[index(var.VM-name, "jenkins_instance")].public_ip
    timeout     = "4m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y python3",
      "echo Done!"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -x /usr/bin/python3 ]; do sleep 5; done",
      "echo Python3 installation completed."
    ]
  }

  provisioner "local-exec" {
    command = <<EOT
     ansible-playbook -i ansible/hosts ansible/main.yml -u ubuntu --private-key=${var.PRIV_KEY_PATH}
    EOT  
  }
}



