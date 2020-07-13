ansible_dir=/root/JetSki/ansible-ipi-install

podman run -it \
	-v ./ansible-ipi-install/group_vars/all.yml:$ansible_dir/group_vars/all.yml:Z \
	-v ./ansible-ipi-install/inventory/jetski/hosts:$ansible_dir/inventory/jetski/hosts:Z \
	-t localhost/jetski
