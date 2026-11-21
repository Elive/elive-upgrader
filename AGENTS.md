To create a hook, you should create a directory in `/usr/lib/elive-upgrader/hooks-<codename>/<version>/[root|user]/`.

For example, using your current environment values (`$ELIVE_DISTRO` = `trixie`, version `3.8.52+`):
- Root hooks directory: `/usr/lib/elive-upgrader/hooks-trixie/3.8.52.01/root/`
- User hooks directory: `/usr/lib/elive-upgrader/hooks-trixie/3.8.52.01/user/`

### Hook Types & Execution Order:
Inside the `[root|user]` directories, files are executed/processed in this order:

1. `pre-*.sh`
   - Executed during the "pre" phase. Must be executable (`chmod +x`).

2. `packages-to-remove.txt`
   - List of packages to remove (one per line or space-separated).

3. `packages-to-install.txt`
   - List of packages to install (one per line or space-separated).

4. `packages-to-upgrade.txt`
   - List of packages to upgrade (only if already installed).

5. `*.sh` (Deprecated)
   - Executed if they don't start with "pre-" or "post-".

6. `CHANGELOG.txt` / `pre-CHANGELOG.txt` / `post-CHANGELOG.txt`
   - Text files containing release notes shown to the user.

7. `post-*.sh`
   - Executed during the "post" phase. Must be executable (`chmod +x`).
