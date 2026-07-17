"""Build strict address-based region evidence for the 2026H1 region V2 model.

The tool reads DWD and dimension data. With --write it inserts only new
ADDRESS_PARSE rows into ec_cross_ceshi.dws_region_recovery_map_2026_gj.
It never updates or deletes an existing row or touches an upstream table.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import re
import sys
import tomllib
from collections import defaultdict, deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SECRETS = PROJECT_ROOT / "dashboard" / ".streamlit" / "secrets.toml"
DEFAULT_OUTPUT = PROJECT_ROOT / "dws" / "results" / "region_address_parse_candidates.csv"
PLACEHOLDERS = {"", "-", "--", "null", "n/a", "na", "nan", "none"}


def normalize(value: object) -> str:
    if value is None:
        return ""
    cleaned = re.sub(r"[^0-9a-z\u4e00-\u9fff]+", "", str(value).lower())
    return "" if cleaned in PLACEHOLDERS else cleaned


def database_engine(secrets_path: Path):
    config = tomllib.loads(secrets_path.read_text(encoding="utf-8"))
    values = config.get("database", config)

    def setting(*names: str, default: object = None):
        for name in names:
            if name in values:
                return values[name]
            if name in config:
                return config[name]
        return default

    return create_engine(
        URL.create(
            "mysql+pymysql",
            username=setting("DB_USER", "user"),
            password=setting("DB_PASSWORD", "password"),
            host=setting("DB_HOST", "host", default="127.0.0.1"),
            port=int(setting("DB_PORT", "port", default=3306)),
            database=setting("DB_NAME", "database", default="ec_cross_ceshi"),
            query={"charset": "utf8mb4"},
        ),
        pool_pre_ping=True,
    )


@dataclass
class TrieNode:
    children: dict[str, int] = field(default_factory=dict)
    fail: int = 0
    outputs: list[str] = field(default_factory=list)


class AliasMatcher:
    def __init__(self, patterns: Iterable[str]):
        self.nodes = [TrieNode()]
        for pattern in sorted(set(patterns)):
            node_index = 0
            for character in pattern:
                child = self.nodes[node_index].children.get(character)
                if child is None:
                    child = self._new_node()
                    self.nodes[node_index].children[character] = child
                node_index = child
            self.nodes[node_index].outputs.append(pattern)
        self._build_failure_links()

    def _new_node(self) -> int:
        self.nodes.append(TrieNode())
        return len(self.nodes) - 1

    def _build_failure_links(self) -> None:
        queue: deque[int] = deque()
        for child in self.nodes[0].children.values():
            queue.append(child)
        while queue:
            current = queue.popleft()
            for character, child in self.nodes[current].children.items():
                queue.append(child)
                fallback = self.nodes[current].fail
                while fallback and character not in self.nodes[fallback].children:
                    fallback = self.nodes[fallback].fail
                self.nodes[child].fail = self.nodes[fallback].children.get(character, 0)
                self.nodes[child].outputs.extend(
                    self.nodes[self.nodes[child].fail].outputs
                )

    def find(self, value: str) -> set[str]:
        matches: set[str] = set()
        state = 0
        for character in value:
            while state and character not in self.nodes[state].children:
                state = self.nodes[state].fail
            state = self.nodes[state].children.get(character, 0)
            matches.update(self.nodes[state].outputs)
        return matches


def acceptable_pattern(value: str) -> bool:
    if not value:
        return False
    if re.search(r"[\u4e00-\u9fff]", value):
        return len(value) >= 2
    return len(value) >= 4


def load_dimension_indexes(connection):
    standard_rows = connection.execute(
        text(
            """
            SELECT DISTINCT province_name, province_alias,
                   city_name, city_alias, county_name, county_alias,
                   city_has_counties
            FROM dim_region_standard_2026_gj
            WHERE province_name IS NOT NULL
            """
        )
    ).mappings()

    province_names: dict[str, set[str]] = defaultdict(set)
    city_names: dict[str, set[tuple[str, str, int]]] = defaultdict(set)
    county_names: dict[str, set[tuple[str, str, str]]] = defaultdict(set)
    province_name_lookup: dict[str, set[str]] = defaultdict(set)
    city_name_lookup: dict[str, set[tuple[str, str, int]]] = defaultdict(set)
    county_name_lookup: dict[str, set[tuple[str, str, str]]] = defaultdict(set)

    for row in standard_rows:
        province = row["province_name"]
        city = row["city_name"]
        county = row["county_name"]
        has_counties = int(row["city_has_counties"] or 0)
        for label in {row["province_name"], row["province_alias"]}:
            key = normalize(label)
            if acceptable_pattern(key):
                province_names[key].add(province)
                province_name_lookup[normalize(label)].add(province)
        if city:
            for label in {row["city_name"], row["city_alias"]}:
                key = normalize(label)
                if acceptable_pattern(key):
                    city_names[key].add((province, city, has_counties))
                    city_name_lookup[normalize(label)].add((province, city, has_counties))
        if city and county:
            for label in {row["county_name"], row["county_alias"]}:
                key = normalize(label)
                if acceptable_pattern(key):
                    county_names[key].add((province, city, county))
                    county_name_lookup[normalize(label)].add((province, city, county))

    aliases = connection.execute(
        text("SELECT alias_key, region_name, region_level FROM dim_region_alias")
    ).mappings()
    for row in aliases:
        alias = normalize(row["alias_key"])
        region_name = normalize(row["region_name"])
        if not acceptable_pattern(alias):
            continue
        if row["region_level"] == "province":
            province_names[alias].update(province_name_lookup.get(region_name, set()))
        elif row["region_level"] == "city":
            city_names[alias].update(city_name_lookup.get(region_name, set()))
        elif row["region_level"] == "county":
            county_names[alias].update(county_name_lookup.get(region_name, set()))

    all_patterns = set(province_names) | set(city_names) | set(county_names)
    return province_names, city_names, county_names, AliasMatcher(all_patterns)


def resolve_address(
    address: str,
    province_names: dict[str, set[str]],
    city_names: dict[str, set[tuple[str, str, int]]],
    county_names: dict[str, set[tuple[str, str, str]]],
    matcher: AliasMatcher,
):
    patterns = matcher.find(address)
    matched_provinces = {
        (pattern, province)
        for pattern in patterns
        for province in province_names.get(pattern, set())
    }
    matched_cities = {
        (pattern, province, city, has_counties)
        for pattern in patterns
        for province, city, has_counties in city_names.get(pattern, set())
    }
    matched_counties = {
        (pattern, province, city, county)
        for pattern in patterns
        for province, city, county in county_names.get(pattern, set())
    }

    county_candidates: set[tuple[str, str, str]] = set()
    county_evidence: dict[tuple[str, str, str], set[str]] = defaultdict(set)
    for county_pattern, province, city, county in matched_counties:
        supporting_patterns = {
            pattern
            for pattern, matched_province in matched_provinces
            if matched_province == province and pattern != county_pattern
        }
        supporting_patterns.update(
            pattern
            for pattern, matched_province, matched_city, _ in matched_cities
            if matched_province == province
            and matched_city == city
            and pattern != county_pattern
        )
        if supporting_patterns:
            candidate = (province, city, county)
            county_candidates.add(candidate)
            county_evidence[candidate].update({county_pattern, *supporting_patterns})

    if len(county_candidates) == 1:
        province, city, county = next(iter(county_candidates))
        return province, city, county, 1, len(county_evidence[(province, city, county)])

    city_candidates: set[tuple[str, str, int]] = set()
    city_evidence: dict[tuple[str, str, int], set[str]] = defaultdict(set)
    for city_pattern, province, city, has_counties in matched_cities:
        supporting_patterns = {
            pattern
            for pattern, matched_province in matched_provinces
            if matched_province == province and pattern != city_pattern
        }
        if supporting_patterns:
            candidate = (province, city, has_counties)
            city_candidates.add(candidate)
            city_evidence[candidate].update({city_pattern, *supporting_patterns})

    if len(city_candidates) == 1:
        province, city, has_counties = next(iter(city_candidates))
        return province, city, None, has_counties, len(city_evidence[(province, city, has_counties)])
    return None


def candidate_addresses(connection):
    return connection.execution_options(stream_results=True).execute(
        text(
            """
            SELECT platform_id, company_address,
                   COUNT(*) AS evidence_rows,
                   MIN(month_id) AS first_month_id,
                   MAX(month_id) AS last_month_id
            FROM dwd_sales_detail_2026_gj
            WHERE month_id BETWEEN 202601 AND 202606
              AND company_address IS NOT NULL
              AND TRIM(company_address) <> ''
              AND UPPER(TRIM(company_address)) NOT IN
                  ('-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
              AND (
                  UPPER(REPLACE(TRIM(country), ' ', '')) IN
                      ('CN', 'CHINA', 'PRC', '中国', '中国大陆')
                  OR (
                      (country IS NULL OR UPPER(TRIM(country)) IN
                          ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE'))
                      AND company_address REGEXP '[一-龥]'
                  )
              )
              AND (
                  province IS NULL OR TRIM(province) = ''
                  OR city IS NULL OR TRIM(city) = ''
                  OR county IS NULL OR TRIM(county) = ''
              )
            GROUP BY platform_id, company_address
            """
        )
    ).mappings()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--secrets", type=Path, default=DEFAULT_SECRETS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    engine = database_engine(args.secrets)
    results: dict[tuple[int, str], dict[str, object]] = {}
    with engine.connect() as connection:
        existing = connection.execute(
            text(
                """
                SELECT COUNT(*)
                FROM dws_region_recovery_map_2026_gj
                WHERE map_type = 'ADDRESS_PARSE'
                """
            )
        ).scalar_one()
        if existing:
            raise RuntimeError(
                "ADDRESS_PARSE rows already exist; refusing to overwrite or delete them."
            )

        province_names, city_names, county_names, matcher = load_dimension_indexes(
            connection
        )
        for row in candidate_addresses(connection):
            address_key = normalize(row["company_address"])
            if not address_key:
                continue
            resolved = resolve_address(
                address_key, province_names, city_names, county_names, matcher
            )
            if not resolved:
                continue
            province, city, county, county_applicable, alias_count = resolved
            key = (int(row["platform_id"]), address_key)
            candidate = results.setdefault(
                key,
                {
                    "platform_id": key[0],
                    "match_key": f"ADDR|{address_key}",
                    "resolved_province": province,
                    "resolved_city": city,
                    "resolved_county": county,
                    "county_applicable": county_applicable,
                    "evidence_rows": 0,
                    "first_month_id": int(row["first_month_id"]),
                    "last_month_id": int(row["last_month_id"]),
                    "matched_alias_count": alias_count,
                },
            )
            same_result = (
                candidate["resolved_province"],
                candidate["resolved_city"],
                candidate["resolved_county"],
            ) == (province, city, county)
            if not same_result:
                candidate["ambiguous"] = True
                continue
            candidate["evidence_rows"] = int(candidate["evidence_rows"]) + int(
                row["evidence_rows"]
            )
            candidate["first_month_id"] = min(
                int(candidate["first_month_id"]), int(row["first_month_id"])
            )
            candidate["last_month_id"] = max(
                int(candidate["last_month_id"]), int(row["last_month_id"])
            )

    accepted = [row for row in results.values() if not row.get("ambiguous")]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "platform_id", "match_key", "resolved_province", "resolved_city",
        "resolved_county", "county_applicable", "evidence_rows",
        "first_month_id", "last_month_id", "matched_alias_count",
    ]
    with args.output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows({name: row.get(name) for name in fieldnames} for row in accepted)

    print(f"Strict address mappings: {len(accepted):,}")
    print(f"Evidence CSV: {args.output}")
    if not args.write:
        print("Dry run only. Pass --write to insert into the new recovery table.")
        return 0

    insert_sql = text(
        """
        INSERT INTO dws_region_recovery_map_2026_gj (
            map_type, platform_id, match_key, match_key_hash,
            resolved_province, resolved_city, resolved_county,
            region_scope, county_applicable, confidence_level,
            evidence_rows, first_month_id, last_month_id
        ) VALUES (
            'ADDRESS_PARSE', :platform_id, :match_key, :match_key_hash,
            :resolved_province, :resolved_city, :resolved_county,
            'DOMESTIC', :county_applicable, 'HIGH',
            :evidence_rows, :first_month_id, :last_month_id
        )
        """
    )
    payload = []
    for row in accepted:
        item = dict(row)
        item["match_key_hash"] = hashlib.sha256(
            str(item["match_key"]).encode("utf-8")
        ).digest()
        payload.append(item)

    with engine.begin() as connection:
        for start in range(0, len(payload), 1000):
            connection.execute(insert_sql, payload[start : start + 1000])
    print(f"Inserted ADDRESS_PARSE mappings: {len(payload):,}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
