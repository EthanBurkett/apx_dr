# Operator requirements

- All remote administration and file transfer MUST use Teleport (`tsh`).
- Use persistent interactive `tsh ssh -t` terminals for remote work whenever
  possible so command activity and output are captured in Teleport recordings.
- Do not invoke OpenSSH clients (`ssh`, `ssh.exe`, `scp`, `scp.exe`), ProxyJump,
  direct SSH connections, or configure port-22 access. Teleport's native
  `tsh ssh` / `tsh scp` commands use the authorized Teleport tunnel.
- The previous public server and its Proxmox host no longer exist. Do not use
  `apx.ethanburkett.dev` or `10.50.0.10` as administration targets.
- The replacement Deathrun server belongs in Miami, on Teleport node
  `mia-fl-01`. Use `tsh ls` to discover current resources. Operator login: root.
- Keep the guest OpenSSH service absent or disabled. Use Teleport enrollment
  and reverse-tunnel access for the VM; never add a direct SSH fallback.
- Never print credentials, include private settings in Git, or publish them
  to the CDN. Preserve existing operator configuration edits.

# Graphify

When the user types `/graphify`, read the installed graphify skill before doing
anything else. The installed skill is under the user's skills directories.
