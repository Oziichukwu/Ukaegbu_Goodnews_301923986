#!/usr/bin/env python3
"""Replay a two-session PostgreSQL exercise exactly as written in two SQL files.

The Session A and Session B files are divided into numbered steps by comments like
"-- 3. Session A: ...". This driver opens two real database connections and runs the
steps in number order, each on its own session, in autocommit mode so that the
BEGIN / COMMIT / ROLLBACK statements in the files control the transactions just as
they would in two psql terminals.

If a step does not finish within --wait seconds (for example a SELECT ... FOR UPDATE
waiting for the other session's row lock), the driver records that it is blocked,
reads its wait event from pg_stat_activity, and carries on with the next step. The
blocked step finishes in the background once the lock is released.

Usage:
    python3 tools/two_session_driver.py --dbname mit_portfolio SessionA.sql SessionB.sql
Connection settings come from the standard PG* environment variables.
Requires psycopg2 (pip install -r requirements.txt).
"""
import argparse
import datetime
import json
import re
import sys
import threading
import time

import psycopg2

STEP_RE = re.compile(r"^-- (\d+)\. (?:Session [AB]: )?(.*)$")


def parse_steps(path, session):
    """Return {step_number: (description, [statements])} for one session file."""
    steps, current = {}, None
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            match = STEP_RE.match(line.rstrip())
            if match:
                current = int(match.group(1))
                steps[current] = [match.group(2), []]
                continue
            if current is None:
                continue
            if line.strip().startswith("--"):
                # Comment lines directly under the step heading continue its description.
                if not steps[current][1]:
                    steps[current][0] += " " + line.strip().lstrip("-").strip()
                continue
            steps[current][1].append(line.rstrip("\n"))
    parsed = {}
    for number, (description, lines) in steps.items():
        sql = "\n".join(lines)
        statements = [s.strip() for s in re.split(r";\s*(?:\n|$)", sql) if s.strip()]
        parsed[number] = (description, statements, session)
    return parsed


def format_rows(cursor):
    names = [d.name for d in cursor.description]
    def show(value):
        if value is None:
            return "NULL"
        if isinstance(value, (dict, list)):
            return json.dumps(value)
        return str(value)

    rows = [[show(v) for v in row] for row in cursor.fetchall()]
    widths = [max(len(n), *(len(r[i]) for r in rows)) if rows else len(n) for i, n in enumerate(names)]
    out = [" | ".join(n.ljust(w) for n, w in zip(names, widths)),
           "-+-".join("-" * w for w in widths)]
    out += [" | ".join(v.ljust(w) for v, w in zip(r, widths)) for r in rows]
    out.append(f"({len(rows)} row{'s' if len(rows) != 1 else ''})")
    return out


class Session:
    def __init__(self, name, dsn_kwargs, log):
        self.name = name
        self.conn = psycopg2.connect(**dsn_kwargs)
        self.conn.autocommit = True
        self.pid = self.conn.get_backend_pid()
        self.log = log
        self.thread = None

    def run_step(self, number, description, statements):
        lines = []
        for sql in statements:
            lines.append(f"[{self.name}] {sql};")
            cursor = self.conn.cursor()
            try:
                cursor.execute(sql)
                if cursor.description:
                    lines += [f"[{self.name}]   {r}" for r in format_rows(cursor)]
                else:
                    lines.append(f"[{self.name}]   {cursor.statusmessage}")
            except psycopg2.Error as error:
                message = (error.pgerror or str(error)).strip().splitlines()[0]
                lines.append(f"[{self.name}]   {message.replace('ERROR:  ', 'ERROR ' + str(error.pgcode) + ': ')}")
        self.log(f"step {number} finished ({self.name})", lines)

    def start(self, number, description, statements):
        self.thread = threading.Thread(target=self.run_step, args=(number, description, statements))
        self.thread.start()

    def wait_done(self):
        if self.thread is not None:
            self.thread.join()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("session_a")
    parser.add_argument("session_b")
    parser.add_argument("--dbname", required=True)
    parser.add_argument("--title", default="Two-session exercise")
    parser.add_argument("--wait", type=float, default=1.5, help="seconds before a step counts as blocked")
    args = parser.parse_args()

    started = time.monotonic()
    lock = threading.Lock()

    def log(heading, lines=()):
        with lock:
            print(f"+{time.monotonic() - started:6.2f}s  {heading}")
            for line in lines:
                print(f"           {line}")
            sys.stdout.flush()

    steps = {}
    steps.update(parse_steps(args.session_a, "A"))
    for number, value in parse_steps(args.session_b, "B").items():
        if number in steps:
            sys.exit(f"step {number} appears in both files")
        steps[number] = value

    print(f"# {args.title}")
    print(f"# Generated by tools/two_session_driver.py on "
          f"{datetime.datetime.now(datetime.timezone.utc):%Y-%m-%d %H:%M:%S UTC}")
    print(f"# Files: {args.session_a} (Session A), {args.session_b} (Session B)")

    sessions = {name: Session(name, {"dbname": args.dbname}, log) for name in ("A", "B")}
    monitor = psycopg2.connect(dbname=args.dbname)
    monitor.autocommit = True
    with monitor.cursor() as cursor:
        cursor.execute("SELECT version()")
        print(f"# Server: {cursor.fetchone()[0].split(',')[0]}")
    print(f"# Session A backend pid {sessions['A'].pid}, Session B backend pid {sessions['B'].pid}")
    print()

    for number in sorted(steps):
        description, statements, name = steps[number]
        session = sessions[name]
        session.wait_done()  # a session runs its own steps strictly in order
        log(f"step {number} started  (Session {name}): {description}")
        session.start(number, description, statements)
        session.thread.join(args.wait)
        if session.thread.is_alive():
            with monitor.cursor() as cursor:
                cursor.execute(
                    "SELECT wait_event_type, wait_event, pg_blocking_pids(pid) "
                    "FROM pg_stat_activity WHERE pid = %s", (session.pid,))
                wait_type, wait_event, blockers = cursor.fetchone()
            other = [n for n, s in sessions.items() if s.pid in (blockers or [])]
            log(f"step {number} is BLOCKED after {args.wait:.1f}s (Session {name}): "
                f"wait_event_type={wait_type}, wait_event={wait_event}, "
                f"blocked by Session {', '.join(other) or blockers}")

    for session in sessions.values():
        session.wait_done()
        session.conn.close()
    monitor.close()
    log("all steps finished")


if __name__ == "__main__":
    main()
