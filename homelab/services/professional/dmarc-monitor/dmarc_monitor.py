#!/usr/bin/env python3
"""Mailbox-driven DMARC report evaluation.

The IMAP mailbox is the alert state store: a mail sitting in the failed or
invalid folder IS an open alert; the operator acknowledges by moving the mail
out of that folder (any mail client, any device). Every cycle this daemon
projects the current folder content to the Alertmanager v2 API and to
Prometheus metrics, so alert state and dashboard can never disagree.

parsedmarc is the single verdict source; this program never interprets report
content itself. A mail the parser cannot turn into an aggregate report is, by
definition, "unparsable" and must be reported (never silently dropped), so a
poison mail can never block the pipeline.
"""

import email.parser
import email.policy
import hashlib
import json
import os
import re
import shutil
import ssl
import subprocess
import sys
import tempfile
import time
import traceback
import urllib.request
from imaplib import IMAP4, IMAP4_SSL
from pathlib import Path

from prometheus_client import Counter, Gauge, start_http_server

MAX_MAIL_BYTES = 20 * 1024 * 1024  # judged invalid without parsing beyond this
MAX_RESULT_BYTES = 10 * 1024 * 1024  # aggregate.json larger than this: invalid
PARSE_TIMEOUT_SECONDS = 60
# Child-only address space cap (KiB, via sh ulimit): a decompression bomb must
# fail inside the parser subprocess (verdict: invalid, mail moved away) instead
# of tripping the unit-wide MemoryMax, which would kill the daemon and retry
# the same mail forever. 400M sits above the legitimate worst case -- a large
# real-world aggregate report inflates to three-digit MB of address space
# after XML-to-dict -- so this cap can only ever kill hostile input, never
# misjudge a fat legitimate report as invalid. The unit's MemoryMax (see
# default.nix) is this value plus daemon footprint plus margin.
PARSE_MEMORY_KIB = 400 * 1024
# Socket timeout for IMAP: a server that accepts the connection and then goes
# silent must fail the cycle instead of hanging the daemon forever.
IMAP_TIMEOUT_SECONDS = 60
MAX_MAILS_PER_RUN = 200
MAX_SINGLE_ALERTS = 50
FAIL_SOURCES_SHOWN = 5


def log(msg):
    print(msg, flush=True)


def safe_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


# --- verdict (single source: parsedmarc) ------------------------------------


def run_parsedmarc(mail_path, workdir):
    """Run parsedmarc on one file; return (aggregate_reports, error_text).

    parsedmarc exits 0 even for unparsable input; the verdict signal is the
    presence and content of aggregate.json in the output directory.
    """
    outdir = Path(tempfile.mkdtemp(dir=workdir))
    cmd = [
        "/bin/sh",
        "-c",
        'ulimit -v %d -t %d; exec "$0" --offline -o "$1" "$2"'
        % (PARSE_MEMORY_KIB, 2 * PARSE_TIMEOUT_SECONDS),
        shutil.which("parsedmarc") or "parsedmarc",
        str(outdir),
        str(mail_path),
    ]
    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            timeout=PARSE_TIMEOUT_SECONDS,
        )
        # stderr may be a multi-line traceback; only its last line is the
        # actual message and short enough for an alert annotation.
        error_lines = [
            line.strip()
            for line in proc.stderr.decode("utf-8", "replace").splitlines()
            if line.strip()
        ]
        error_text = (error_lines[-1] if error_lines else "")[:200]
    except subprocess.TimeoutExpired:
        return [], "parser timeout after %ds" % PARSE_TIMEOUT_SECONDS
    result = outdir / "aggregate.json"
    if not result.is_file():
        return [], error_text or "no aggregate report found"
    if result.stat().st_size > MAX_RESULT_BYTES:
        return [], "parse result exceeds %d bytes" % MAX_RESULT_BYTES
    try:
        reports = json.loads(result.read_text())
    except ValueError:
        return [], "unreadable parser output"
    return (reports if isinstance(reports, list) else []), error_text


def record_compliant(record):
    # alignment.dmarc is parsedmarc's own per-record judgment (aligned DKIM
    # pass or aligned SPF pass); fall back to deriving the same thing from
    # policy_evaluated should the field ever disappear upstream.
    alignment = record.get("alignment")
    if isinstance(alignment, dict) and "dmarc" in alignment:
        return bool(alignment["dmarc"])
    pe = record.get("policy_evaluated")
    pe = pe if isinstance(pe, dict) else {}
    return pe.get("dkim") == "pass" or pe.get("spf") == "pass"


def classify(reports, error_text=""):
    """Turn parsedmarc output for one mail into a verdict summary.

    Total over malformed shapes: it must never raise, otherwise a crafted
    report would crash the cycle and be retried forever instead of being
    judged invalid and moved away.
    """
    reports = [r for r in reports if isinstance(r, dict)]
    if not reports:
        return {"verdict": "invalid", "reason": error_text or "unparsable"}
    per_report = []
    fail_sources = {}
    for report in reports:
        metadata = report.get("report_metadata")
        metadata = metadata if isinstance(metadata, dict) else {}
        published = report.get("policy_published")
        published = published if isinstance(published, dict) else {}
        acc = {
            "reporter": str(metadata.get("org_name") or "unknown"),
            "domain": str(published.get("domain") or "unknown"),
            "total": 0,
            "compliant": 0,
            "quarantine": 0,
            "reject": 0,
        }
        records = report.get("records")
        for record in records if isinstance(records, list) else []:
            if not isinstance(record, dict):
                continue
            count = safe_int(record.get("count"))
            pe = record.get("policy_evaluated")
            pe = pe if isinstance(pe, dict) else {}
            disposition = str(pe.get("disposition") or "none").lower()
            acc["total"] += count
            if disposition in ("quarantine", "reject"):
                acc[disposition] += count
            if record_compliant(record):
                acc["compliant"] += count
            else:
                source = record.get("source")
                source = source if isinstance(source, dict) else {}
                ip = str(source.get("ip_address") or "unknown")
                fail_sources[(ip, disposition)] = (
                    fail_sources.get((ip, disposition), 0) + count
                )
        per_report.append(acc)
    total = sum(r["total"] for r in per_report)
    compliant = sum(r["compliant"] for r in per_report)
    # Fail closed: a structurally present report without a single countable
    # record is no evidence of compliance.
    if total <= 0:
        return {
            "verdict": "invalid",
            "reason": error_text or "report without countable records",
        }
    return {
        "verdict": "compliant" if compliant == total else "noncompliant",
        "reports": per_report,
        "total": total,
        "compliant": compliant,
        "fail_sources": [
            {"ip": ip, "disposition": disposition, "count": count}
            for (ip, disposition), count in sorted(
                fail_sources.items(), key=lambda item: -item[1]
            )
        ],
    }


# --- mail identity ----------------------------------------------------------


def parse_headers(header_bytes):
    return email.parser.BytesParser(policy=email.policy.default).parsebytes(
        header_bytes
    )


def mail_identity(msg, size):
    # Stable across IMAP moves (UIDs are not). Attacker-controlled collisions
    # only merge alerts of mails that are still present, which keeps alerts
    # open longer but can never close one early: posting follows folder
    # content, not this bookkeeping.
    message_id = msg.get("Message-ID")
    parts = (
        [message_id]
        if message_id
        else [msg.get("Date"), msg.get("From"), msg.get("Subject"), str(size)]
    )
    digest = hashlib.sha256("\x00".join(str(p) for p in parts).encode()).hexdigest()
    return digest[:16]


# --- persisted metrics ------------------------------------------------------

COUNTER_SPECS = {
    "dmarc_reports_total": (
        "Parsed DMARC aggregate reports",
        ["reporter", "from_domain"],
    ),
    "dmarc_messages_total": (
        "Messages covered by DMARC reports",
        ["reporter", "from_domain"],
    ),
    "dmarc_messages_compliant_total": (
        "DMARC-compliant messages",
        ["reporter", "from_domain"],
    ),
    "dmarc_messages_noncompliant_total": (
        "Non-compliant messages",
        ["reporter", "from_domain"],
    ),
    "dmarc_messages_quarantine_total": (
        "Messages disposed as quarantine",
        ["reporter", "from_domain"],
    ),
    "dmarc_messages_reject_total": (
        "Messages disposed as reject",
        ["reporter", "from_domain"],
    ),
    "dmarc_invalid_mails_total": ("Mails not parsable as DMARC report", []),
}


def atomic_write_json(path, data):
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(json.dumps(data))
    os.replace(tmp, path)


class Metrics:
    def __init__(self, state_file):
        self.state_file = state_file
        self.counters = {
            name: Counter(name, doc, labels)
            for name, (doc, labels) in COUNTER_SPECS.items()
        }
        self.values = {name: {} for name in COUNTER_SPECS}
        self.open_alerts = Gauge(
            "dmarc_open_alerts", "Mails awaiting acknowledgement", ["folder"]
        )
        self.last_run = Gauge(
            "dmarc_last_successful_run_timestamp_seconds",
            "Completion time of the last successful cycle",
        )
        if state_file.is_file():
            for name, labeled in json.loads(state_file.read_text()).items():
                if name not in self.counters:
                    continue
                for key, value in labeled.items():
                    self._counter(name, json.loads(key)).inc(value)
                    self.values[name][key] = value
        # Gauges are not persisted by prometheus_client, so a restart would
        # show "No data" until the first cycle completes. Initialize from the
        # last persisted counts (0 on a fresh install) for display continuity;
        # the first cycle refreshes them from the mailbox, which stays the
        # truth.
        self.open_file = state_file.with_name("open.json")
        stored_open = (
            json.loads(self.open_file.read_text()) if self.open_file.is_file() else {}
        )
        for role in ("failed", "invalid"):
            self.open_alerts.labels(role).set(stored_open.get(role, 0))

    def _counter(self, name, labelvalues):
        counter = self.counters[name]
        return counter.labels(*labelvalues) if labelvalues else counter

    def inc(self, name, labelvalues, amount):
        if amount <= 0:
            return
        self._counter(name, labelvalues).inc(amount)
        key = json.dumps(labelvalues)
        self.values[name][key] = self.values[name].get(key, 0) + amount

    def account(self, summary):
        if summary["verdict"] == "invalid":
            self.inc("dmarc_invalid_mails_total", [], 1)
            return
        for acc in summary["reports"]:
            labels = [acc["reporter"], acc["domain"]]
            self.inc("dmarc_reports_total", labels, 1)
            self.inc("dmarc_messages_total", labels, acc["total"])
            self.inc("dmarc_messages_compliant_total", labels, acc["compliant"])
            self.inc(
                "dmarc_messages_noncompliant_total",
                labels,
                acc["total"] - acc["compliant"],
            )
            self.inc("dmarc_messages_quarantine_total", labels, acc["quarantine"])
            self.inc("dmarc_messages_reject_total", labels, acc["reject"])

    def set_open(self, counts):
        for role in ("failed", "invalid"):
            self.open_alerts.labels(role).set(counts.get(role, 0))
        atomic_write_json(self.open_file, counts)

    def save(self):
        atomic_write_json(self.state_file, self.values)


# --- imap -------------------------------------------------------------------


class Mailbox:
    def __init__(self, host, port, username, password_file):
        # Explicit context: certificate chain AND hostname are verified against
        # the system CA store. Without it, imaplib's default context has been
        # unverified in several Python versions -- never rely on it.
        self.conn = IMAP4_SSL(
            host,
            port,
            ssl_context=ssl.create_default_context(),
            timeout=IMAP_TIMEOUT_SECONDS,
        )
        # Read at connect time so an agenix rotation applies without restart;
        # the secret is function-local and never logged.
        self.conn.login(username, Path(password_file).read_text().strip())

    def close(self):
        try:
            self.conn.logout()
        except (OSError, IMAP4.error):
            pass

    @staticmethod
    def _quote(folder):
        """Quote a mailbox as an IMAP quoted-string, see RFC 3501 4.3.

        imaplib passes the mailbox through verbatim, so a name with spaces
        would arrive as several arguments, and an embedded quote or backslash
        would end the string early.
        """
        return '"%s"' % folder.replace("\\", "\\\\").replace('"', '\\"')

    @staticmethod
    def _ok(action, result):
        # Every IMAP status is checked: a NO/BAD answered SEARCH read as an
        # empty folder would falsely resolve open alerts downstream.
        status, data = result
        if status != "OK":
            raise RuntimeError("IMAP %s answered %s" % (action, status))
        return data

    def uids(self, folder, readonly):
        self._ok(
            "SELECT %s" % folder,
            self.conn.select(self._quote(folder), readonly=readonly),
        )
        data = self._ok("SEARCH", self.conn.uid("SEARCH", None, "ALL"))
        return data[0].split() if data and data[0] else []

    def fetch_meta(self, uid):
        """Return (size, parsed headers) without downloading the body."""
        data = self._ok(
            "FETCH", self.conn.uid("FETCH", uid, "(RFC822.SIZE BODY.PEEK[HEADER])")
        )
        size, header_bytes = 0, b""
        for item in data or []:
            if isinstance(item, tuple) and len(item) == 2:
                match = re.search(rb"RFC822\.SIZE (\d+)", item[0])
                if match:
                    size = int(match.group(1))
                header_bytes = item[1]
        return size, parse_headers(header_bytes)

    def fetch_full(self, uid):
        data = self._ok("FETCH", self.conn.uid("FETCH", uid, "(BODY.PEEK[])"))
        for item in data or []:
            if isinstance(item, tuple) and len(item) == 2:
                return item[1]
        raise RuntimeError("empty FETCH response for uid %s" % uid)

    def move(self, uid, folder):
        # UID MOVE only, deliberately without a COPY/STORE/EXPUNGE fallback:
        # that emulation is not safely possible (a failed STORE after a
        # successful COPY duplicates the mail on every retry, and plain
        # EXPUNGE purges every \Deleted mail in the folder, not just this
        # UID). Dovecot supports MOVE; on a server without it the cycle fails
        # loudly instead of corrupting the mailbox.
        self._ok("MOVE", self.conn.uid("MOVE", uid, self._quote(folder)))


# --- alertmanager -----------------------------------------------------------


def iso_utc(ts):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(ts))


def post_alerts(url, alerts):
    if not alerts:
        return
    request = urllib.request.Request(
        url.rstrip("/") + "/api/v2/alerts",
        data=json.dumps(alerts).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        if response.status not in (200, 201):
            raise RuntimeError("alertmanager answered %s" % response.status)


def build_alert(ident, folder_role, summary, first_seen, ends_at):
    # The alert name follows the folder the mail sits in, not the cached
    # summary: folder membership is the verdict of record.
    labels = {
        "alertname": "DmarcNonCompliant"
        if folder_role == "failed"
        else "DmarcUnparsableMail",
        "severity": "warning",
        "service": "dmarc",
        "id": ident,
        "folder": folder_role,
    }
    if folder_role == "failed" and summary.get("reports"):
        reports = summary["reports"]
        labels["reporter"] = ", ".join(sorted({r["reporter"] for r in reports}))
        labels["from_domain"] = ", ".join(sorted({r["domain"] for r in reports}))
        failed = summary.get("total", 0) - summary.get("compliant", 0)
        sources = "; ".join(
            "%s (%d, %s)" % (s["ip"], s["count"], s["disposition"])
            for s in summary.get("fail_sources", [])[:FAIL_SOURCES_SHOWN]
        )
        annotations = {
            "summary": "DMARC: %d of %d messages non-compliant"
            % (failed, summary.get("total", 0)),
            "description": "Failing sources: %s. Acknowledge by moving the mail out of the failed folder."
            % (sources or "unknown"),
        }
    else:
        annotations = {
            "summary": "Mail not parsable as DMARC report (from %s, subject %r)"
            % (summary.get("from", "unknown"), summary.get("subject", "")),
            "description": "%s. Raw mail kept for inspection; acknowledge by moving it out of the invalid folder."
            % summary.get("reason", "unparsable"),
        }
    return {
        "labels": labels,
        "annotations": annotations,
        "startsAt": iso_utc(first_seen),
        "endsAt": iso_utc(ends_at),
    }


# --- run cycle --------------------------------------------------------------


class Monitor:
    def __init__(self, cfg):
        self.cfg = cfg
        state_dir = Path(cfg["state_dir"])
        state_dir.mkdir(parents=True, exist_ok=True)
        self.metrics = Metrics(state_dir / "counters.json")
        self.verdicts_file = state_dir / "verdicts.json"
        self.posted_file = state_dir / "posted.json"
        self.verdicts = self._load(self.verdicts_file)
        self.posted = self._load(self.posted_file)

    @staticmethod
    def _load(path):
        return json.loads(path.read_text()) if path.is_file() else {}

    def _summarize_mail(self, raw, workdir):
        with tempfile.NamedTemporaryFile(dir=workdir, suffix=".eml") as tmp:
            tmp.write(raw)
            tmp.flush()
            reports, error_text = run_parsedmarc(tmp.name, workdir)
        return classify(reports, error_text)

    def process_inbox(self, mailbox, workdir):
        cfg = self.cfg
        uids = mailbox.uids(cfg["folder_inbox"], readonly=False)
        if len(uids) > MAX_MAILS_PER_RUN:
            log("inbox holds %d mails, processing %d" % (len(uids), MAX_MAILS_PER_RUN))
            uids = uids[:MAX_MAILS_PER_RUN]
        for uid in uids:
            size, msg = mailbox.fetch_meta(uid)
            ident = mail_identity(msg, size)
            if size > MAX_MAIL_BYTES:
                summary = {
                    "verdict": "invalid",
                    "reason": "mail size %d exceeds limit" % size,
                }
            else:
                raw = mailbox.fetch_full(uid)
                try:
                    summary = self._summarize_mail(raw, workdir)
                except Exception as exc:  # noqa: BLE001 -- a mail must never
                    # crash the cycle; anything unjudgeable is invalid.
                    summary = {
                        "verdict": "invalid",
                        "reason": "monitor error: %.200s" % exc,
                    }
            summary["from"] = str(msg.get("From", "unknown"))
            summary["subject"] = str(msg.get("Subject", ""))
            destination = {
                "compliant": cfg["folder_archive"],
                "noncompliant": cfg["folder_failed"],
                "invalid": cfg["folder_invalid"],
            }[summary["verdict"]]
            # Verdict and metrics are booked only after the move is confirmed:
            # a failed move leaves the mail in the inbox for the next cycle,
            # and accounting first would count it twice then.
            mailbox.move(uid, destination)
            self.metrics.account(summary)
            if summary["verdict"] != "compliant":
                summary["first_seen"] = time.time()
                self.verdicts[ident] = summary
            log("uid %s -> %s (%s)" % (uid.decode(), destination, summary["verdict"]))

    def collect_open(self, mailbox, workdir):
        """Map identity -> (folder role, summary) for every unacknowledged mail."""
        open_mails = {}
        for role, folder in (
            ("failed", self.cfg["folder_failed"]),
            ("invalid", self.cfg["folder_invalid"]),
        ):
            for uid in mailbox.uids(folder, readonly=True):
                size, msg = mailbox.fetch_meta(uid)
                ident = mail_identity(msg, size)
                summary = self.verdicts.get(ident)
                if summary is None:
                    # Cache lost (state reset): rebuild the annotation once by
                    # re-parsing; the verdict of record stays the folder.
                    summary = {"verdict": "invalid", "reason": "unparsable"}
                    if role == "failed" and size <= MAX_MAIL_BYTES:
                        try:
                            summary = self._summarize_mail(
                                mailbox.fetch_full(uid), workdir
                            )
                        except Exception:  # noqa: BLE001
                            pass
                    summary["from"] = str(msg.get("From", "unknown"))
                    summary["subject"] = str(msg.get("Subject", ""))
                    summary["first_seen"] = time.time()
                    self.verdicts[ident] = summary
                open_mails[ident] = (role, summary)
        return open_mails

    def alert_phase(self, open_mails):
        cfg = self.cfg
        now = time.time()
        ends_at = now + 3 * cfg["poll_interval"]
        # Deterministic order so the set of individually-alerted mails is
        # stable across cycles even above the cap (no identity flapping).
        ordered = sorted(
            open_mails.items(), key=lambda kv: (kv[1][1].get("first_seen", now), kv[0])
        )
        alerts = [
            build_alert(ident, role, summary, summary.get("first_seen", now), ends_at)
            for ident, (role, summary) in ordered[:MAX_SINGLE_ALERTS]
        ]
        if len(ordered) > MAX_SINGLE_ALERTS:
            alerts.append(
                {
                    "labels": {
                        "alertname": "DmarcAlertOverflow",
                        "severity": "warning",
                        "service": "dmarc",
                        "id": "overflow",
                    },
                    "annotations": {
                        "summary": "%d mails await acknowledgement, showing first %d"
                        % (len(ordered), MAX_SINGLE_ALERTS)
                    },
                    "startsAt": iso_utc(now),
                    "endsAt": iso_utc(ends_at),
                }
            )
        current = {alert["labels"]["id"]: alert for alert in alerts}
        # Acknowledged mails: resolve immediately instead of waiting for the
        # posted endsAt to expire. RESOLVED is strictly a consequence of the
        # operator's move; a failed resolve post is retried next cycle.
        for ident, previous in self.posted.items():
            if ident not in current:
                alerts.append(dict(previous, endsAt=iso_utc(now)))
        post_alerts(cfg["alertmanager_url"], alerts)
        self.posted = current
        # Pruned against everything open, not against the posting cap: above
        # MAX_SINGLE_ALERTS the uncapped identities must keep their cached
        # verdicts, or every further cycle would re-download and re-parse
        # those mails.
        self.verdicts = {
            ident: summary
            for ident, summary in self.verdicts.items()
            if ident in open_mails
        }

    def persist(self):
        self.metrics.save()
        atomic_write_json(self.verdicts_file, self.verdicts)
        atomic_write_json(self.posted_file, self.posted)

    def run_cycle(self):
        cfg = self.cfg
        mailbox = Mailbox(
            cfg["imap_host"],
            cfg["imap_port"],
            cfg["imap_username"],
            cfg["imap_password_file"],
        )
        # Folders are operator-managed and never created here: the
        # dmarc-mailbox-check unit is the precondition that verifies they
        # exist, so a misconfiguration fails loudly instead of silently
        # growing stray folders in a live mailbox.
        try:
            with tempfile.TemporaryDirectory() as workdir:
                self.process_inbox(mailbox, workdir)
                # Mails are moved now; persist their counter increments before
                # the alert phase can fail, or the dashboard would undercount.
                self.persist()
                open_mails = self.collect_open(mailbox, workdir)
        finally:
            mailbox.close()
        # Gauges reflect the mailbox before anything is posted: dashboard and
        # folder state must agree even while Alertmanager is unreachable.
        self.metrics.set_open(
            {
                role: sum(
                    1 for folder_role, _ in open_mails.values() if folder_role == role
                )
                for role in ("failed", "invalid")
            }
        )
        self.alert_phase(open_mails)
        self.persist()
        self.metrics.last_run.set(time.time())


def config_from_env():
    def need(name):
        value = os.environ.get(name)
        if not value:
            sys.exit("missing environment variable %s" % name)
        return value

    return {
        "imap_host": need("DMARC_IMAP_HOST"),
        "imap_port": int(os.environ.get("DMARC_IMAP_PORT", "993")),
        "imap_username": need("DMARC_IMAP_USERNAME"),
        "imap_password_file": need("DMARC_IMAP_PASSWORD_FILE"),
        "folder_inbox": need("DMARC_FOLDER_INBOX"),
        "folder_archive": need("DMARC_FOLDER_ARCHIVE"),
        "folder_failed": need("DMARC_FOLDER_FAILED"),
        "folder_invalid": need("DMARC_FOLDER_INVALID"),
        "poll_interval": int(os.environ.get("DMARC_POLL_INTERVAL_SECONDS", "1800")),
        "alertmanager_url": need("DMARC_ALERTMANAGER_URL"),
        "metrics_port": int(os.environ.get("DMARC_METRICS_PORT", "9095")),
        "state_dir": need("STATE_DIRECTORY"),
    }


def run_daemon():
    cfg = config_from_env()
    monitor = Monitor(cfg)
    start_http_server(cfg["metrics_port"], addr="127.0.0.1")
    # Counted as a successful run so DmarcMonitorStale measures from process
    # start instead of firing on an absent metric right after boot.
    monitor.metrics.last_run.set(time.time())
    log("dmarc-monitor started, polling every %ds" % cfg["poll_interval"])
    while True:
        started = time.time()
        try:
            monitor.run_cycle()
        except Exception:  # noqa: BLE001 -- transient IMAP/Alertmanager
            # failures: log and retry next cycle; if they persist,
            # DmarcMonitorStale fires.
            log(traceback.format_exc())
        time.sleep(max(1.0, cfg["poll_interval"] - (time.time() - started)))


# --- selftest ---------------------------------------------------------------


def selftest(fixtures_dir):
    """Pin parsedmarc CLI behavior and the verdict mapping.

    Runs in the package checkPhase: an upstream format change breaks the
    deploy build instead of the running production service.
    """
    import email.message
    import gzip

    fixtures = Path(fixtures_dir)
    failures = []
    with tempfile.TemporaryDirectory() as workdir:
        workdir = Path(workdir)

        garbage = workdir / "garbage.txt"
        garbage.write_text("garbage, not a report")

        # The real ingestion path: a mail with a gzipped XML attachment.
        message = email.message.EmailMessage()
        message["From"] = "reporter@selftest.example"
        message["To"] = "dmarc@example.com"
        message["Subject"] = "Report Domain: example.com Submitter: selftest.example"
        message["Date"] = "Mon, 10 Aug 2026 00:00:00 +0000"
        message["Message-ID"] = "<selftest-eml-1@selftest.example>"
        message.set_content("DMARC aggregate report attached")
        message.add_attachment(
            gzip.compress((fixtures / "compliant.xml").read_bytes()),
            maintype="application",
            subtype="gzip",
            filename="selftest.example!example.com!1700000000!1700086400.xml.gz",
        )
        eml = workdir / "compliant.eml"
        eml.write_bytes(bytes(message))

        cases = [
            (fixtures / "compliant.xml", "compliant"),
            (fixtures / "noncompliant.xml", "noncompliant"),
            # parsedmarc rejects reports without a single <record> ("Missing
            # field: 'record'"), so a zero-record report is judged invalid and
            # therefore alerts. Pinned deliberately: if upstream ever starts
            # accepting such reports, this case fails and forces a decision.
            (fixtures / "empty_records.xml", "invalid"),
            (garbage, "invalid"),
            (eml, "compliant"),
        ]
        for path, expected in cases:
            reports, error_text = run_parsedmarc(path, workdir)
            summary = classify(reports, error_text)
            status = "ok" if summary["verdict"] == expected else "FAIL"
            log(
                "%s: %s expected=%s got=%s"
                % (status, path.name, expected, summary["verdict"])
            )
            if summary["verdict"] != expected:
                failures.append(path.name)

        reports, error_text = run_parsedmarc(fixtures / "noncompliant.xml", workdir)
        summary = classify(reports, error_text)
        expectations = [
            summary["total"] == 7,
            summary["compliant"] == 2,
            summary["reports"][0]["reporter"] == "selftest.example",
            summary["reports"][0]["domain"] == "example.com",
            summary["reports"][0]["reject"] == 5,
            summary["fail_sources"][0]["ip"] == "198.51.100.23",
            summary["fail_sources"][0]["count"] == 5,
        ]
        if not all(expectations):
            failures.append("noncompliant summary fields")
            log("FAIL: summary fields %s" % summary)

    if failures:
        sys.exit("selftest failed: %s" % ", ".join(failures))
    log("selftest passed")


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "selftest":
        default_fixtures = Path(__file__).resolve().parent / "fixtures"
        selftest(sys.argv[2] if len(sys.argv) > 2 else default_fixtures)
    elif len(sys.argv) >= 2 and sys.argv[1] == "run":
        run_daemon()
    else:
        sys.exit("usage: dmarc_monitor.py run | selftest [fixtures_dir]")


if __name__ == "__main__":
    main()
