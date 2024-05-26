## Dependencies

    $ ansible-galaxy role install nickjj.docker

## Misc

Filter the available vms in a region e.i:

    $ az vm list-sizes --location uaenorth | jq '.[] | select( .numberOfCores == 8 )'