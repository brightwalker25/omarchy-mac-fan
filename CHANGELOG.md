# Changelog

All notable changes to this plugin are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-09-25

The first public version.

### Added
- A bar glyph tinted green, amber or red from the CPU package temperature and
  whether mbpfan and the helper are running.
- A panel with the fan speed, the CPU package temperature, the clock against
  its turbo ceiling, and whether the CPU is throttling, judged from time spent
  throttled rather than the count of events.
- Four fan profiles for mbpfan (Quiet, Balanced, Performance and Max), written
  to `/etc/mbpfan.conf` by a root helper with fixed verbs, with the original
  config kept and restorable.
- A power profile row using `powerprofilesctl`.
- `bin/mac-fan` for the same from a terminal, and `bin/mac-fan-install` to set
  up mbpfan, the helper and its sudoers rule, or remove them.
