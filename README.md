; -*- Mode: Markdown; -*-
; vim: filetype=none tw=76 expandtab

# ETORRENT

ETORRENT is a bittorrent client written in Erlang. The focus is on
robustness and scalability in number of torrents rather than in pure
speed. ETORRENT is mostly meant for unattended operation, where one
just specifies what files to download and gets a notification when
they are.

## Build Status

[![CI](https://github.com/kremlhi/etorrent/actions/workflows/ci.yml/badge.svg)](https://github.com/kremlhi/etorrent/actions/workflows/ci.yml)


## Why

ETORRENT was mostly conceived as an experiment in how easy it would be
to write a bittorrent client in Erlang. The hypothesis is that the
code will be cleaner and smaller than comparative bittorrent clients.

## Maturity

The code is at this point somewhat mature. It has been used in several
scenarios with a good host of different clients and trackers. The code
base is not known to act as a bad p2p citizen, although it may be
possible that it is.

The most important missing link currently is that only a few users
have been testing it - so there may still be bugs in the code. The
`master` branch has been quite stable for months now however, so it is
time to get some more users for testing. Please report any bugs,
especially if the client behaves badly.

## Currently supported BEPs:

   * BEP 03 - The BitTorrent Protocol Specification.
   * BEP 04 - Known Number Allocations.
   * BEP 05 - DHT Protocol
   * BEP 10 - Extension Protocol
   * BEP 12 - Multitracker Metadata Extension.
   * BEP 15 - UDP Tracker Protocol
   * BEP 23 - Tracker Returns Compact Peer Lists.

## Required software:

   * rebar3 - you need a working rebar3 installation to build etorrent.
     See https://rebar3.org for installation instructions.
   * Erlang/OTP - current and previous release are supported.
   * A UNIX-derivative as the operating system.

## GETTING STARTED

   0. edit `config/sys.config` - set at minimum these two keys:
      * `{dir, "/path/to/watch"}` - the directory etorrent watches for .torrent files
      * `{download_dir, "/path/to/downloads"}` - where downloaded files are written
      Both directories must exist before starting. The system checks `dir` every
      `dirwatch_interval` seconds (default: 20) for new .torrent files.
   1. check `config/vm.args` - Erlang args to supply
   2. be sure to protect the erlang cookie or anybody can connect to
      your erlang system! See the Erlang user manual in [distributed operation](http://www.erlang.org/doc/reference_manual/distributed.html)
   3. **development**: run `rebar3 shell` (or `make shell`) - compiles everything
      and starts an interactive Erlang shell with etorrent running. Reload a
      recompiled module with `l(ModuleName).` without restarting.
   4. **production**: run `make release` to assemble a release in
      *_build/default/rel/etorrent*, then run
      `_build/default/rel/etorrent/bin/etorrent console`
   5. to download a torrent, copy a .torrent file into the directory you configured
      as `dir`. Etorrent will detect it within `dirwatch_interval` seconds and
      begin downloading to `download_dir`.
   6. call `etorrent:help()` from the Erlang console for a list of commands to
      inspect and manage running torrents (list, pause, unpause, etc.).
   7. to use the web UI, set `{webui, true}` in `config/sys.config` before
      starting, then browse to http://localhost:8080 (or the configured
      `webui_port`). It shows per-torrent progress, peer counts, and rates.

## GETTING STARTED (Windows)

Windows users can run etorrent using the Windows Subsystem for Linux (WSL).

   0. Install WSL from PowerShell or cmd: `wsl --install`
   1. Open a WSL terminal and follow the standard GETTING STARTED steps above.

Windows drives are accessible from WSL at `/mnt/c/`, `/mnt/d/`, etc., so you
can point `dir` and `download_dir` at paths like `/mnt/c/Users/yourname/...`
if you want to watch a Windows folder or save downloads to a Windows location.

## Testing etorrent

Read the document [etorrent/TEST.md](/jlouis/etorrent/tree/master/TEST.md)
for how to run tests of the system.

## Troubleshooting

If the above commands doesn't work, we want to hear about it. This is
a list of known problems:

   * General: Many distributions are insane and pack erlang in split
     packages, so each part of erlang is in its own package. This
     *always* leads to build problems due to missing stuff. Be sure
     you have all relevant packages installed. And when you find which
     packages are needed, please send a patch to this file for the
     distribution and version so we can keep it up-to-date.

### Installing Erlang

The easiest way to install Erlang is with [kerl](https://github.com/kerl/kerl):

``` bash
$ curl -O https://raw.githubusercontent.com/kerl/kerl/master/kerl; chmod a+x kerl
$ ./kerl build latest latest
$ ./kerl install latest /opt/erlang/latest
$ . /opt/erlang/latest/activate
```

## QUESTIONS??

You can either mail them to `jesper.louis.andersen@gmail.com` or you
can come by on IRC #etorrent/freenode and ask.

# Development

## PATCHES

To submit patches, we have documentation in `documentation/git.md`,
giving tips to patch submitters.

## Documentation

Read the HACKING.md file in this directory. For how the git repository
is worked, see `documentation/git.md`.

## ISSUES

Either mail them to `jesper.louis.andersen@gmail.com` (We are
currently lacking a mailing list) or use the [issue tracker](http://github.com/jlouis/etorrent/issues)

## Reading material for hacking Etorrent:

   - [Protocol specification - BEP0003](http://www.bittorrent.org/beps/bep_0003.html):
     This is the original protocol specification, tracked into the BEP
     process. It is worth reading because it explains the general overview
     and the precision with which the original protocol was written down.

   - [Bittorrent Enhancement Process - BEP0000](http://www.bittorrent.org/beps/bep_0000.html)
     The BEP process is an official process for adding extensions on top of
     the BitTorrent protocol. It allows implementors to mix and match the
     extensions making sense for their client and it allows people to
     discuss extensions publicly in a forum. It also provisions for the
     deprecation of certain features in the long run as they prove to be of
     less value.

   - [wiki.theory.org](http://wiki.theory.org/Main_Page)
     An alternative description of the protocol. This description is in
     general much more detailed than the BEP structure. It is worth a read
     because it acts somewhat as a historic remark and a side channel. Note
     that there are some commentary on these pages which can be disputed
     quite a lot.
