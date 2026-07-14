SET NAMES utf8mb4;
USE ec_cross_ceshi;

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
        month_id,
        platform_id,
        platform_name,
        CASE
            WHEN category_name IS NULL
              OR UPPER(TRIM(category_name)) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
            THEN '未分类'
            ELSE LOWER(TRIM(category_name))
        END AS category_name,
        shop_id,
        sales_money,
        sales_num
    FROM dwd_sales_detail_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
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
FROM normalized
GROUP BY month_id, platform_id, category_name;

INSERT INTO dws_category_month_top10_2026_gj (
    month_id, platform_id, platform_name, category_name,
    total_sales_rmb, total_sales_num, shop_count,
    sales_pct, category_rank
)
WITH ranked AS (
    SELECT
        c.*,
        CASE WHEN total_sales_rmb IS NULL THEN NULL
             ELSE ROUND(
                 total_sales_rmb
                 / NULLIF(SUM(total_sales_rmb) OVER (
                     PARTITION BY month_id, platform_id
                   ), 0) * 100,
                 4
             ) END AS sales_pct,
        ROW_NUMBER() OVER (
            PARTITION BY month_id, platform_id
            ORDER BY total_sales_rmb IS NULL,
                     total_sales_rmb DESC,
                     category_name
        ) AS category_rank
    FROM dws_category_month_summary_2026_gj c
    WHERE month_id BETWEEN 202601 AND 202606
)
SELECT
    month_id, platform_id, platform_name, category_name,
    total_sales_rmb, total_sales_num, shop_count,
    sales_pct, category_rank
FROM ranked
WHERE category_rank <= 10;

SELECT *
FROM dws_category_month_top10_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
ORDER BY month_id, platform_id, category_rank;
