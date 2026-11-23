#!/bin/bash
# Our TGCall against the real tgcalls library through a real Telegram reflector, in both
# roles for each version. No account and no TDLib: signaling runs over localhost.
#   scripts/call_bench.sh [version ...]     default: 5.0.0 2.7.7
# CALL_BENCH_NET="--loss 5 --delay 60 --jitter 40 --rate 400" puts a bad phone network
# between us and the reflector (both ways; percent, ms, ms, kbit/s).
# --switch-at MS --outage MS in CALL_BENCH_NET plays a network change: that long with
# nothing through, then the reflector hears us from a new port.
# CALL_BENCH_P2P=1 lets both sides go peer to peer (the reflector stays as the fallback).
# CALL_BENCH_PCM=file keeps what our playout produced (s16le 48 kHz, plus file.steps);
# CALL_BENCH_ARRIVALS=1 logs each audio packet's arrival.
# CALL_BENCH_VIDEO=1 turns both cameras on (9.0.0 only) and reports the frames each
# side decoded from the other. Both sides of ours play iOS 7.1.2;
# CALL_BENCH_CODEC=vp8 takes VideoToolbox away too.
# Needs tgcalls_cli built with tests/call_bench/tgcalls_cli_bridge.patch. CALL_BENCH_CLI
# overrides its path, CALL_BENCH_REFLECTOR the reflector.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="${CALL_BENCH_CLI:-$HOME/.crew/calls/Telegram-iOS/bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli}"
REFLECTOR="${CALL_BENCH_REFLECTOR:-91.108.13.2:598}"
DURATION="${CALL_BENCH_SECONDS:-12}"
LOGS="$ROOT/build/call_bench"
mkdir -p "$LOGS"
make -C "$ROOT" -f tests/Makefile bench > "$LOGS/build.log" 2>&1 || { tail -20 "$LOGS/build.log"; exit 1; }
BENCH="$ROOT/build/tests/call_bench"
PORT=47100
[ $# -gt 0 ] && VERSIONS="$*" || VERSIONS="5.0.0 2.7.7"
for version in $VERSIONS; do
	for ours in caller callee; do
		[ "$ours" = caller ] && theirs=callee || theirs=caller
		KEY=$(openssl rand -hex 256)
		TAG=$(openssl rand -hex 16)
		PORT=$((PORT + 1))
		NAME="$version-ours-$ours"
		# The reflector tells the two ends of a call apart by the first byte of the tag.
		[ "$ours" = caller ] && OUR_TAG="00${TAG:2}" || OUR_TAG="01${TAG:2}"
		[ "$ours" = caller ] && THEIR_TAG="01${TAG:2}" || THEIR_TAG="00${TAG:2}"
		"$CLI" --mode bridge --version "$version" --reflector "$REFLECTOR" --duration "$((DURATION + 4))" \
			--role "$theirs" --key-hex "$KEY" --tag-hex "$THEIR_TAG" --signal-port "$PORT" \
			--rtc-log "$LOGS/$NAME.rtc.log" ${CALL_BENCH_VIDEO:+--video} ${CALL_BENCH_P2P:+--p2p} \
			> "$LOGS/$NAME.theirs.out" 2> "$LOGS/$NAME.theirs.log" &
		PEER=$!
		"$BENCH" --role "$ours" --version "$version" --reflector "$REFLECTOR" --duration "$DURATION" \
			--key-hex "$KEY" --tag-hex "$OUR_TAG" --signal-port "$PORT" --silent "${CALL_BENCH_SILENT:-0}" --video "${CALL_BENCH_VIDEO:-0}" --codec "${CALL_BENCH_CODEC:-h264}" $CALL_BENCH_NET \
			> "$LOGS/$NAME.ours.out" 2> "$LOGS/$NAME.ours.log"
		# A bench that died leaves the peer waiting for a client that never comes.
		for _ in $(seq 1 $((DURATION + 8))); do kill -0 "$PEER" 2>/dev/null || break; sleep 1; done
		kill "$PEER" 2>/dev/null
		wait "$PEER" 2>/dev/null
		echo "== $version, we are the $ours"
		grep -h 'OURS_RESULT' "$LOGS/$NAME.ours.out" | sed 's/OURS_RESULT/  ours  /'
		grep -h 'BRIDGE_RESULT' "$LOGS/$NAME.theirs.out" | sed 's/BRIDGE_RESULT/  theirs/'
		grep -h 'OURS_VIDEO' "$LOGS/$NAME.ours.out" | sed 's/OURS_VIDEO/  ours  /'
		grep -h 'OURS_PLAYOUT' "$LOGS/$NAME.ours.out" | sed 's/OURS_PLAYOUT_OPUS_PLC/  plc   /; s/OURS_PLAYOUT/  ours  /'
		grep -h 'BRIDGE_PLAYOUT' "$LOGS/$NAME.theirs.out" | sed 's/BRIDGE_PLAYOUT/  theirs/'
		grep -h 'OURS_NET' "$LOGS/$NAME.ours.out" | sed 's/OURS_NET_STATE/  state /; s/OURS_NET/  net   /'
		grep -h 'BRIDGE_VIDEO' "$LOGS/$NAME.theirs.out" | sed 's/BRIDGE_VIDEO/  theirs/'
	done
done
