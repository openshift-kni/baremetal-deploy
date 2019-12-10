# Validating PTP operator

## How to use

* Edit the `ptpconfig*yaml` files if the target nics on your environment is different that `eno2`. To figure out if a nic is PTP enabled, you can use `ethtool -T $nic` 
* Run the `deploy.sh` script

It will deploy the PTP operator and select one of the masters randomly to act as the grandmaster and the other nodes as slaves.
