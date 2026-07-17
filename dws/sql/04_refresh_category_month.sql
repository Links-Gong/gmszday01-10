SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- Build evidence maps only from observed DWD categories. Inferred values are
-- never fed back into these maps.
START TRANSACTION;

DELETE FROM dws_category_recovery_map_2026_gj;

INSERT INTO dws_category_recovery_map_2026_gj (
    map_type, platform_id, match_key, resolved_category_name,
    evidence_rows, first_month_id, last_month_id
)
WITH observed AS (
    SELECT
        month_id,
        platform_id,
        shop_id,
        CASE
            WHEN category_id IS NULL
              OR UPPER(TRIM(category_id)) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
            THEN NULL
            ELSE TRIM(category_id)
        END AS category_id,
        CASE
            WHEN category_name IS NULL THEN NULL
            WHEN UPPER(TRIM(REGEXP_REPLACE(
                     REPLACE(REPLACE(REPLACE(REPLACE(
                         category_name, CHAR(13), ''), CHAR(10), ''), CHAR(9), ' '),
                         CONVERT(UNHEX('C2A0') USING utf8mb4), ' '),
                     '[[:space:]]+', ' ')))
                 IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE', '未分类')
            THEN NULL
            ELSE LOWER(TRIM(REGEXP_REPLACE(
                     REPLACE(REPLACE(REPLACE(REPLACE(
                         category_name, CHAR(13), ''), CHAR(10), ''), CHAR(9), ' '),
                         CONVERT(UNHEX('C2A0') USING utf8mb4), ' '),
                     '[[:space:]]+', ' ')))
        END AS category_name
    FROM dwd_sales_detail_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
      AND platform_id IN (1, 2, 3)
), category_id_evidence AS (
    SELECT
        platform_id,
        category_id AS match_key,
        MIN(category_name) AS resolved_category_name,
        COUNT(*) AS evidence_rows,
        MIN(month_id) AS first_month_id,
        MAX(month_id) AS last_month_id
    FROM observed
    WHERE category_id IS NOT NULL AND category_name IS NOT NULL
    GROUP BY platform_id, category_id
    HAVING COUNT(DISTINCT category_name) = 1
)
SELECT
    'CATEGORY_ID', platform_id, match_key, resolved_category_name,
    evidence_rows, first_month_id, last_month_id
FROM category_id_evidence;

INSERT INTO dws_category_recovery_map_2026_gj (
    map_type, platform_id, match_key, resolved_category_name,
    evidence_rows, first_month_id, last_month_id
)
WITH observed AS (
    SELECT
        month_id,
        platform_id,
        shop_id,
        CASE
            WHEN category_name IS NULL THEN NULL
            WHEN UPPER(TRIM(REGEXP_REPLACE(
                     REPLACE(REPLACE(REPLACE(REPLACE(
                         category_name, CHAR(13), ''), CHAR(10), ''), CHAR(9), ' '),
                         CONVERT(UNHEX('C2A0') USING utf8mb4), ' '),
                     '[[:space:]]+', ' ')))
                 IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE', '未分类')
            THEN NULL
            ELSE LOWER(TRIM(REGEXP_REPLACE(
                     REPLACE(REPLACE(REPLACE(REPLACE(
                         category_name, CHAR(13), ''), CHAR(10), ''), CHAR(9), ' '),
                         CONVERT(UNHEX('C2A0') USING utf8mb4), ' '),
                     '[[:space:]]+', ' ')))
        END AS category_name
    FROM dwd_sales_detail_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
      AND platform_id IN (1, 2, 3)
), shop_evidence AS (
    SELECT
        platform_id,
        shop_id AS match_key,
        MIN(category_name) AS resolved_category_name,
        COUNT(*) AS evidence_rows,
        MIN(month_id) AS first_month_id,
        MAX(month_id) AS last_month_id
    FROM observed
    WHERE shop_id IS NOT NULL AND category_name IS NOT NULL
    GROUP BY platform_id, shop_id
    HAVING COUNT(DISTINCT category_name) = 1
)
SELECT
    'SHOP_HISTORY', platform_id, match_key, resolved_category_name,
    evidence_rows, first_month_id, last_month_id
FROM shop_evidence;

COMMIT;

START TRANSACTION;

DELETE FROM dws_category_month_summary_2026_gj
WHERE month_id BETWEEN 202601 AND 202606;

DELETE FROM dws_category_month_top10_2026_gj
WHERE month_id BETWEEN 202601 AND 202606;

INSERT INTO dws_category_month_summary_2026_gj (
    month_id, platform_id, platform_name, category_name,
    total_sales_rmb, total_sales_num, shop_count, money_valid_rows
)
WITH normalized AS (
    SELECT
        d.month_id,
        d.platform_id,
        d.platform_name,
        d.shop_id,
        CASE
            WHEN d.category_id IS NULL
              OR UPPER(TRIM(d.category_id)) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
            THEN NULL
            ELSE TRIM(d.category_id)
        END AS category_id,
        CASE
            WHEN d.category_name IS NULL THEN NULL
            WHEN UPPER(TRIM(REGEXP_REPLACE(
                     REPLACE(REPLACE(REPLACE(REPLACE(
                         d.category_name, CHAR(13), ''), CHAR(10), ''), CHAR(9), ' '),
                         CONVERT(UNHEX('C2A0') USING utf8mb4), ' '),
                     '[[:space:]]+', ' ')))
                 IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE', '未分类')
            THEN NULL
            ELSE LOWER(TRIM(REGEXP_REPLACE(
                     REPLACE(REPLACE(REPLACE(REPLACE(
                         d.category_name, CHAR(13), ''), CHAR(10), ''), CHAR(9), ' '),
                         CONVERT(UNHEX('C2A0') USING utf8mb4), ' '),
                     '[[:space:]]+', ' ')))
        END AS source_category_name,
        d.sales_money,
        d.sales_num
    FROM dwd_sales_detail_2026_gj d
    WHERE d.month_id BETWEEN 202601 AND 202606
), resolved AS (
    SELECT
        n.month_id,
        n.platform_id,
        n.platform_name,
        n.shop_id,
        COALESCE(
            n.source_category_name,
            id_map.resolved_category_name,
            shop_map.resolved_category_name,
            '未分类'
        ) AS category_name,
        n.sales_money,
        n.sales_num
    FROM normalized n
    LEFT JOIN dws_category_recovery_map_2026_gj id_map
      ON id_map.map_type = 'CATEGORY_ID'
     AND id_map.platform_id = n.platform_id
     AND id_map.match_key = n.category_id
    LEFT JOIN dws_category_recovery_map_2026_gj shop_map
      ON shop_map.map_type = 'SHOP_HISTORY'
     AND shop_map.platform_id = n.platform_id
     AND shop_map.match_key = n.shop_id
)
SELECT
    month_id,
    platform_id,
    MAX(platform_name),
    category_name,
    SUM(sales_money),
    SUM(sales_num),
    COUNT(DISTINCT shop_id),
    SUM(sales_money IS NOT NULL)
FROM resolved
GROUP BY month_id, platform_id, category_name;

INSERT INTO dws_category_month_top10_2026_gj (
    month_id, platform_id, platform_name, category_name,
    total_sales_rmb, total_sales_num, shop_count,
    sales_pct, category_rank
)
WITH totals AS (
    SELECT
        c.*,
        SUM(total_sales_rmb) OVER (
            PARTITION BY month_id, platform_id
        ) AS all_category_sales_rmb
    FROM dws_category_month_summary_2026_gj c
    WHERE month_id BETWEEN 202601 AND 202606
), ranked AS (
    SELECT
        t.*,
        CASE WHEN total_sales_rmb IS NULL THEN NULL
             ELSE ROUND(
                 total_sales_rmb / NULLIF(all_category_sales_rmb, 0) * 100,
                 4
             ) END AS sales_pct,
        ROW_NUMBER() OVER (
            PARTITION BY month_id, platform_id
            ORDER BY total_sales_rmb IS NULL,
                     total_sales_rmb DESC,
                     category_name
        ) AS category_rank
    FROM totals t
    WHERE category_name <> '未分类'
)
SELECT
    month_id, platform_id, platform_name, category_name,
    total_sales_rmb, total_sales_num, shop_count,
    sales_pct, category_rank
FROM ranked
WHERE category_rank <= 10;

COMMIT;

SELECT *
FROM dws_category_month_top10_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
ORDER BY month_id, platform_id, category_rank;
