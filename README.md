# omarchy-mac-fan

Fan profiles for Intel Macs on the Omarchy bar. A fan glyph, tinted green,
amber or red, opens a panel with the fan speed, the CPU package temperature,
the clock against its turbo ceiling, and whether the CPU is throttling, plus
two rows of buttons: how eagerly the fan spins up, and the power profile.

The fan itself is driven by [mbpfan](https://github.com/linux-on-mac/mbpfan),
which reads `coretemp` and sets the speed through `applesmc`. This plugin does
not replace it. Each profile is a fixed set of mbpfan thresholds, written to
`/etc/mbpfan.conf` by a small root helper, after which mbpfan is sent SIGHUP
and picks it up without restarting.

Written for, and verified on, an Intel iMac with a single fan. It should work
on any Mac mbpfan supports, since fan limits are read from the SMC rather than
assumed.

## Why this exists

Apple has stopped updating macOS for many Intel Macs, including iMacs that
are still perfectly capable machines. Installing Linux, and Omarchy in
particular, gives them a current, maintained system again, but it leaves the
fan to mbpfan, which runs on a single fixed set of temperature thresholds that
you edit by hand in `/etc/mbpfan.conf`. That one setting is either quiet and
hot or cool and loud, and nothing on the desktop tells you which you have,
how hot the CPU is running, or whether it has started to slow itself down to
cope.

This plugin puts that on the bar. It shows the fan speed, the CPU temperature
and whether the CPU is throttling, and it switches mbpfan between a few tested
profiles with one click, so an old Mac can be quiet for everyday work and
still run flat out for a long render or build.

## Profiles

| Profile | Fan floor | Ramps from | Flat out at | For |
|---|---|---|---|---|
| Quiet | the SMC minimum | 68°C | 86°C | silence; the CPU runs hotter |
| Balanced | the SMC minimum | 55°C | 80°C | everyday use |
| Performance | 40% of the range | 50°C | 72°C | long loads, keeping turbo headroom |
| Max | full speed | - | - | renders and builds; audible |

"Ramps from" is mbpfan's `high_temp`; below `low_temp` (5 to 8°C lower) the
fan winds back to its floor. The floor is a fraction of the way from the
fan's own minimum to its maximum, so it scales to whatever fan the Mac has.

The power profile row calls `powerprofilesctl`, which needs no root. For the
most speed, pair Performance power with the Performance or Max fan profile.

## Installing

```bash
git clone https://github.com/brightwalker25/omarchy-mac-fan.git ~/Work/omarchy-mac-fan
~/Work/omarchy-mac-fan/bin/mac-fan-install --dry-run   # see what it will do
sudo ~/Work/omarchy-mac-fan/bin/mac-fan-install
ln -s ~/Work/omarchy-mac-fan ~/.config/omarchy/plugins/brightwalker25.mac-fan
omarchy-shell shell rescanPlugins
omarchy plugin enable brightwalker25.mac-fan --section right --after brightwalker25.system
```

The installer installs and enables mbpfan if it is missing, copies the helper
to `/usr/local/lib/omarchy-mac-fan/apply` (root-owned, so editing the plugin
folder cannot change what root runs), and writes
`/etc/sudoers.d/omarchy-mac-fan`, checked with `visudo`, which lets your
account run that helper with one of six fixed verbs and nothing else:

```
version  restore  profile-quiet  profile-balanced  profile-performance  profile-max
```

No verb takes a value. Run the installer again after pulling a new version.
Nothing changes until you pick a profile.

The first profile you apply keeps the existing config as
`/etc/mbpfan.conf.pre-mac-fan`. `mac-fan restore` puts it back.

## From a terminal

```bash
bin/mac-fan status --text
bin/mac-fan profile performance
bin/mac-fan power performance
bin/mac-fan restore
```

Keybindings can switch profile without opening the panel:
`omarchy-shell brightwalker25.mac-fan performance` (also `quiet`, `balanced`,
`max`, and the usual `open`, `close`, `toggle`, `refresh`).

## The glyph and "throttling"

The glyph is amber when mbpfan is not running or the helper is missing, and
amber or red as the CPU package nears its critical temperature.

Throttling is judged from the time the CPU has spent throttled, not the
number of throttle events. Some Intel CPUs log bursts of events at ordinary
temperatures that add up to no measurable time; the panel only says
"throttling now" when the throttled time rises by 50 ms or more.

## Uninstalling

```bash
sudo ~/Work/omarchy-mac-fan/bin/mac-fan-install --uninstall
omarchy plugin disable brightwalker25.mac-fan
rm ~/.config/omarchy/plugins/brightwalker25.mac-fan
```

Uninstalling restores the original `/etc/mbpfan.conf` and leaves mbpfan
itself installed and running.

## Credits

The real work of driving a Mac's fan on Linux is done by
[mbpfan](https://github.com/linux-on-mac/mbpfan), and this plugin only
chooses its settings. Thanks to:

- [Allan McRae](http://allanmcrae.com/2010/05/simple-macbook-pro-fan-daemon/),
  who wrote the original simple MacBook Pro fan daemon in 2010 that mbpfan
  grew from.
- [Daniel Graziotin](https://github.com/dgraziotin), who developed it into
  mbpfan as it is today.
- The [linux-on-mac](https://github.com/linux-on-mac) maintainers and every
  mbpfan contributor, who keep it working on Macs Apple no longer supports.

mbpfan is licensed under the GPL-3.0 and is installed separately, from your
distribution's packages.

## Written with AI help

Yes, an AI helped write this. No, it is not Skynet. Or is it? Either way, I
have checked the code to make sure it is not plotting Judgment Day. If that
still puts you off, no hard feelings. The whole point of Linux is that you
decide what runs on your computer.

## Licence

MIT. The bar-widget and panel scaffolding is derived from Omarchy's own
plugins (MIT, Copyright (c) David Heinemeier Hansson).
