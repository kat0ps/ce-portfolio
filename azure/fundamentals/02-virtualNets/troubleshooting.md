# Lab 4.1 troubleshooting log

Real errors from building this lab, what caused them and how they were fixed.

## 1. VM creation rejected the admin password

**Section:** 3 (create the VMs)

**Error** (once per VM):

```text
The password length must be between 12 and 72. Password must have the 3 of the following:
1 lower case character, 1 upper case character, 1 number and 1 special character.
```

**Cause:** the password typed at the hidden `read -s` prompt didn't meet Azure's complexity rules (or was empty). `read -s` hides what you type, so a short or mistyped password isn't noticed until `az vm create` validates it. Nothing was created, so nothing was billed.

**Fix:** re-enter the password with a loop that checks length and character types before continuing (now in section 0 of [commands.sh](commands.sh)):

```bash
until [[ ${#VMPW} -ge 12 && "$VMPW" =~ [a-z] && "$VMPW" =~ [A-Z] && "$VMPW" =~ [0-9] && "$VMPW" =~ [^a-zA-Z0-9] ]]; do
  read -s -p "VM admin password (12+ chars, upper, lower, digit, symbol): " VMPW; echo
done; echo "Password OK (${#VMPW} chars)"
```

**Lesson:** validate secrets at the point they're entered, not at the point they're used. `${#VMPW}` shows the length without ever printing the password.

## 2. Standard_B1s not available (capacity)

**Section:** 3

**Error:**

```text
(SkuNotAvailable) The requested VM size for resource 'Following SKUs have failed for Capacity Restrictions:
Standard_B1s' is currently not available in location 'SouthAfricaNorth'.
```

**Cause:** Azure had no spare capacity for that size in the region. It's a temporary, regional condition, not a problem with the subscription or the command. The Azure CLI also printed a long Python traceback (`The content for this response was already consumed`) around the real error; that's a CLI display bug, and the useful line is the `SkuNotAvailable` one.

**Fix:** try other small sizes in order and keep the first that works. `Standard_B2ats_v2` (2 vCPU, burstable, AMD) succeeded. `Standard_B1ms` and `Standard_B1ls`, from the same older B-series family as B1s, were also out of capacity.

```bash
for SIZE in Standard_B2ats_v2 Standard_B2als_v2 Standard_B2s; do
  az vm create ... --size $SIZE -o none && { echo "OK: $SIZE"; break; }
done
```

## 3. Regional vCPU quota exceeded

**Section:** 3

**Error:**

```text
(QuotaExceeded) Operation could not be completed as it results in exceeding approved Total Regional Cores quota.
Location: SouthAfricaNorth, Current Limit: 4, Current Usage: 4, Additional Required: 2
```

**Cause:** the subscription allows **4 vCPUs per region**. Two B2ats_v2 VMs (2 vCPU each) used all 4, so the third VM was refused. Checked with:

```bash
az vm list-usage -l $LOC --query "[?name.value=='cores'].{used:currentValue, limit:limit}" -o table
```

**Fix:** a 1-vCPU size wasn't available (entry 2), so the lab runs with **two VMs**. vm-hub takes over the storage endpoint tests: the service endpoint is on the hub's `snet-shared`, and the private endpoint (still in the spoke's `snet-data`) is tested from vm-hub across the peering. The other option is a quota increase request (Quotas > Compute > Total Regional vCPUs), which free-trial subscriptions usually can't get.

**Lesson:** check quota *before* sizing a deployment. Capacity (entry 2) and quota are different problems: capacity is Azure's side and changes over time; quota is the subscription's limit and only changes by request.

## 4. Terminal "stuck" after a failed VM create

**Section:** 3

**Symptom:** after the quota error, Cloud Shell sat with no prompt and ignored typing.

**Cause:** the next line was `az vm wait -g $RG -n vm-data --created`, which waits (up to an hour) for a VM that was never created because its `--no-wait` create had failed.

**Fix:** **Ctrl + C** to cancel the wait; nothing is deleted. `commands.sh` no longer uses `--no-wait` and `az vm wait` for the VMs, so a failed create shows its error immediately.

## 5. Cloud Shell lost its sign-in while creating Bastion

**Section:** 5

**Error:**

```text
The command requires the extension bastion. Do you want to install it now? (Y/n): y
A Cloud Shell credential problem occurred.
Timeout waiting for token from portal. Audience: https://management.core.windows.net/
```

Then restarting Cloud Shell failed with `Request failed with status code 401`.

**Cause:** the Azure portal session had expired. Cloud Shell gets its Azure token from the portal, so once the portal sign-in lapsed, both the extension install and the restart were refused (401 = not authenticated).

**Fix:**
1. Refresh the portal page (or sign out and back in), then reopen Cloud Shell. The home directory persisted, so `~/vnetfun.env` was still there: `source ~/vnetfun.env` and redefine `vmrun`.
2. Allow CLI extensions to install without a prompt: `az config set extension.use_dynamic_install=yes_without_prompt`.
3. Check before re-creating: `az network bastion list -g $RG -o table` showed `bas-hub` **Succeeded**. The first request had already reached Azure before the token problem, so the resource existed.

**Lessons:**
- Check whether a resource exists before re-running a create after an error; the request may have succeeded on Azure's side even if the client failed.
- Paste long commands as a single line. A multi-line paste ran `az config set` but appeared to skip the next command.
