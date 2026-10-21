#!/usr/bin/env bash
# Read-only SSH audit: accepted/failed logins, failed-login table, and the 192.168.1.13 session.
# Run: sudo ./audit-ssh.sh   -> writes audit-ssh.log next to this script.
set -u
LOG="$(cd "$(dirname "$0")" && pwd)/audit-ssh.log"
exec > >(tee "$LOG") 2>&1

echo "== audit-ssh $(date -Is) on $(hostname) =="

echo; echo "== 1. sshd Accepted/Failed/Invalid (last 3 days) =="
journalctl _COMM=sshd --since "3 days ago" --no-pager | grep -E 'Accepted|Failed|Invalid' || echo "(none)"

echo; echo "== 2. lastb -n 30 (failed logins) =="
lastb -n 30 -F || echo "(lastb failed)"

echo; echo "== 3. sessions from 192.168.1.13 =="
who -u | grep 192.168.1.13 || echo "(no who entry)"
ps -eo pid,user,lstart,cmd | grep -E 'sshd:' | grep -v grep || true
ss -tnp 2>/dev/null | grep 192.168.1.13 || echo "(no live TCP from 192.168.1.13)"

echo; echo "== done; log: $LOG =="
if [ -n "${SUDO_USER:-}" ]; then chown "$SUDO_USER" "$LOG"; fi
