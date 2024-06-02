include .env

.PHONY: configure check shell sync-env

# TODO:
# - use default ssh key when none are set (~/.ssh/id_rsa) if exists
#validate-env:
#	test ${private_key}

configure:
	ansible-playbook --user ${admin_user} --extra-vars "domain_name=${domain_name}" -i ./hosts ./playbooks/configure.playbook.yaml

#check:
#	ssh -i ${private_key} ${admin_user}@${instance_ip} "mysql --host ${mysql_host} --ssl-ca=${ssl_cert_path} -p${mysql_password}"

shell:
	ssh  ${admin_user}@${instance_ip}

proxy:
	ssh -TND 4711 ${admin_user}@${instance_ip}

# TODO
#clean:
