#!/usr/bin/env python3
"""Generate the bundled fallback stock list (MyTaiwanStock/Resources/StockList.json).

Sources (official open data, no key needed):
  - TWSE   https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL            (Code, Name)
  - TPEx   https://www.tpex.org.tw/openapi/v1/tpex_mainboard_daily_close_quotes   (SecuritiesCompanyCode, CompanyName)

The OTC filter below must stay identical to StockListParser.parseOTC in the app.
"""
import json
import sys
import urllib.request
from pathlib import Path

TWSE_URL = "https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL"
TPEX_URL = "https://www.tpex.org.tw/openapi/v1/tpex_mainboard_daily_close_quotes"
OUTPUT = Path(__file__).resolve().parent.parent / "MyTaiwanStock" / "Resources" / "StockList.json"


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def keep_otc(code):
    # Warrants are 6-character codes starting with 70-73; keep stocks (<= 5 chars) and ETFs (start with 00).
    return len(code) <= 5 or code.startswith("00")


def main():
    entries = {}
    for item in fetch(TWSE_URL):
        code, name = item["Code"].strip(), item["Name"].strip()
        if code and name:
            entries[code] = {"code": code, "name": name, "market": "tse"}
    for item in fetch(TPEX_URL):
        code, name = item["SecuritiesCompanyCode"].strip(), item["CompanyName"].strip()
        if code and name and keep_otc(code) and code not in entries:
            entries[code] = {"code": code, "name": name, "market": "otc"}

    ordered = sorted(entries.values(), key=lambda entry: entry["code"])
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps({"entries": ordered}, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
    )
    tse = sum(1 for e in ordered if e["market"] == "tse")
    print(f"wrote {OUTPUT}: tse={tse} otc={len(ordered) - tse}")


if __name__ == "__main__":
    sys.exit(main())
