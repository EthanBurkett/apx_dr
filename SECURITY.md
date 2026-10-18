# Security and private configuration

Keep RCON, server and admin credentials in ignored config/private.cfg.
The builder deploys it locally as loose config; uploading the entire dist
directory can expose it.

The audit excludes private configs before reading and redacts credential values
found in public configs. It is a guard for common mistakes, not a full secret scanner.

## Report a sensitive issue

Do not put passwords, access bypasses, player data or raw logs in public issues.
Contact the repository owner privately through the hosting platform. If private
vulnerability reporting is enabled, use that channel. No email or SLA is assumed.

Include affected commit, reproduction, required access and impact. Redact secrets
and identifiers. Revoke/rotate leaked credentials first; deleting a file in a later
commit does not remove history.

## Runtime boundaries

Admin/VIP menu visibility is not authorization. GSC must enforce every privileged
response. Client dvars, menu selections and saved customization are untrusted.

Importers treat packs as data and do not execute supplied scripts. Review
dependencies/rights first. Native fixtures use loopback and owned processes;
do not expose test fixtures as a public server.

See [releasing](docs/RELEASING.md) for public artifact boundaries.
