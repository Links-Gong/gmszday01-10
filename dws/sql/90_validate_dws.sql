SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- Must return 24 rows.
SELECT month_id, platform_id, platform_name,
       total_sales_rmb, total_sales_num, shop_count,
       last_sales_rmb, mom_growth_pct
FROM dws_platform_month_summary_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
ORDER BY month_id, platform_id;

-- Platform reconciliation: all differences must be zero or NULL on both sides.
WITH dwd AS (
    SELECT month_id, platform_id,
           SUM(sales_money) AS dwd_money,
           SUM(sales_num) AS dwd_num,
           COUNT(DISTINCT shop_id) AS dwd_shop_count
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

-- National region totals must match platform totals.
SELECT p.month_id, p.platform_id,
       r.total_sales_rmb - p.total_sales_rmb AS region_money_difference,
       r.total_sales_num - p.total_sales_num AS region_num_difference,
       r.shop_count - p.shop_count AS region_shop_difference
FROM dws_platform_month_summary_2026_gj p
JOIN dws_region_month_summary_2026_gj r
  ON r.month_id = p.month_id
 AND r.platform_id = p.platform_id
 AND r.region_level = '全国'
WHERE p.month_id BETWEEN 202601 AND 202606
ORDER BY p.month_id, p.platform_id;

-- Category totals include '未分类' and must match platform totals.
WITH category_total AS (
    SELECT month_id, platform_id,
           SUM(total_sales_rmb) AS category_money,
           SUM(total_sales_num) AS category_num
    FROM dws_category_month_summary_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
    GROUP BY month_id, platform_id
)
SELECT p.month_id, p.platform_id,
       c.category_money - p.total_sales_rmb AS category_money_difference,
       c.category_num - p.total_sales_num AS category_num_difference
FROM dws_platform_month_summary_2026_gj p
JOIN category_total c USING (month_id, platform_id)
WHERE p.month_id BETWEEN 202601 AND 202606
ORDER BY p.month_id, p.platform_id;

-- Must return zero rows: January has no previous month inside this data set.
SELECT *
FROM dws_platform_month_summary_2026_gj
WHERE month_id = 202601
  AND (last_sales_rmb IS NOT NULL OR mom_growth_pct IS NOT NULL);

-- Must return zero rows.
SELECT month_id, platform_id, category_rank, COUNT(*) AS duplicate_rank
FROM dws_category_month_top10_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
GROUP BY month_id, platform_id, category_rank
HAVING COUNT(*) > 1 OR category_rank NOT BETWEEN 1 AND 10;

