#!/usr/bin/env python3
"""3-2-1 modu için Wikidata'dan kulüp ve futbolcu kariyer verisi çeker.

Kullanım (proje kökünden):
    python3 -I tool/three21/fetch_wikidata.py resolve   # clubs.csv -> clubs_resolved.json (QID'ler)
    python3 -I tool/three21/fetch_wikidata.py fetch     # her kulübün kariyer kayıtları -> cache/<code>.json

Yalnızca standart kütüphane kullanır. Wikidata'ya nazik davranır (istekler arası bekleme,
açıklayıcı User-Agent). Ham cevaplar cache/ klasörüne yazılır; tekrar çalıştırınca
önbellekteki kulüpler atlanır (--refresh ile yeniden çekilir).
Veri lisansı: Wikidata CC0.
"""

import csv
import json
import pathlib
import sys
import time
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent
CACHE = ROOT / "cache"
ENDPOINT = "https://query.wikidata.org/sparql"
UA = "FootIQ-321-data/0.1 (https://github.com/gkhngdr/footiq)"

# Çok branşlı kulüplerin "spor kulübü" kaydı: bazı futbolcular futbol şubesi
# yerine buna bağlanmış olabilir. Yalnızca futbolcular alındığı için güvenli.
EXTRA_QIDS = {
    "fb": ["Q19648"],
}


def sparql(query: str, retries: int = 4) -> list[dict]:
    data = urllib.parse.urlencode({"query": query, "format": "json"}).encode()
    for attempt in range(retries):
        req = urllib.request.Request(
            ENDPOINT,
            data=data,
            headers={"User-Agent": UA, "Accept": "application/sparql-results+json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.load(r)["results"]["bindings"]
        except Exception as e:  # 429/503/zaman aşımı: bekle ve tekrar dene
            wait = 10 * (attempt + 1)
            print(f"  ! sorgu hatası ({e}); {wait} sn sonra tekrar", file=sys.stderr)
            time.sleep(wait)
    raise RuntimeError("Wikidata sorgusu başarısız")


def _num(v):
    """Sayı değilse (Wikidata'da "bilinmeyen değer") None."""
    try:
        return int(float(v)) if v else None
    except ValueError:
        return None


def _date(v):
    return v[:10] if v and v[:4].isdigit() else None


def qid(uri: str) -> str:
    return uri.rsplit("/", 1)[-1]


def load_clubs() -> list[dict]:
    with open(ROOT / "clubs.csv", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def resolve() -> None:
    clubs = load_clubs()
    values = " ".join(
        '"%s"@en' % c["enwiki"].replace('"', '\\"') for c in clubs
    )
    q = f"""
    SELECT ?title ?club ?links WHERE {{
      VALUES ?title {{ {values} }}
      ?article schema:name ?title ; schema:isPartOf <https://en.wikipedia.org/> ;
               schema:about ?club .
      ?club wikibase:sitelinks ?links .
    }}"""
    rows = sparql(q)
    by_title = {r["title"]["value"]: (qid(r["club"]["value"]), int(r["links"]["value"])) for r in rows}
    out, missing = [], []
    for c in clubs:
        hit = by_title.get(c["enwiki"])
        if not hit:
            missing.append(c["enwiki"])
            continue
        out.append({**c, "qids": [hit[0], *EXTRA_QIDS.get(c["code"], [])], "sitelinks": hit[1]})
    (ROOT / "clubs_resolved.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"çözümlenen: {len(out)} / {len(clubs)}")
    for m in missing:
        print("  bulunamadı:", m)


STINTS_QUERY = """
SELECT ?p ?nameTr ?nameEn ?birth ?plinks ?club ?start ?end ?apps ?loan
       (GROUP_CONCAT(DISTINCT ?alias; separator="|") AS ?aliases) WHERE {{
  VALUES ?club {{ {clubs} }}
  ?p p:P54 ?st . ?st ps:P54 ?club .
  ?p wdt:P106 wd:Q937857 .
  OPTIONAL {{ ?st pq:P580 ?start }}
  OPTIONAL {{ ?st pq:P582 ?end }}
  OPTIONAL {{ ?st pq:P1350 ?apps }}
  OPTIONAL {{ ?st pq:P1642 ?how . FILTER(?how = wd:Q2914547) BIND(true AS ?loan) }}
  OPTIONAL {{ ?p rdfs:label ?nameTr FILTER(lang(?nameTr) = "tr") }}
  OPTIONAL {{ ?p rdfs:label ?nameEn FILTER(lang(?nameEn) = "en") }}
  OPTIONAL {{ ?p skos:altLabel ?alias FILTER(lang(?alias) IN ("tr", "en")) }}
  OPTIONAL {{ ?p wdt:P569 ?birth }}
  ?p wikibase:sitelinks ?plinks .
}}
GROUP BY ?p ?nameTr ?nameEn ?birth ?plinks ?club ?start ?end ?apps ?loan
"""


def fetch(refresh: bool = False) -> None:
    CACHE.mkdir(exist_ok=True)
    clubs = json.loads((ROOT / "clubs_resolved.json").read_text(encoding="utf-8"))
    for i, c in enumerate(clubs, 1):
        target = CACHE / f"{c['code']}.json"
        if target.exists() and not refresh:
            continue
        ids = " ".join(f"wd:{q}" for q in c["qids"])
        rows = sparql(STINTS_QUERY.format(clubs=ids))
        stints = []
        for r in rows:
            g = lambda k: r.get(k, {}).get("value")
            stints.append({
                "qid": qid(g("p")),
                "name_tr": g("nameTr"),
                "name_en": g("nameEn"),
                "aliases": [a for a in (g("aliases") or "").split("|") if a],
                "birth": _date(g("birth")),
                "sitelinks": int(g("plinks") or 0),
                "start": _date(g("start")),
                "end": _date(g("end")),
                "apps": _num(g("apps")),
                "loan": g("loan") == "true",
            })
        target.write_text(json.dumps(stints, ensure_ascii=False), encoding="utf-8")
        print(f"[{i}/{len(clubs)}] {c['name_tr']}: {len(stints)} kayıt")
        time.sleep(1.5)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "resolve":
        resolve()
    elif cmd == "fetch":
        fetch(refresh="--refresh" in sys.argv)
    else:
        print(__doc__)
