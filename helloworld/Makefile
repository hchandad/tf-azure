include .env

.PHONY: configure


configure:
	ansible-playbook -i ./hosts --private-key ${private_key} ./playbooks/configure.playbook.yml

check:
	ssh -i ${private_key} ${admin_user}@${instance_ip} "mysql --host ${mysql_host} --ssl-ca=${ssl_cert_path} -p${mysql_password}"

shell:
	ssh -i ${private_key} ${admin_user}@${instance_ip}

sync-env:
	scp -i ${private_key} .env ${admin_user}@${instance_ip}:~
