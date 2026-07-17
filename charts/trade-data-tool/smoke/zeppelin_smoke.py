#!/usr/bin/env python3
"""Smoke test: the developers' real Asycuda rule notebooks, adapted to the
single-database schema, must execute through Zeppelin's jdbc interpreter
against this release's database and produce their intended effects.

Everything goes through Zeppelin's REST API — the same front door RuleService
and CoreService use (per-paragraph synchronous runs with dynamic-form params,
mirroring ExecuteRule). No kubectl, no direct DB connection.

Env: ZEPPELIN_API_URL, ZEPPELIN_USER, ZEPPELIN_PASSWORD,
     NOTEBOOK_DIR (dir containing asycuda-*.json)
"""
import json, os, sys, time, urllib.request, urllib.parse, http.cookiejar

API = os.environ["ZEPPELIN_API_URL"].rstrip("/")
BATCH = 424242  # improbable batch id; everything created/asserted/removed under it

cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

def call(method, path, data=None, form=False, timeout=120):
    body, headers = None, {}
    if data is not None:
        if form:
            body = urllib.parse.urlencode(data).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        else:
            body = json.dumps(data).encode()
            headers["Content-Type"] = "application/json"
    req = urllib.request.Request(API + path, data=body, headers=headers, method=method)
    with opener.open(req, timeout=timeout) as r:
        return json.loads(r.read() or b"{}")

def login():
    for attempt in range(30):
        try:
            call("POST", "/api/login", {"userName": os.environ["ZEPPELIN_USER"],
                                        "password": os.environ["ZEPPELIN_PASSWORD"]}, form=True)
            return
        except Exception as e:
            print(f"waiting for zeppelin ({e}); {attempt+1}/30", flush=True)
            time.sleep(10)
    sys.exit("FAIL: zeppelin unreachable / login rejected")

def create_note(name, paragraphs):
    # The developers' notebooks rely on the note-level defaultInterpreterGroup
    # (jdbc); API-created notes don't reliably inherit one, so pin each
    # paragraph explicitly.
    paras = [{**p, "text": p["text"] if p["text"].lstrip().startswith("%")
              else "%jdbc\n" + p["text"]} for p in paragraphs]
    return call("POST", "/api/notebook", {"name": name, "paragraphs": paras})["body"]

def delete_note(note_id):
    try: call("DELETE", f"/api/notebook/{note_id}")
    except Exception as e: print(f"cleanup: could not delete note {note_id}: {e}")

def run_note(note_id, params=None):
    """Run every paragraph synchronously in order (TDT's ExecuteRule shape);
    return list of (title, status, first_output)."""
    note = call("GET", f"/api/notebook/{note_id}")["body"]
    out = []
    for p in note["paragraphs"]:
        pid = p["id"]
        body = {"params": params} if params else None
        call("POST", f"/api/notebook/run/{note_id}/{pid}", body, timeout=300)
        got = call("GET", f"/api/notebook/{note_id}/paragraph/{pid}")["body"]
        msgs = (got.get("results") or {}).get("msg") or []
        out.append((p.get("title") or pid, got.get("status"),
                    msgs[0].get("data", "").strip() if msgs else ""))
    return out

def table_value(output):
    """Zeppelin %jdbc SELECT output is TSV with a header line."""
    lines = [l for l in output.splitlines() if l.strip()]
    return lines[1].split("\t") if len(lines) > 1 else []

FIXTURE = [
  {"title": "create brz.asycuda", "text": "%jdbc\nCREATE TABLE IF NOT EXISTS `brz.asycuda` (\n"
    "  RECORD_ID INT AUTO_INCREMENT PRIMARY KEY, BatchId INT, SourceType INT,\n"
    "  AGENCE VARCHAR(32), DECLARANT VARCHAR(32), PRODUCT VARCHAR(32),\n"
    "  SH8 VARCHAR(16), SHEXT VARCHAR(8), TYPDEC VARCHAR(8),\n"
    "  PAYSORIGIN VARCHAR(8), PAYSLDFO VARCHAR(8), PAYSDEST VARCHAR(8), PAYSEXP VARCHAR(8), PARTNER VARCHAR(8),\n"
    "  RATEUSD DECIMAL(18,6), RATEEUR DECIMAL(18,6), VALD DECIMAL(18,4), VALUSD DECIMAL(18,4), VALEURO DECIMAL(18,4),\n"
    "  FOB DECIMAL(18,4), FRET DECIMAL(18,4), ASSURANCE DECIMAL(18,4), AUTRECHARG DECIMAL(18,4),\n"
    "  TAXE1 VARCHAR(8), TAXE2 VARCHAR(8), TAXE3 VARCHAR(8), TAXE4 VARCHAR(8), TAXE5 VARCHAR(8), TAXE6 VARCHAR(8), TAXE7 VARCHAR(8),\n"
    "  VALTAX1 DECIMAL(18,4), VALTAX2 DECIMAL(18,4), VALTAX3 DECIMAL(18,4), VALTAX4 DECIMAL(18,4),\n"
    "  VALTAX5 DECIMAL(18,4), VALTAX6 DECIMAL(18,4), VALTAX7 DECIMAL(18,4),\n"
    "  DDI_VALTAX1 DECIMAL(18,4), DDE_VALTAX2 DECIMAL(18,4), TVA_VALTAX3 DECIMAL(18,4), DCI_VALTAX4 DECIMAL(18,4),\n"
    "  DAS_VALTAX5 DECIMAL(18,4), RIN_VALTAX6 DECIMAL(18,4), FSR_VALTAX7 DECIMAL(18,4), OTH_TAXES DECIMAL(18,4)\n)"},
  {"title": "create DECLARANT", "text": "%jdbc\nCREATE TABLE IF NOT EXISTS `DECLARANT` (CODE VARCHAR(32) PRIMARY KEY, NAME VARCHAR(64))"},
  {"title": "create HS10", "text": "%jdbc\nCREATE TABLE IF NOT EXISTS `HS10` (CODE VARCHAR(16) PRIMARY KEY, NAME VARCHAR(128))"},
  {"title": "seed", "text": "%jdbc\nDELETE FROM `brz.asycuda` WHERE BatchId=" + str(BATCH) + ";\n"
    "DELETE FROM `prc.customError` WHERE BatchId=" + str(BATCH) + ";\n"
    "INSERT IGNORE INTO `DECLARANT` (CODE, NAME) VALUES ('AG1','Known Agency');\n"
    "INSERT IGNORE INTO `HS10` (CODE, NAME) VALUES ('0101210000','Live horses');\n"
    # row 1: known declarant, import, CIF adds up -> enriched, no error
    "INSERT INTO `brz.asycuda` (BatchId, SourceType, AGENCE, SH8, SHEXT, TYPDEC, PAYSORIGIN, RATEUSD, FOB, FRET, ASSURANCE, AUTRECHARG, VALD, TAXE1, VALTAX1)\n"
    "VALUES (" + str(BATCH) + ", 0, 'AG1', '01012100', '00', 'IM4', 'FR', 2.0, 100, 10, 5, 5, 120, 'DDI', 7.5);\n"
    # row 2: unknown declarant, export, CIF does NOT add up -> validation error
    "INSERT INTO `brz.asycuda` (BatchId, SourceType, AGENCE, SH8, SHEXT, TYPDEC, PAYSDEST, RATEUSD, FOB, FRET, ASSURANCE, AUTRECHARG, VALD)\n"
    "VALUES (" + str(BATCH) + ", 0, 'NOPE', '02023300', '10', 'EX1', 'DE', 2.0, 100, 0, 0, 0, 999)"},
]

ASSERTS = [
  {"title": "assert enrichment", "text": "%jdbc\n"
    "SELECT SUM(SourceType) AS src, \n"
    "       SUM(CASE WHEN DECLARANT='AG1' THEN 1 ELSE 0 END) AS known_decl,\n"
    "       SUM(CASE WHEN DECLARANT='UNKNOWN' THEN 1 ELSE 0 END) AS unknown_decl,\n"
    "       SUM(CASE WHEN PRODUCT IS NOT NULL THEN 1 ELSE 0 END) AS with_product,\n"
    "       SUM(CASE WHEN PARTNER IS NOT NULL THEN 1 ELSE 0 END) AS with_partner\n"
    "FROM `brz.asycuda` WHERE BatchId=" + str(BATCH)},
  {"title": "assert validation errors", "text": "%jdbc\n"
    "SELECT COUNT(*) AS errors FROM `prc.customError` WHERE BatchId=" + str(BATCH)},
]

CLEANUP = [
  {"title": "cleanup", "text": "%jdbc\n"
    "DELETE FROM `brz.asycuda` WHERE BatchId=" + str(BATCH) + ";\n"
    "DELETE FROM `prc.customError` WHERE BatchId=" + str(BATCH) + ";\n"
    "DELETE FROM `DECLARANT` WHERE CODE='AG1';\n"
    "DELETE FROM `HS10` WHERE CODE='0101210000'"},
]

def main():
    nb_dir = os.environ.get("NOTEBOOK_DIR", os.path.dirname(os.path.abspath(__file__)))
    treatment = json.load(open(os.path.join(nb_dir, "asycuda-file-treatment.json")))
    validation = json.load(open(os.path.join(nb_dir, "asycuda-validation.json")))
    # the validation notebook's second paragraph is a display-only SELECT the
    # developers used for eyeballing; the INSERT paragraph is the rule
    validation["paragraphs"] = validation["paragraphs"][:1]

    login()
    failures, notes = [], []
    try:
        for name, paras, params in [
            ("tdt-smoke/00-fixture", FIXTURE, None),
            ("tdt-smoke/01-" + treatment["name"].split("/")[-1], treatment["paragraphs"], {"BatchId": str(BATCH)}),
            ("tdt-smoke/02-" + validation["name"].split("/")[-1], validation["paragraphs"], {"BatchId": str(BATCH)}),
        ]:
            nid = create_note(name, paras)
            notes.append(nid)
            print(f"== running {name} ({len(paras)} paragraphs)")
            for title, status, out in run_note(nid, params):
                ok = status == "FINISHED"
                print(f"  [{'ok' if ok else 'FAIL'}] {title}: {status}" + ("" if ok else f" | {out[:200]}"))
                if not ok:
                    failures.append(f"{name}/{title}: {status}")

        nid = create_note("tdt-smoke/03-asserts", ASSERTS)
        notes.append(nid)
        results = run_note(nid)
        src, known, unknown, with_product, with_partner = table_value(results[0][2])
        errors = table_value(results[1][2])[0]
        checks = [
            ("both rows enriched (SourceType)", src == "2"),
            ("known declarant resolved", known == "1"),
            ("unknown declarant flagged UNKNOWN", unknown == "1"),
            ("product codes built", with_product == "2"),
            ("trade partners resolved", with_partner == "2"),
            ("exactly the bad row raised a CIF/FOB error", errors == "1"),
        ]
        for desc, ok in checks:
            print(f"  [{'ok' if ok else 'FAIL'}] {desc}")
            if not ok:
                failures.append(desc)
    finally:
        nid = create_note("tdt-smoke/99-cleanup", CLEANUP)
        notes.append(nid)
        run_note(nid)
        for n in notes:
            delete_note(n)

    if failures:
        print("\nSMOKE TEST FAILED:\n  " + "\n  ".join(failures))
        sys.exit(1)
    print("\nSMOKE TEST PASSED: the Asycuda rule notebooks run end-to-end "
          "through Zeppelin against this release's database.")

if __name__ == "__main__":
    main()
