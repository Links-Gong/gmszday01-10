"""Load the region V2 summary in 24 restartable month-platform batches.

Only the new dws_region_month_summary_v2_2026_gj table is written. Each batch
commits its four region levels together, so a lost connection cannot leave a
partially loaded month-platform result.
"""

from __future__ import annotations

import argparse
import sys
import time
import tomllib
from pathlib import Path

import pymysql


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SECRETS = PROJECT_ROOT / "dashboard" / ".streamlit" / "secrets.toml"
SQL_PATH = PROJECT_ROOT / "dws" / "sql" / "08_refresh_region_month_v2.sql"
MONTHS = range(202601, 202607)
PLATFORMS = range(1, 5)


def settings(path: Path) -> dict[str, object]:
    config = tomllib.loads(path.read_text(encoding="utf-8"))
    values = config.get("database", config)

    def value(*names: str, default: object = None):
        for name in names:
            if name in values:
                return values[name]
            if name in config:
                return config[name]
        return default

    return {
        "host": value("DB_HOST", "host", default="127.0.0.1"),
        "port": int(value("DB_PORT", "port", default=3306)),
        "user": value("DB_USER", "user"),
        "password": value("DB_PASSWORD", "password"),
        "database": value("DB_NAME", "database", default="ec_cross_ceshi"),
    }


def connection(config: dict[str, object]):
    return pymysql.connect(
        **config,
        charset="utf8mb4",
        autocommit=False,
        read_timeout=3600,
        write_timeout=3600,
    )


def sql_parts() -> tuple[str, str, str, list[str]]:
    statements = [
        statement.strip()
        for statement in SQL_PATH.read_text(encoding="utf-8").split(";")
        if statement.strip()
    ]
    target_create = next(
        statement
        for statement in statements
        if "CREATE TABLE dws_region_month_summary_v2_2026_gj" in statement
    )
    temp_create = next(
        statement
        for statement in statements
        if "CREATE TEMPORARY TABLE tmp_region_resolved_2026_gj" in statement
    )
    temp_insert = next(
        statement
        for statement in statements
        if "INSERT INTO tmp_region_resolved_2026_gj" in statement
    )
    aggregates = [
        statement
        for statement in statements
        if "INSERT INTO dws_region_month_summary_v2_2026_gj" in statement
    ]
    if len(aggregates) != 4:
        raise RuntimeError(f"Expected four aggregate statements, found {len(aggregates)}")
    return target_create, temp_create, temp_insert, aggregates


def batch_status(cursor, month_id: int, platform_id: int) -> int:
    cursor.execute(
        """
        SELECT COUNT(DISTINCT region_level)
        FROM dws_region_month_summary_v2_2026_gj
        WHERE month_id = %s AND platform_id = %s
        """,
        (month_id, platform_id),
    )
    return int(cursor.fetchone()[0])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--secrets", type=Path, default=DEFAULT_SECRETS)
    parser.add_argument("--month", type=int)
    parser.add_argument("--platform", type=int, choices=PLATFORMS)
    args = parser.parse_args()

    selected_months = [args.month] if args.month else list(MONTHS)
    if any(month not in MONTHS for month in selected_months):
        raise ValueError("month must be between 202601 and 202606")
    selected_platforms = [args.platform] if args.platform else list(PLATFORMS)
    target_create, temp_create, temp_insert_template, aggregates = sql_parts()
    config = settings(args.secrets)

    bootstrap = connection(config)
    try:
        with bootstrap.cursor() as cursor:
            cursor.execute(
                """
                SELECT COUNT(*)
                FROM information_schema.tables
                WHERE table_schema = DATABASE()
                  AND table_name = 'dws_region_month_summary_v2_2026_gj'
                """
            )
            if int(cursor.fetchone()[0]) == 0:
                cursor.execute(target_create)
                bootstrap.commit()
                print("Created dws_region_month_summary_v2_2026_gj", flush=True)
    finally:
        bootstrap.close()

    completed = 0
    skipped = 0
    for month_id in selected_months:
        for platform_id in selected_platforms:
            conn = connection(config)
            started = time.time()
            try:
                with conn.cursor() as cursor:
                    levels = batch_status(cursor, month_id, platform_id)
                    if levels == 4:
                        skipped += 1
                        print(f"SKIP {month_id}/{platform_id}: already complete", flush=True)
                        continue
                    if levels != 0:
                        raise RuntimeError(
                            f"Refusing partial batch {month_id}/{platform_id}: "
                            f"found {levels} levels"
                        )

                    cursor.execute(temp_create)
                    temp_insert = temp_insert_template.replace(
                        "WHERE month_id BETWEEN 202601 AND 202606",
                        f"WHERE month_id = {month_id} AND platform_id = {platform_id}",
                        1,
                    )
                    if temp_insert == temp_insert_template:
                        raise RuntimeError("Could not inject the batch predicate")
                    cursor.execute(temp_insert)
                    resolved_rows = cursor.rowcount
                    print(
                        f"RESOLVED {month_id}/{platform_id}: "
                        f"{resolved_rows:,} shop-month rows",
                        flush=True,
                    )

                    target_rows = 0
                    for aggregate in aggregates:
                        cursor.execute(aggregate)
                        target_rows += cursor.rowcount
                    conn.commit()
                    completed += 1
                    print(
                        f"COMMIT {month_id}/{platform_id}: {target_rows:,} summary rows "
                        f"in {time.time() - started:.1f}s",
                        flush=True,
                    )
            except Exception:
                try:
                    conn.rollback()
                except Exception:
                    pass
                raise
            finally:
                conn.close()

    print(f"Completed batches: {completed}; skipped batches: {skipped}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
