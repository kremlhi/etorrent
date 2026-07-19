#!/bin/sh
# Run the test battery under cover and enforce a minimum total line
# coverage over etorrent_core.
#
#   - Common Test runs through ct_run with CT-native cover: rebar3's
#     'ct --cover' only instruments the local CT node, but nearly all
#     etorrent code executes on the suite's slave nodes. The cover spec
#     (test/etorrent.cover) plus ct_cover:add_nodes/1 in etorrent_SUITE
#     counts those too. The coverage gate applies to this data.
#   - EUnit runs inside the etorrent_core checkout ('rebar3 eunit' does
#     not pick up checkout apps from the umbrella). Its coverage is
#     reported for information but not merged into the gate: the eunit
#     beams are compiled with -DTEST, which changes the measurable line
#     set, and merging differently compiled instrumentations distorts
#     the percentage.
#
# Usage: ./cover.sh [min_percent]   (default 80)
set -e
MIN=${1:-80}
if [ ! -d _checkouts/etorrent_core ]; then
    echo "error: cover needs etorrent_core as a checkout dependency:" >&2
    echo "  ln -s /path/to/etorrent_core _checkouts/etorrent_core" >&2
    exit 2
fi
rebar3 as test compile
epmd -daemon || true
rm -rf _build/test/cover
# ct_run does not create its log directory and fails with enoent on a
# fresh workspace if it is missing.
mkdir -p _build/test/cover _build/test/logs

ct_run -dir "$PWD/test" -suite etorrent_SUITE \
    -config etorrent_test.cfg \
    -cover test/etorrent.cover \
    -logdir _build/test/logs \
    -erl_args -noinput -sname ct_cover \
    -pa "$PWD"/_build/test/lib/*/ebin "$PWD"/_build/test/checkouts/*/ebin
cp "$(ls -t _build/test/logs/ct_run.*/all.coverdata | head -1)" \
    _build/test/cover/ct.coverdata

(cd _checkouts/etorrent_core && rebar3 eunit --cover)
cp _checkouts/etorrent_core/_build/test/cover/eunit.coverdata _build/test/cover/
echo ""
echo "EUnit coverage (informational):"
./cover_gate 0 _build/test/cover/eunit.coverdata | tail -1

echo ""
echo "Common Test coverage (gated):"
exec ./cover_gate "$MIN" _build/test/cover/ct.coverdata
