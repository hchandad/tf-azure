# A Terraform/Azure demo


The files in this directory, where used to create a linux virtual machine, and mysql flexible server, connected with a fire wall rule.

The `make configure` target, configures the created instance, and `make check` checks the mysql connection from it.

Using it, requires manually setting the .env vars file with:

```
instance_ip="20.XX.XXX.XXX"
mysql_host="<fqdn>.mysql.database.azure.com"
mysql_password="xxxxxxxxxxxxxxxx"
ssl_cert_path=/opt/DigiCertGlobalRootCA.crt.pem
private_key=/path/to/private_key.pem
admin_user=whoami?
```