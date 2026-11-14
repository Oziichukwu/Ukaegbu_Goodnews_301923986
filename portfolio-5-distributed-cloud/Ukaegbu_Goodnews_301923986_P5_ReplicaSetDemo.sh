#!/usr/bin/env bash
# Portfolio 5: live demonstration of a three-member MongoDB replica set on one computer.
#
# It starts three mongod processes (ports 27101-27103) as replica set "rs0", then:
#   1. shows the members and which one is primary
#   2. writes payment_event documents with majority write concern and reads them on every member
#   3. shows replication lag
#   4. crashes the primary (kill -9) and measures how long the election takes
#   5. writes again on the new primary while one member is down
#   6. restarts the crashed member and checks that it catches up
#   7. stops two members so no majority remains, and shows that writes are refused
#   8. restarts them, checks a primary is elected again and every member has the same data
#
# All three members run on ONE machine, so this shows replication and elections working;
# it is not real high availability (that needs separate machines in separate zones).
#
# Requirements: mongod and mongosh on PATH (or set MONGOD / MONGOSH). Uses a temporary
# data directory that is deleted at the end.
set -euo pipefail
export TZ=UTC

MONGOD="${MONGOD:-mongod}"
MONGOSH="${MONGOSH:-mongosh}"
PORTS=(27101 27102 27103)
WORK="$(mktemp -d)"
RS_URI="mongodb://127.0.0.1:27101,127.0.0.1:27102,127.0.0.1:27103/portfolio_replica?replicaSet=rs0"

say() { printf '\n=== %s ===\n' "$1"; }
now_ms() { date +%s%3N; }
member_sh() { "$MONGOSH" "mongodb://127.0.0.1:$1/?directConnection=true" --quiet --eval "$2"; }
rs_sh() { "$MONGOSH" "$RS_URI" --quiet --eval "$1"; }

start_member() {
  local port="$1"
  mkdir -p "$WORK/$port"
  "$MONGOD" --replSet rs0 --port "$port" --bind_ip 127.0.0.1 --dbpath "$WORK/$port" \
            --logpath "$WORK/$port.log" --pidfilepath "$WORK/$port.pid" --fork > /dev/null
}
stop_member() {   # clean shutdown
  member_sh "$1" 'try { db.getSiblingDB("admin").shutdownServer({ force: true }) } catch (e) {}' > /dev/null 2>&1 || true
  while kill -0 "$(cat "$WORK/$1.pid")" 2> /dev/null; do sleep 0.2; done
}
cleanup() {
  for port in "${PORTS[@]}"; do
    [[ -f "$WORK/$port.pid" ]] && kill "$(cat "$WORK/$port.pid")" 2> /dev/null || true
  done
  sleep 1
  rm -rf "$WORK"
}
trap cleanup EXIT

# Prints one line per member: host, state and health, seen from the given member.
STATUS_JS='rs.status().members.forEach(m => print("  " + m.name + "  " + m.stateStr.padEnd(10) + "  health=" + m.health + (m.self ? "  (answering)" : "")))'

echo "# Portfolio 5 - three-member replica set demonstration"
echo "# Generated on $(date -u '+%Y-%m-%d %H:%M:%S UTC'); mongod $("$MONGOD" --version | head -1 | sed 's/db version //')"

say "Start three mongod processes as replica set rs0"
for port in "${PORTS[@]}"; do start_member "$port"; echo "  started member on port $port"; done
member_sh 27101 'print("  rs.initiate ok=" + rs.initiate({ _id: "rs0", members: [
  { _id: 0, host: "127.0.0.1:27101" }, { _id: 1, host: "127.0.0.1:27102" }, { _id: 2, host: "127.0.0.1:27103" } ] }).ok)'
member_sh 27101 'while (!db.hello().primary) { sleep(250) } print("  primary elected: " + db.hello().primary)'

say "1. Members and states"
member_sh 27101 "$STATUS_JS"

say "2. Majority writes, then read the documents on every member"
rs_sh '
const events = db.getCollection("payment_event");
const docs = [3001, 3003, 3004].map((id, i) => ({ _id: "rs_event_" + (i + 1), eventType: "payment_requested",
  occurredAt: new Date(Date.UTC(2025, 3, 2 + i, 10)), source: { entity: "payment", key: { payment_id: id } } }));
const result = events.insertMany(docs, { writeConcern: { w: "majority", wtimeout: 5000 } });
print("  insertMany acknowledged=" + result.acknowledged + ", inserted=" + Object.keys(result.insertedIds).length + ", writeConcern w=majority");'
for port in "${PORTS[@]}"; do
  member_sh "$port" 'db.getMongo().setReadPref("nearest"); const h = db.hello();
    print("  " + h.me + "  " + (h.isWritablePrimary ? "PRIMARY  " : "SECONDARY") + "  documents=" +
      db.getSiblingDB("portfolio_replica").payment_event.countDocuments())'
done

say "3. Replication lag seen by the primary"
rs_sh 'rs.printSecondaryReplicationInfo()' | sed 's/^/  /'

say "4. Crash the primary (kill -9) and measure the election"
OLD_PRIMARY_PORT="$(rs_sh 'print(db.hello().primary.split(":")[1])')"
SURVIVOR_PORT=27101; [[ "$OLD_PRIMARY_PORT" == 27101 ]] && SURVIVOR_PORT=27102
OLD_TERM="$(member_sh "$SURVIVOR_PORT" 'print(Number(rs.status().term))')"
echo "  primary before the crash: 127.0.0.1:$OLD_PRIMARY_PORT (term $OLD_TERM)"
KILLED_AT="$(now_ms)"
kill -9 "$(cat "$WORK/$OLD_PRIMARY_PORT.pid")"
echo "  killed the primary process at t=0 ms"
member_sh "$SURVIVOR_PORT" "
const killedAt = $KILLED_AT;
let h = db.hello();
while (!h.primary || h.primary.endsWith(':$OLD_PRIMARY_PORT')) { sleep(100); h = db.hello(); }
print('  new primary: ' + h.primary + ' detected after ' + (Date.now() - killedAt) + ' ms');"
NEW_PRIMARY_PORT="$(member_sh "$SURVIVOR_PORT" 'print(db.hello().primary.split(":")[1])')"
member_sh "$NEW_PRIMARY_PORT" '
const s = rs.status(); const m = s.electionCandidateMetrics || {};
print("  term now " + Number(s.term) + ", election reason: " + m.lastElectionReason);
print("  heartbeat election timeout setting: " + rs.conf().settings.electionTimeoutMillis + " ms");'
member_sh "$NEW_PRIMARY_PORT" "$STATUS_JS"

say "5. Write on the new primary while one member is down (2 of 3 = majority)"
rs_sh '
const r = db.payment_event.insertOne({ _id: "rs_event_4", eventType: "payment_settled", occurredAt: new Date(Date.UTC(2025, 3, 2, 16, 30)),
  source: { entity: "payment", key: { payment_id: 3001 } } }, { writeConcern: { w: "majority", wtimeout: 5000 } });
print("  insertOne acknowledged=" + r.acknowledged + " with w=majority; documents now " + db.payment_event.countDocuments());'

say "6. Restart the crashed member and check it catches up"
start_member "$OLD_PRIMARY_PORT"
member_sh "$OLD_PRIMARY_PORT" '
let h = db.hello(); while (!h.secondary) { sleep(250); h = db.hello(); }
db.getMongo().setReadPref("nearest");
const coll = db.getSiblingDB("portfolio_replica").payment_event;
while (coll.countDocuments() < 4) { sleep(250); }
print("  " + h.me + " rejoined as SECONDARY with documents=" + coll.countDocuments());'

say "7. Stop two members so no majority is left"
CURRENT_PRIMARY_PORT="$(rs_sh 'print(db.hello().primary.split(":")[1])')"
LAST_PORT=""
for port in "${PORTS[@]}"; do
  if [[ "$port" != "$CURRENT_PRIMARY_PORT" && -z "$LAST_PORT" ]]; then LAST_PORT="$port"; fi
done
for port in "${PORTS[@]}"; do
  if [[ "$port" != "$LAST_PORT" ]]; then stop_member "$port"; echo "  stopped member on port $port"; fi
done
echo "  only 127.0.0.1:$LAST_PORT is still running (1 of 3 votes)"
member_sh "$LAST_PORT" '
sleep(12000);   // longer than the 10 s election timeout
const h = db.hello();
print("  after 12 s: isWritablePrimary=" + h.isWritablePrimary + ", primary known=" + (h.primary || "none"));
try {
  db.getSiblingDB("portfolio_replica").payment_event.insertOne({ _id: "rs_event_5", eventType: "payment_requested", occurredAt: new Date() });
  print("  write ACCEPTED (unexpected)");
} catch (e) { print("  write refused: code " + e.code + " (" + (e.codeName || "NotWritablePrimary") + ")"); }'
member_sh "$LAST_PORT" "$STATUS_JS"

say "8. Restart the stopped members; a primary is elected and all members agree"
for port in "${PORTS[@]}"; do
  if [[ "$port" != "$LAST_PORT" ]]; then start_member "$port"; fi
done
member_sh "$LAST_PORT" 'let h = db.hello(); while (!h.primary) { sleep(250); h = db.hello(); } print("  primary elected: " + h.primary);'
for port in "${PORTS[@]}"; do
  member_sh "$port" '
  let h = db.hello(); while (!h.isWritablePrimary && !h.secondary) { sleep(250); h = db.hello(); }
  db.getMongo().setReadPref("nearest");
  const coll = db.getSiblingDB("portfolio_replica").payment_event;
  print("  " + h.me + "  " + (h.isWritablePrimary ? "PRIMARY  " : "SECONDARY") + "  documents=" + coll.countDocuments() +
    "  ids=" + coll.find({}, { _id: 1 }).sort({ _id: 1 }).toArray().map(d => d._id).join(","))'
done

say "Shut down and remove the temporary data"
for port in "${PORTS[@]}"; do stop_member "$port"; done
echo "  done"
