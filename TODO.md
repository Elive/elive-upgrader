# TODO: automatic security updates

Requirement record for the unattended security update feature. Checklist, not a
design doc: decisions are locked, tasks are what remains.

## Goal

Machines running Elive stay patched against Debian security advisories without
the user doing anything, and the user finds out both when a patch has been
applied and when an installed package has a known unpatched issue.

## Locked decisions

- Scope: `elive-upgrader` package. The feature ships in the package, so it
  reaches every Elive machine through the normal repo.
- Trigger: `/etc/cron.d`, not a systemd timer. Cron is init-agnostic, so the
  feature behaves the same under systemd and OpenRC. No new init integration.
- Privilege: the cron entry runs as `root` in its own right. No sudoers change,
  no dependency on `elive-upgrader-root`.
- Cadence: hourly light probe, act only when the repo actually changed.
- Upgrade scope: packages from `Debian-Security` only.
- Escalation: if a security package cannot be installed without touching other
  packages, include those. If that is still not enough, full upgrade. Last
  resort only, and always recorded in the log.
- Notification: a marker file under `/var/run`, consumed by the first graphical
  session that reads it, then cleared. Same pattern as `reboot-required`.
- Architecture: current machine architecture only (amd64 on amd64). No foreign
  arch indices.
- The `no AI` rule: advisories are consumed from Debian's structured feeds. No
  model, no summariser, no package list leaving the machine.

## Why cron.d and not a timer

| Property | systemd timer | `/etc/cron.d` |
|---|---|---|
| Works under OpenRC without extra code | no | yes |
| Needs the user logged in | no | no |
| Survives reboot without `enable` per system | no | yes |
| Extra package or integration | unit file | nothing, cron is already there |

`cron` and `anacron` are already present in the Elive base, and `/etc/cron.d`
already carries entries from other packages.

## Measured baseline

Numbers taken from the live repos, used to size the feature.

| Item | Value |
|---|---|
| `InRelease` trixie-security, full GET | 43409 B |
| Conditional GET with `If-Modified-Since` | `304`, 0 B body, 329 B total response |
| `HEAD` | 0 B body |
| Cost of 24 hourly probes | 7.7 KiB/day, 0.23 MiB/month |
| Probe latency | ~0.11 s |
| `Packages.xz` main amd64 | 294.5 KiB |
| `Packages.xz` main i386 (unused) | 244.7 KiB |
| Full tracker JSON (89 MB) | server side only, never per client |
| Unpatched-CVE JSON, trixie, gzipped | 44.8 KiB |

`deb.debian.org` is behind Varnish with `max-age=120`, so detection can lag up
to two minutes. Fine for an hourly probe, not a real-time guarantee.

## Phase 1: probe

- [ ] Worker script `/usr/lib/elive-upgrader/elive-security-worker`, mode
      `--probe`.
- [ ] Conditional GET on the `InRelease` of every enabled Debian security
      source, reusing the `Last-Modified` value from the previous run.
- [ ] Store the validator and the fetched timestamp in a state dir owned by
      root, for example `/var/lib/elive-security/`.
- [ ] Exit with no further work on `304`. Do not call `apt-get update`.
- [ ] `flock` around the whole run so it cannot collide with an interactive
      `elive-upgrader` or with `apt-daily`.
- [ ] Respect the existing apt list lock wait instead of failing on it.
- [ ] `/etc/cron.d/elive-security`, hourly, with `SHELL` and `PATH` set
      explicitly.
- [ ] Log every run to `/var/log/elive-security/`, including the runs that do
      nothing.

## Phase 2: update

- [ ] On `200`, refresh only the security source lists, not every repo.
- [ ] Restrict the fetch to the current architecture
      (`APT::Architectures`), dropping the i386 index.
- [ ] Compute which installed packages are behind the candidate version in the
      security source.
- [ ] Upgrade those packages.
- [ ] Escalate if the upgrade cannot be applied without touching other
      packages, then to a full upgrade as last resort. Record which path was
      taken.
- [ ] Non-interactive throughout: `DEBIAN_FRONTEND=noninteractive`,
      `DEBIAN_PRIORITY=critical`, no conffile prompts.
- [ ] Never run while the apt list lock or the dpkg lock is held by someone
      else; wait, then proceed.
- [ ] Write the outcome (packages, versions, path taken, errors) to the state
      dir for the notification layer.

## Phase 3: notification

- [ ] Marker file in `/var/run`, world-readable, written by the worker.
- [ ] Separate marker for "update applied" and "unpatched package installed".
- [ ] Consumer runs in the graphical session: reuse the `elive-news` widget and
      its history file so the same notice is not repeated.
- [ ] Clear the marker once shown.
- [ ] Show what happened: package names and old to new version, not a count.
- [ ] Never block the desktop. If no session is open, the notice waits for the
      next one.

## Phase 4: unpatched package warnings

This is the only part that needs data from outside apt, and the only part that
can say "this is not fixed yet".

- [ ] Server side: pull Debian's structured advisory data once a day, compute
      the packages with CVEs still open for the Elive base suite, publish a
      small JSON plus a checksum.
- [ ] Server side: publish only the fields the client needs (package, CVE,
      description, fixed version or none). No client ever sends its package
      list.
- [ ] Client: fetch that JSON on the same hourly schedule, behind the same
      conditional GET, compare against `dpkg-query`.
- [ ] Raise "installed and unpatched, avoid until fixed" when a CVE is open.
- [ ] Clear it automatically when Debian moves the CVE to resolved. The
      "you can use it again" notice comes from the same mechanism, no extra
      state machine.
- [ ] Keep the whole payload under ~50 KiB gzipped so the hourly cost stays
      negligible.

## Integration constraints

- [ ] `el_aptget_update` keeps a 4 hour stamp in
      `/var/lib/apt/lists/partial` and would block the hourly probe. Give the
      security path its own cadence or its own stamp; do not lower the global
      one.
- [ ] Reuse `el_aptget` for lock waiting rather than reimplementing it.
- [ ] Reuse `el_config_get` / `el_config_save` for user-visible settings.
- [ ] New strings go through gettext, like the rest of the package.
- [ ] Keep the existing `elive-upgrader` interactive flow untouched. This
      feature is a parallel path, not a rewrite.
- [ ] Decide and document how the worker coexists with `unattended-upgrades`
      if it is present in the base: two updaters fighting over the same lock is
      the failure mode to design out.

## Configuration

- [ ] Setting to enable or disable the automatic path, off or opt-in as
      appropriate for a first release.
- [ ] Setting for the probe interval.
- [ ] Setting for metered connections: skip the update, keep the probe.
- [ ] Setting for the last-resort full upgrade, so a user or a remaster can
      forbid it.

## Verification

- [ ] Probe against a repo with no change produces a `304` and no apt call.
      Assert on the log and on the byte count.
- [ ] Probe against a repo with a change triggers exactly one update.
- [ ] Two runs in parallel: `flock` serialises them, no dpkg error.
- [ ] Behaviour with no graphical session: update happens, notice is pending,
      nothing crashes.
- [ ] Behaviour with two graphical sessions: notice shown once.
- [ ] Behaviour on a metered connection.
- [ ] Behaviour with the apt lock held by a manual `apt` run.
- [ ] Works on a system booted with OpenRC and on one booted with systemd.
- [ ] Uninstall removes the cron entry and leaves no orphan state.
- [ ] Package builds and installs cleanly; `postinst` is idempotent.

## Open questions

- Where the server-side JSON lives on `repo.trixie.elive.elivecd.org`.
- Whether the hourly probe should also cover the Elive repo for "update
  available" (not for automatic install, just for the notice).
- Behaviour when the user is actively using a package that gets updated: notice
  to restart, or hold the update until the app closes.
