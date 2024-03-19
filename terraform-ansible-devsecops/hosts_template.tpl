[servers]
jenkins_instance ansible_host=${instance_ip_public} ansible_user=${ansible_ssh_user}

[all:vars]
ansible_python_interpreter=/usr/bin/python3
