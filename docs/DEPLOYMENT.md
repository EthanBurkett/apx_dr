# Public server and automatic deployment

ApX runs on Debian under `apx-dr.service`. GitHub's **Deploy production** workflow
builds on an ephemeral Windows worker after **Checks** succeeds for a push to
`main`. Branches and pull requests run checks without production credentials.
Manual deployment is also available from Actions, selecting `main`.

## Release path

1. Check out the exact approved commit and hydrate its LFS assets.
2. Fetch the private licensed SDK through SSH and verify its pinned SHA-256.
3. Run the complete Python suite; compile HLSL and link the fastfile.
4. Package three client files and **committed public configs** with a checksum
   manifest. Local operator config edits, credentials and SDK files are excluded.
5. Transfer the candidate through the restricted SSH jump account.
6. Run an isolated native server on loopback port 28961 for at least 20 seconds.
   It must answer a query and produce no detected script/asset-limit errors.
7. Stop production, upload the three public mod files to Bunny, purge the pull
   zone cache, and hash the actual public downloads.
8. Switch the release symlink, start production, and require a live server query.
   Failed activation restores the previous release **and its CDN files**.

Deployment briefly disconnects players. Deployments are serialized and are never
cancelled midway by a newer push. Superseded commits are skipped before upload.
An uncertain rollback is reported as a failed workflow; inspect it before retrying.

The native smoke test verifies startup, not interactive client menus or every map.
Test menu behavior in the official client before merging. Keep the branch/ruleset
protections configured for the repository; this workflow does not replace review.

## Credentials and network access

The GitHub `production` environment allows the `main` branch and contains:

| Type | Name | Purpose |
| --- | --- | --- |
| Secret | `APX_DEPLOY_KEY` | Dedicated Ed25519 CI identity; never a personal/root key |
| Variable | `APX_SSH_KNOWN_HOSTS` | Host keys obtained through the trusted operator SSH sessions |
| Variable | `APX_SDK_SHA256` | Pinned checksum of the private SDK ZIP |

`apx-ci@apx.ethanburkett.dev` can only forward to `10.50.0.10:22`; it cannot
open an interactive shell. `apxdeploy@10.50.0.10` can read the SDK and write
incoming packages. Its only sudo entry is the root-owned deployment helper,
which accepts one full commit SHA and rejects traversal, links, duplicate paths,
credentials, executable files and invalid release checksums.

GitHub does not receive the Bunny keys, RCON password, admin password or listing
token. `/etc/apx-dr/private.cfg` belongs to root and the server group (0640).
`/etc/apx-dr/bunny.env` belongs to root only (0600), with `access_key` and `api_key`.
Never print either file in Actions logs, put it in Git, or upload it to FastDL.

The licensed SDK is `/srv/apx-dr/sdk/build-sdk.zip`, readable only by the CI
account and root. It is not on Bunny or published as a GitHub artifact. Regenerate
it with `tools/prepare_ci_sdk.py` when intentionally updating the SDK, transfer it
privately, then update `APX_SDK_SHA256`. Updating the deploy helper itself requires
an operator install; a repository push cannot replace the root-owned helper.

For a replacement host or key rotation, transfer `server/linux/setup-ci.sh` and
the public CI key through your trusted operator session. Run its `jump` mode on
Proxmox and its `server` mode on the VM (with `deploy.py` beside it). Generate a
dedicated Ed25519 key with no passphrase, store its private half with
`gh secret set APX_DEPLOY_KEY --env production`, and remove the local private
copy after verifying the workflow. Obtain host-key pins from the existing trusted
sessions, rather than accepting unverified scan output.

## Layout and routine operations

| Path | Owns |
| --- | --- |
| `/srv/apx-dr/game` | Licensed game data, native server, validated usermaps |
| `/srv/apx-dr/game/mods/apx_dr` | Symlink to the active release |
| `/srv/apx-dr/releases/<commit>` | Retained candidate/release files |
| `/srv/apx-dr/incoming` | CI package staging |
| `/var/lib/apx-dr` | Writable server home, profiles and deployment logs |
| `/var/lib/apx-dr/deployed.json` | Active/previous revision and built checksums |
| `/usr/local/lib/apx-dr/deploy.py` | Root-owned activation and rollback implementation |

Connect through `ssh -J root@apx.ethanburkett.dev ethan@10.50.0.10`, then:

```sh
sudo systemctl status apx-dr
sudo journalctl -u apx-dr -n 80 --no-pager
sudo systemctl restart apx-dr
cat /var/lib/apx-dr/deployed.json
```

Keep journal output private if changing logging or querying credential cvars.
The generated RCON password is 12 alphanumeric characters and remains in the
private config. The listing token survives all deployments. Base `g_speed` is
210; the configured Jumper/Activator multipliers still apply.

Each new release filters the committed, measured map rotation against complete
public CDN downloads. The root-owned `/srv/apx-dr/map-files.json` records the
validated installed map files. Maps whose uploads are incomplete remain pending.
After adding maps to Bunny, the next new release admits those that are ready.
For a rotation-only update, run `tools/prepare_public_rotation.py` against the
validated manifest and install its config through your operator session. These
checks verify public availability and exact byte lengths; the installed-map
manifest separately records source SHA-256 checksums.

For a local, already-built **committed** release, set the SSH environment values
in your local shell and run:

```powershell
python tools/deploy.py package
python tools/deploy.py deploy
```

The first command only creates an ignored tar file; the second uploads and deploys.
Prefer merging to `main` so GitHub records the checks and deployment together.

To request the same main-branch workflow from your authenticated GitHub CLI,
without loading a deployment key locally, use `python tools/deploy.py trigger`.

## Master-list login workaround

The current token site's Steam link uses an old HTTP/IP callback. For this setup,
sign-in succeeded when Steam's OpenID `return_to` pointed directly to
`https://cod4master.cod4x.ovh/index.php?token_generator=true`, with the HTTPS
hostname as its realm. Returning to the server-list root did not retain sign-in.
The token was installed privately and the public list was checked for
`65.21.230.95:28960`. This is an observed workaround, not a change to CoD4x's site.

The native server uses the pinned CoD4x revision and pool patch described in
[the server guide](../server/README.md). Preserve its corresponding AGPL source
bundle and license when distributing the binary or providing network access.
