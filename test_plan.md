# etorrent test plan

This document collects test ideas that are not yet implemented, grouped by
area. Items here are candidates for new EUnit tests, Common Test cases, or
property-based tests.

## Supervisor restart behaviour

### Torrent supervisor crash recovery

`etorrent_torrent_sup` uses `{one_for_all, 1, 60}`. Two scenarios are not
covered:

- Kill one child of a running torrent supervisor (e.g. `etorrent_torrent_ctl`)
  and verify that the supervisor restarts all children and the torrent reappears
  in `etorrent_table` with the correct state. Currently there is no test that
  confirms recovery happens at all.

- Trigger two crashes within 60 seconds to exhaust the restart budget. The
  supervisor should terminate, and the torrent entry should be removed from
  `etorrent_table` rather than left in an inconsistent state. No test covers
  this path.

### Tracker communication crash triggers one_for_all restart

`etorrent_tracker_communication` is started as a `transient` child inside
`etorrent_torrent_sup`. An integration test should feed the tracker
communication process a malformed response (e.g. return garbage from a test
tracker for one request), verify that the process exits abnormally, and then
confirm that:

1. The `one_for_all` restart fires and all sibling children restart.
2. The torrent recovers and remains in `etorrent_table`.
3. The restart does not exceed the 1-in-60s budget, so the torrent supervisor
   itself stays alive.

## Seeder stability

No existing test asserts that the seeder's torrent supervisor keeps running
throughout a transfer. The `seed_leech` case only checks download completion on
the leecher side. A stability check should:

- After `start_app` on the seeder node, monitor the torrent supervisor PID via
  `erlang:monitor`.
- Assert no `DOWN` message arrives during the entire transfer.
- Assert the torrent entry in `etorrent_table` remains valid from the moment the
  seeder announces until the leecher finishes.

## Tracker response formats

### Dict-model peer list parsing

`etorrent_utils:decode_ips/1` has two clauses: one for the compact binary
format (`<<B1:8, B2:8, B3:8, B4:8, Port:16/big, Rest/binary>>`) and one for
the dict model (`[IPDict | Rest]`). Only the compact format is exercised by
existing tests. An EUnit test should:

- Build a dict-model peer list as a list of bencoded dicts, each with `"ip"`
  and `"port"` keys.
- Call `etorrent_utils:decode_ips/1` on that list.
- Assert the returned `{IP, Port}` tuples match the input values.

A property-based variant could generate random lists of `{IP, Port}` pairs,
encode them as dict-model lists, decode them, and check the round-trip.

## Peer self-connection

When the seeder announces to the tracker it may receive its own IP and port
back in the peer list. `spawn_peer` in `etorrent_peer_mgr` handles this via:

```erlang
{ok, _Capabilities, LocalPeerId} -> ok;
{ok, _Capabilities, LocalPeerId2} -> ok;
```

There is no test that exercises this branch. A unit or integration test should:

- Arrange for the tracker to return the seeder's own address in the peer list
  (e.g. by having the test tracker include the announcing peer in the response).
- Confirm that the seeder does not start a peer control process for itself
  (i.e. no new entry appears in `etorrent_table` for a peer whose peer_id
  matches the local peer_id).
- Confirm that no error or crash results from the self-connection attempt.

## Fast resume and seeding state

The seeder starts with `state=unknown` and goes through piece checking before
networking starts. After checking completes the torrent should be marked as
seeding (all pieces valid). No test verifies this transition. A test should:

- Start the seeder with a complete, valid data file.
- Wait for piece checking to finish (poll `etorrent_table` until `state` is no
  longer `unknown` or `checking`).
- Assert that the final state recorded in `etorrent_table` is `seeding`.
- Assert that the valid-piece count equals the total piece count reported by
  `etorrent_torrent:num_pieces/1`.

## UDP tracker

### Real UDP tracker announce test

The `udp_seed_leech` CT test was originally designed to run a seed/leech cycle
using a UDP tracker announce. In CI the test tracker (`etorrent_test_tracker`)
only speaks HTTP, so the torrent's announce URL was temporarily changed to HTTP
to keep CI green.

To actually test `etorrent_udp_tracker_proto` and `etorrent_udp_tracker_mgr`
end-to-end, `etorrent_test_tracker` should grow a minimal UDP tracker handler
implementing the BitTorrent UDP tracker protocol (BEP 15):

1. Accept a connection-request datagram, respond with a `connection_id`.
2. Accept an announce datagram with that `connection_id`, respond with a peer
   list in the same dict format the HTTP tracker already produces.

Once that exists, revert the announce URL back to `udp://localhost:6969/announce`
and confirm the full seed/leech cycle completes.

## Observability TODOs

### Compare error_logger vs ETS for crash capture in CT

Currently the diagnostic approach inserts crash reasons into a public
`torrent_crash_log` ETS table (owned by `etorrent_table`) so the test node can
read them via `rpc:call` + `ct:pal`. The alternative is relying on
`error_logger:error_msg` from slave nodes.

OTP's `slave` module forwards `error_logger` messages from slave nodes to the
master. It is worth experimenting locally to confirm whether these messages
appear in the `rebar3 ct` stdout captured by CI. If they do, the ETS table is
unnecessary overhead and the terminate callbacks can go back to a plain
`error_logger:error_msg`.

### SASL crash reports to stdout

SASL can print supervisor crash reports and process crash reports to the
terminal if the SASL application is started with `sasl_error_logger` set to
`tty` (or via the `logger` backend in OTP 21+). Experiment locally with
`-kernel logger_level debug` or adding SASL to the test sys.config to confirm
crash reports appear in `rebar3 ct` output without any custom instrumentation.
