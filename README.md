# Get SSM Inventory & Patch Details from CLI

Through console, we can see the SSM Managed Instances Inventory data:
![Alt text](images/ssm-inventory.jpg?raw=true "SSM Inventory")

SSM Managed Instances Patch Data:
![Alt text](images/ssm-patch.jpg?raw=true "SSM Patch")


To get the above data from CLI: Clone the Repo, Add the Instances IDs in "instanceids.txt" (One Instance Id in each line) and Execute the script with the following arguments:
```
./get-ssm-details.sh --action <action-name>
```
Provide <action-name> as  one of the available actions below:
```
- get-inventory-list
- get-patch-list 
- get-patch-summary
```
