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
