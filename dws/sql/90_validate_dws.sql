SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- Must return 24 rows.
SELECT month_id, platform_id, platform_name,
       total_sales_rmb, total_sales_num, shop_count,
       last_sales_rmb, mom_growth_pct
FROM dws_platform_month_summary_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
ORDER BY month_id, platform_id;

-- Platform reconciliation: all differences must be zero.
WITH dwd AS (
    SELECT month_id, platform_id,
           SUM(sales_money) AS dwd_money,
           SUM(sales_num) AS dwd_num,
           COUNT(*) AS dwd_shop_count
    FROM dwd_sales_detail_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
    GROUP BY month_id, platform_id
)
SELECT p.month_id, p.platform_id,
       p.total_sales_rmb - d.dwd_money AS money_difference,
       p.total_sales_num - d.dwd_num AS num_difference,
       p.shop_count - d.dwd_shop_count AS shop_difference
FROM dws_platform_month_summary_2026_gj p
JOIN dwd d USING (month_id, platform_id)
WHERE p.month_id BETWEEN 202601 AND 202606
ORDER BY p.month_id, p.platform_id;

-- Category totals retain unclassified rows and must match platform totals.
WITH category_total AS (
    SELECT month_id, platform_id,
           SUM(total_sales_rmb) AS category_money,
           SUM(total_sales_num) AS category_num,
           SUM(shop_count) AS category_shops
    FROM dws_category_month_summary_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
    GROUP BY month_id, platform_id
)
SELECT p.month_id, p.platform_id,
       c.category_money - p.total_sales_rmb AS category_money_difference,
       c.category_num - p.total_sales_num AS category_num_difference,
       c.category_shops - p.shop_count AS category_shop_difference
FROM dws_platform_month_summary_2026_gj p
JOIN category_total c USING (month_id, platform_id)
WHERE p.month_id BETWEEN 202601 AND 202606
ORDER BY p.month_id, p.platform_id;

-- Ozon now carries the observed source category. Must return zero.
SELECT COUNT(*) AS ozon_rows_without_category
FROM dwd_sales_detail_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
  AND platform_id = 4
  AND sales_money IS NOT NULL
  AND (category_name IS NULL OR TRIM(category_name) = '');

-- Evidence maps must contain only supported types and complete evidence.
SELECT COUNT(*) AS invalid_recovery_map_rows
FROM dws_category_recovery_map_2026_gj
WHERE map_type NOT IN ('CATEGORY_ID', 'SHOP_HISTORY')
   OR match_key IS NULL OR TRIM(match_key) = ''
   OR resolved_category_name IS NULL OR TRIM(resolved_category_name) = ''
   OR evidence_rows <= 0
   OR first_month_id > last_month_id;

-- Classification coverage after recovery. Expected unresolved RMB:
-- SMT=918166824.47; Amazon=168184777135.49;
-- Alibaba=5118489515.25; Ozon=0.
SELECT
    platform_id,
    MAX(platform_name) AS platform_name,
    SUM(total_sales_rmb) AS total_sales_rmb,
    SUM(CASE WHEN category_name = '未分类' THEN total_sales_rmb ELSE 0 END)
        AS unclassified_sales_rmb,
    ROUND(
        SUM(CASE WHEN category_name = '未分类' THEN total_sales_rmb ELSE 0 END)
        / NULLIF(SUM(total_sales_rmb), 0) * 100,
        4
    ) AS unclassified_pct
FROM dws_category_month_summary_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
GROUP BY platform_id
ORDER BY platform_id;

-- Must return zero: normalized category labels contain no control characters.
SELECT COUNT(*) AS category_labels_with_control_characters
FROM dws_category_month_summary_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
  AND (category_name LIKE CONCAT('%', CHAR(13), '%')
    OR category_name LIKE CONCAT('%', CHAR(10), '%')
    OR category_name LIKE CONCAT('%', CHAR(9), '%'));

-- Must return zero: unclassified is kept in the base but excluded from TOP10.
SELECT COUNT(*) AS unclassified_top10_rows
FROM dws_category_month_top10_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
  AND category_name = '未分类';

-- Must return zero: ranks are unique, continuous, and between 1 and 10.
WITH ranked AS (
    SELECT month_id, platform_id, category_rank,
           ROW_NUMBER() OVER (
               PARTITION BY month_id, platform_id ORDER BY category_rank
           ) AS expected_rank,
           COUNT(*) OVER (
               PARTITION BY month_id, platform_id, category_rank
           ) AS duplicate_rank
    FROM dws_category_month_top10_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
)
SELECT COUNT(*) AS invalid_top10_rank_rows
FROM ranked
WHERE category_rank <> expected_rank
   OR category_rank NOT BETWEEN 1 AND 10
   OR duplicate_rank > 1;

-- TOP10 percentages must use all category sales, including unclassified.
WITH totals AS (
    SELECT month_id, platform_id, SUM(total_sales_rmb) AS all_sales_rmb
    FROM dws_category_month_summary_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
    GROUP BY month_id, platform_id
)
SELECT COUNT(*) AS invalid_top10_sales_pct_rows
FROM dws_category_month_top10_2026_gj t
JOIN totals a USING (month_id, platform_id)
WHERE ABS(t.sales_pct - ROUND(t.total_sales_rmb / NULLIF(a.all_sales_rmb, 0) * 100, 4)) > 0.0001;

-- Must return zero: January has no previous month inside this data set.
SELECT COUNT(*) AS january_rows_with_mom_baseline
FROM dws_platform_month_summary_2026_gj
WHERE month_id = 202601
  AND (last_sales_rmb IS NOT NULL OR mom_growth_pct IS NOT NULL);
