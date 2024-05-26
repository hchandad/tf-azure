include .env

.PHONY: configure check shell sync-env

# TODO:
# - use default ssh key when none are set (~/.ssh/id_rsa) if exists
#validate-env:
#	test ${private_key}

configure:
	ansible-playbook -i ./hosts --private-key ${private_key} ./playbooks/configure.playbook.yml

#check:
#	ssh -i ${private_key} ${admin_user}@${instance_ip} "mysql --host ${mysql_host} --ssl-ca=${ssl_cert_path} -p${mysql_password}"

shell:
	ssh -i ${private_key} ${admin_user}@${instance_ip}

sync-env:
	scp -i ${private_key} .env ${admin_user}@${instance_ip}:~

proxy:
	ssh -i ${private_key} -TND 4711 ${admin_user}@${instance_ip}
