import argparse
from pathlib import Path


YEAR = 2026
MONTHS = range(202601, 202607)
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "sql" / "load"
STAGE_TABLE = "stg_dwd_sales_detail_2026_gj"
AUDIT_TABLE = "etl_load_audit_2026_gj"
PROMOTE_PROCEDURE = "sp_promote_dwd_batch_2026_gj"
DIM_STAGE_TABLE = "stg_dim_company_basic_2026_gj"
PLACEHOLDERS = "('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')"
NUMERIC_PATTERN = "^([0-9]+([.][0-9]+)?|[.][0-9]+)$"

STAGE_COLUMNS = """(
    month_id, platform_id, platform_name, shop_id, shop_name,
    company_name, company_address, country, province, city, county,
    sales_num, sales_money, currency_type, category_id, category_name,
    source_row_count, invalid_sales_num_count, invalid_sales_money_count,
    dim_match_flag
)"""


def configure(year: int, output_dir: Path | None = None) -> None:
    global YEAR, MONTHS, OUTPUT_DIR, STAGE_TABLE, AUDIT_TABLE, PROMOTE_PROCEDURE

    if year not in (2025, 2026):
        raise ValueError("Only 2025 and 2026 are supported")

    YEAR = year
    MONTHS = range(year * 100 + 1, year * 100 + 7)
    suffix = f"{year}_gj"
    STAGE_TABLE = f"stg_dwd_sales_detail_{suffix}"
    AUDIT_TABLE = f"etl_load_audit_{suffix}"
    PROMOTE_PROCEDURE = f"sp_promote_dwd_batch_{suffix}"

    if output_dir is not None:
        OUTPUT_DIR = output_dir
    elif year == 2026:
        OUTPUT_DIR = Path(__file__).resolve().parents[1] / "sql" / "load"
    else:
        OUTPUT_DIR = Path(__file__).resolve().parents[1] / "sql" / f"load_{year}"


def clean_text(expression: str, *, shop_id: bool = False) -> str:
    value = f"TRIM(CAST({expression} AS CHAR))"
    if shop_id:
        value = safe_shop_id(expression)
        comparable = value
    else:
        comparable = f"TRIM(CAST({expression} AS CHAR))"
    return (
        f"CASE WHEN {expression} IS NULL "
        f"OR UPPER({comparable}) IN {PLACEHOLDERS} "
        f"THEN NULL ELSE {value} END"
    )


def safe_shop_id(expression: str) -> str:
    # Remove both UTF-8 NBSP (C2A0) and a stray latin1 A0 while the value is
    # binary, then decode the remaining original UTF-8 bytes normally. This
    # avoids both conversion errors and latin1 byte-expansion of non-ASCII IDs.
    return (
        "TRIM(CONVERT("
        "REPLACE(REPLACE("
        f"CAST({expression} AS BINARY), "
        "UNHEX('C2A0'), UNHEX('')), "
        "UNHEX('A0'), UNHEX('')) "
        "USING utf8mb4))"
    )


def clean_numeric(expression: str) -> str:
    # Remove common UTF-8/latin1 currency and NBSP byte sequences while the
    # value is binary. The remaining numeric text can always be read safely.
    binary_value = f"CAST({expression} AS BINARY)"
    for token in ("EFBFA5", "EFBF84", "EFBC8C", "C2A5", "C2A0", "A5", "A0"):
        binary_value = f"REPLACE({binary_value}, UNHEX('{token}'), UNHEX(''))"
    value = f"TRIM(CONVERT({binary_value} USING latin1))"
    return (
        f"CASE WHEN {expression} IS NULL OR UPPER({value}) IN {PLACEHOLDERS} "
        f"THEN NULL ELSE {value} END"
    )


def valid_shop_condition(expression: str) -> str:
    normalized = safe_shop_id(expression)
    return (
        f"{expression} IS NOT NULL AND "
        f"UPPER({normalized}) NOT IN {PLACEHOLDERS}"
    )


def strip_numeric(expression: str) -> str:
    result = f"UPPER({expression})"
    for token in ("US$", "USD", "RMB", "CNY", "$", ",", " "):
        escaped = token.replace("'", "''")
        result = f"REPLACE({result}, '{escaped}', '')"
    return result


def audit_preamble(month: int, platform_id: int, platform_name: str, source: str) -> str:
    shop_condition = valid_shop_condition("shop_id")
    normalized_shop_id = safe_shop_id("shop_id")
    return f"""-- Generated file. Re-run only this batch after a timeout or failure.
SET NAMES utf8mb4;
USE ec_cross_ceshi;
SET SESSION group_concat_max_len = 4096;
SET SESSION max_execution_time = 0;

SET @source_row_count = (SELECT COUNT(*) FROM ec_cross_border.{source});
SET @empty_shop_id_count = (
    SELECT COUNT(*) FROM ec_cross_border.{source}
    WHERE NOT ({shop_condition})
);
SET @valid_shop_count = (
    SELECT COUNT(DISTINCT {normalized_shop_id})
    FROM ec_cross_border.{source}
    WHERE {shop_condition}
);

INSERT INTO {AUDIT_TABLE} (
    batch_key, month_id, platform_id, platform_name, source_table,
    source_row_count, empty_shop_id_count, valid_shop_count,
    staged_row_count, target_row_count, status, message,
    started_time, completed_time
) VALUES (
    '{month}-{platform_id}', {month}, {platform_id}, '{platform_name}', '{source}',
    @source_row_count, @empty_shop_id_count, @valid_shop_count,
    NULL, NULL, 'RUNNING', 'Building isolated staging batch',
    CURRENT_TIMESTAMP, NULL
)
ON DUPLICATE KEY UPDATE
    source_table = VALUES(source_table),
    source_row_count = VALUES(source_row_count),
    empty_shop_id_count = VALUES(empty_shop_id_count),
    valid_shop_count = VALUES(valid_shop_count),
    staged_row_count = NULL,
    target_row_count = NULL,
    staged_sales_money_rmb = NULL,
    target_sales_money_rmb = NULL,
    status = 'RUNNING',
    message = 'Building isolated staging batch',
    started_time = CURRENT_TIMESTAMP,
    completed_time = NULL;

DELETE FROM {STAGE_TABLE}
WHERE month_id = {month} AND platform_id = {platform_id};
"""


def audit_postamble(month: int, platform_id: int) -> str:
    return f"""
SET @staged_row_count = (
    SELECT COUNT(*) FROM {STAGE_TABLE}
    WHERE month_id = {month} AND platform_id = {platform_id}
);
SET @staged_sales_money_rmb = (
    SELECT ROUND(SUM(sales_money), 2) FROM {STAGE_TABLE}
    WHERE month_id = {month} AND platform_id = {platform_id}
);

UPDATE {AUDIT_TABLE}
SET staged_row_count = @staged_row_count,
    staged_sales_money_rmb = @staged_sales_money_rmb,
    status = 'STAGED',
    message = 'Staging complete; validating before promotion'
WHERE month_id = {month} AND platform_id = {platform_id};

CALL {PROMOTE_PROCEDURE}({month}, {platform_id});

SELECT month_id, platform_id, platform_name, source_row_count,
       empty_shop_id_count, valid_shop_count, staged_row_count,
       target_row_count, staged_sales_money_rmb, target_sales_money_rmb,
       status, message, completed_time
FROM {AUDIT_TABLE}
WHERE month_id = {month} AND platform_id = {platform_id};
"""


def typed_ctes() -> str:
    sales_num_text = strip_numeric("sales_num_raw")
    sales_money_text = strip_numeric("sales_money_raw")
    return f""", normalized AS (
    SELECT c.*,
           {sales_num_text} AS sales_num_text,
           {sales_money_text} AS sales_money_text
    FROM cleaned c
), typed AS (
    SELECT n.*,
           CASE WHEN sales_num_text REGEXP '{NUMERIC_PATTERN}'
                THEN CAST(sales_num_text AS DECIMAL(28,4)) END AS sales_num_value,
           CASE WHEN sales_money_text REGEXP '{NUMERIC_PATTERN}'
                THEN CAST(sales_money_text AS DECIMAL(28,4)) END AS sales_money_value,
           CASE WHEN sales_num_raw IS NOT NULL
                     AND NOT (sales_num_text REGEXP '{NUMERIC_PATTERN}')
                THEN 1 ELSE 0 END AS invalid_sales_num_flag,
           CASE WHEN sales_money_raw IS NOT NULL
                     AND NOT (sales_money_text REGEXP '{NUMERIC_PATTERN}')
                THEN 1 ELSE 0 END AS invalid_sales_money_flag
    FROM normalized n
)"""


def smt_sql(month: int) -> str:
    source = f"smt_shopinfo_{month}"
    body = f"""
INSERT INTO {STAGE_TABLE} {STAGE_COLUMNS}
WITH cleaned AS (
    SELECT
        {clean_text('s.shop_id', shop_id=True)} AS shop_id,
        {clean_text('s.shop_name')} AS shop_name,
        {clean_text('s.company')} AS company_name,
        {clean_text('s.address')} AS company_address,
        NULL AS country,
        {clean_text('s.province')} AS province,
        {clean_text('s.city')} AS city,
        {clean_text('s.county')} AS county,
        {clean_numeric('s.sales_num')} AS sales_num_raw,
        {clean_numeric('s.sales_month')} AS sales_money_raw,
        COALESCE({clean_text('s.category_id_new')}, {clean_text('s.category_id')}) AS category_id,
        COALESCE({clean_text('s.category_name_new')}, {clean_text('s.category_name')}) AS category_name
    FROM ec_cross_border.{source} s
    WHERE {valid_shop_condition('s.shop_id')}
){typed_ctes()}
SELECT
    {month}, 1, 'SMT', shop_id, shop_name,
    company_name, company_address, country, province, city, county,
    sales_num_value,
    CASE WHEN sales_money_value IS NULL THEN NULL
         ELSE ROUND(sales_money_value * 7.2, 2) END,
    'RMB', category_id, category_name,
    1, invalid_sales_num_flag, invalid_sales_money_flag, 0
FROM typed;
"""
    return audit_preamble(month, 1, "SMT", source) + body + audit_postamble(month, 1)


def aggregated_platform_sql(
    month: int,
    platform_id: int,
    platform_name: str,
    source: str,
    dim_platform: str,
    cleaned_select: str,
    money_factor: str,
) -> str:
    body = f"""
INSERT INTO {STAGE_TABLE} {STAGE_COLUMNS}
WITH cleaned AS (
    SELECT DISTINCT
{cleaned_select}
    FROM ec_cross_border.{source} s
    WHERE {valid_shop_condition('s.shop_id')}
){typed_ctes()}, aggregated AS (
    SELECT
        shop_id,
        MAX(shop_name) AS shop_name,
        MAX(company_name) AS company_name,
        MAX(company_address) AS company_address,
        MAX(country) AS country,
        MAX(province) AS province,
        MAX(city) AS city,
        MAX(county) AS county,
        SUM(sales_num_value) AS sales_num,
        ROUND(SUM(sales_money_value * {money_factor}), 2) AS sales_money,
        SUBSTRING_INDEX(
            GROUP_CONCAT(
                CONCAT(COALESCE(category_id, '__NULL__'),
                       '|#PAIR#|',
                       COALESCE(category_name, '__NULL__'))
                ORDER BY sales_money_value IS NULL,
                         sales_money_value DESC, category_id, category_name
                SEPARATOR '|#ROW#|'
            ),
            '|#ROW#|', 1
        ) AS primary_category_pair,
        COUNT(*) AS source_row_count,
        SUM(invalid_sales_num_flag) AS invalid_sales_num_count,
        SUM(invalid_sales_money_flag) AS invalid_sales_money_count
    FROM typed
    GROUP BY shop_id
)
SELECT
    {month}, {platform_id}, '{platform_name}', a.shop_id, a.shop_name,
    COALESCE(d.company_name, a.company_name),
    COALESCE(d.company_address, a.company_address),
    a.country,
    COALESCE(a.province, d.province),
    COALESCE(a.city, d.city),
    COALESCE(a.county, d.county),
    a.sales_num, a.sales_money, 'RMB',
    NULLIF(SUBSTRING_INDEX(a.primary_category_pair, '|#PAIR#|', 1), '__NULL__'),
    NULLIF(SUBSTRING_INDEX(a.primary_category_pair, '|#PAIR#|', -1), '__NULL__'),
    a.source_row_count, a.invalid_sales_num_count,
    a.invalid_sales_money_count,
    CASE WHEN d.shop_id IS NULL THEN 0 ELSE 1 END
FROM aggregated a
LEFT JOIN {DIM_STAGE_TABLE} d
  ON d.platform = '{dim_platform}'
 AND d.platform_id = {platform_id}
 AND d.shop_id = a.shop_id;
"""
    return (
        audit_preamble(month, platform_id, platform_name, source)
        + body
        + audit_postamble(month, platform_id)
    )


def amazon_sql(month: int) -> str:
    source = f"amazonus_shopinfo_{month}_sales"
    cleaned = f"""        {clean_text('s.shop_id', shop_id=True)} AS shop_id,
        {clean_text('s.shop_name')} AS shop_name,
        {clean_text('s.company')} AS company_name,
        {clean_text('s.company_address')} AS company_address,
        {clean_text('s.country')} AS country,
        {clean_text('s.province')} AS province,
        {clean_text('s.city')} AS city,
        {clean_text('s.county')} AS county,
        {clean_numeric('s.sales')} AS sales_num_raw,
        {clean_numeric('s.sales_money')} AS sales_money_raw,
        {clean_text('s.category_id_new')} AS category_id,
        {clean_text('s.category_name_new')} AS category_name"""
    return aggregated_platform_sql(
        month, 2, "Amazon", source, "amus", cleaned, "7.2"
    )


def alibaba_sql(month: int) -> str:
    source = f"alibabagj_shopinfo_{month}"
    cleaned = f"""        {clean_text('s.shop_id', shop_id=True)} AS shop_id,
        NULL AS shop_name,
        COALESCE({clean_text('s.company_cn')}, {clean_text('s.company')}) AS company_name,
        COALESCE({clean_text('s.company_address')}, {clean_text('s.address')}) AS company_address,
        {clean_text('s.country')} AS country,
        {clean_text('s.province')} AS province,
        {clean_text('s.city')} AS city,
        {clean_text('s.county')} AS county,
        {clean_numeric('s.sales')} AS sales_num_raw,
        {clean_numeric('s.sales_money')} AS sales_money_raw,
        COALESCE({clean_text('s.category_id_new')}, {clean_text('s.category_id')}) AS category_id,
        COALESCE({clean_text('s.category_name_new')}, {clean_text('s.category_name')}) AS category_name"""
    return aggregated_platform_sql(
        month, 3, "Alibaba", source, "algj", cleaned, "2.25"
    )


def ozon_sql(month: int) -> str:
    source = f"ozon_shopinfo_{month}_cn"
    body = f"""
INSERT INTO {STAGE_TABLE} {STAGE_COLUMNS}
WITH cleaned AS (
    SELECT
        {clean_text('o.shop_id', shop_id=True)} AS shop_id,
        {clean_text('o.goods_id')} AS goods_id,
        {clean_text('o.shop_name')} AS shop_name,
        COALESCE({clean_text('o.company_cn')}, {clean_text('o.company')}) AS company_name,
        COALESCE({clean_text('o.company_address')}, {clean_text('o.address')}) AS company_address,
        {clean_text('o.country')} AS country,
        {clean_text('o.province')} AS province,
        {clean_text('o.city')} AS city,
        {clean_text('o.county')} AS county,
        {clean_numeric('o.sales_num')} AS sales_num_raw,
        {clean_numeric('o.sales_money')} AS sales_money_raw
    FROM ec_cross_border.{source} o
    WHERE {valid_shop_condition('o.shop_id')}
){typed_ctes()}, goods_deduplicated AS (
    SELECT
        shop_id,
        COALESCE(
            goods_id,
            CONCAT('__NULL__|', SHA2(CONCAT_WS('|',
                COALESCE(shop_name, '__NULL__'),
                COALESCE(company_name, '__NULL__'),
                COALESCE(company_address, '__NULL__'),
                COALESCE(country, '__NULL__'),
                COALESCE(province, '__NULL__'),
                COALESCE(city, '__NULL__'),
                COALESCE(county, '__NULL__'),
                COALESCE(sales_num_raw, '__NULL__'),
                COALESCE(sales_money_raw, '__NULL__')), 256))
        ) AS goods_key,
        MAX(shop_name) AS shop_name,
        MAX(company_name) AS company_name,
        MAX(company_address) AS company_address,
        MAX(country) AS country,
        MAX(province) AS province,
        MAX(city) AS city,
        MAX(county) AS county,
        MAX(sales_num_value) AS sales_num_value,
        MAX(sales_money_value) AS sales_money_value,
        MAX(invalid_sales_num_flag) AS invalid_sales_num_flag,
        MAX(invalid_sales_money_flag) AS invalid_sales_money_flag
    FROM typed
    GROUP BY shop_id,
             COALESCE(goods_id, CONCAT('__NULL__|', SHA2(CONCAT_WS('|',
                 COALESCE(shop_name, '__NULL__'),
                 COALESCE(company_name, '__NULL__'),
                 COALESCE(company_address, '__NULL__'),
                 COALESCE(country, '__NULL__'),
                 COALESCE(province, '__NULL__'),
                 COALESCE(city, '__NULL__'),
                 COALESCE(county, '__NULL__'),
                 COALESCE(sales_num_raw, '__NULL__'),
                 COALESCE(sales_money_raw, '__NULL__')), 256)))
), aggregated AS (
    SELECT
        shop_id,
        MAX(shop_name) AS shop_name,
        MAX(company_name) AS company_name,
        MAX(company_address) AS company_address,
        MAX(country) AS country,
        MAX(province) AS province,
        MAX(city) AS city,
        MAX(county) AS county,
        SUM(sales_num_value) AS sales_num,
        ROUND(SUM(sales_money_value), 2) AS sales_money,
        COUNT(*) AS source_row_count,
        SUM(invalid_sales_num_flag) AS invalid_sales_num_count,
        SUM(invalid_sales_money_flag) AS invalid_sales_money_count
    FROM goods_deduplicated
    GROUP BY shop_id
)
SELECT
    {month}, 4, 'Ozon', a.shop_id, a.shop_name,
    COALESCE(d.company_name, a.company_name),
    COALESCE(d.company_address, a.company_address),
    a.country,
    COALESCE(a.province, d.province),
    COALESCE(a.city, d.city),
    COALESCE(a.county, d.county),
    a.sales_num, a.sales_money, 'RMB', NULL, NULL,
    a.source_row_count, a.invalid_sales_num_count,
    a.invalid_sales_money_count,
    CASE WHEN d.shop_id IS NULL THEN 0 ELSE 1 END
FROM aggregated a
LEFT JOIN {DIM_STAGE_TABLE} d
  ON d.platform = 'ozon'
 AND d.platform_id = 4
 AND d.shop_id = a.shop_id;
"""
    return audit_preamble(month, 4, "Ozon", source) + body + audit_postamble(month, 4)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate six monthly DWD load scripts for four platforms."
    )
    parser.add_argument(
        "--year",
        type=int,
        choices=(2025, 2026),
        default=2026,
        help="Source year and target-table suffix (default: 2026).",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        help="Optional output directory. Defaults to sql/load for 2026 and sql/load_YEAR otherwise.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    configure(args.year, args.output_dir)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    generators = (
        (1, "smt", smt_sql),
        (2, "amazon", amazon_sql),
        (3, "alibaba", alibaba_sql),
        (4, "ozon", ozon_sql),
    )
    expected_files = set()
    for month in MONTHS:
        for platform_id, slug, generator in generators:
            filename = f"load_{month}_{platform_id:02d}_{slug}.sql"
            expected_files.add(filename)
            (OUTPUT_DIR / filename).write_text(generator(month), encoding="utf-8")

    for old_file in OUTPUT_DIR.glob("load_*.sql"):
        if old_file.name not in expected_files:
            old_file.unlink()

    print(
        f"Generated {len(expected_files)} load scripts for {YEAR} in {OUTPUT_DIR}"
    )


if __name__ == "__main__":
    main()
