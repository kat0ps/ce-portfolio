## Environment setup

Lab variables are stored in a local env file and loaded 
into Cloud Shell:

```bash
# Variables used 
RG=rg-vnetfun-netmon
LOC=southafricanorth
SA1=stsvcep2648
SA2=stpe2468
```

```bash
# Load variables
source ~/vnetfun.env

# Verify
echo $RG   # rg-vnetfun-netmon
echo $LOC  # southafricanorth
```

This setup keeps creds out of source control 
while making commands repeatable across sessions.
