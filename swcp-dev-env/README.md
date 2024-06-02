# Cachet deployment utils
Deploy [cachet](https://github.com/cachethq/cachet) on azure.

## Structure
The deployment is split into two parts:
- `provisioning` the virtual machine instance on Azure using terraform
- `installing` cachet on the provisioned instance

## Preparations
The terraform definition requires the access to the azure api, and cloudflare api (for dns management)
- The terraform azure provider is configured to use the credentials for the azure cli
- The cloudflare provider requires setting the `api_token/account_id` pair in the `terraform.tfvars` file

Required Terraform variables:
- `admin_username` (string) : this is the admin user created on the virtual machine
- `public_key` (path) : path to the public key to be added to our instance
- `domain_name` (string) : the domain name to link to the azure instance (managed by cloudflare)

Cloudflare hosted zone, we need to import the cloudflare hosted zone on which we need to operate, you can access the hosted zone id from the cloudflare dashboard. (e.i)
`terraform import cloudflare_zone.this 90b6cd9ff3b506e61b42dd7be2ea9bf8`

## Running
Example usage of the scripts

```bash
$ terraform init        # install the needed providers
$ terraform validate    # after adding our variables, we validate our config
$ terraform plan        # dry run, check for the changes
$ terraform apply       # provision ...
```

After provisioning is done, we populate the `.env` and `hosts` as outputs.

We can then, call our Makefile to install cachet

```bash
$ make configure        # this will run our playbook installation step on the vm
```

## Notes
- [Azure#Vm-selector](https://azure.microsoft.com/en-us/pricing/vm-selector/)

To get the full name of a size from the name in the vm-selector use
```
az vm list-sizes --location eastus > vm-sizes-eastus.json
jq '.[] |  select( .name | test("D2pls") )' vm-sizes-eastus.json
```

To list image ids
```
$ az vm image list --output table --all --publisher Canonical
$ az vm image list --output table --all --publisher Canonical --offer 0001-com-ubuntu-server-noble
```