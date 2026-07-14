SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- Must return 24 rows; formula differences must be zero.
SELECT
    month_id,
    platform_id,
    express_revenue_rmb - ROUND(retail_sales_rmb * 0.15, 2) AS revenue_difference,
    express_volume - ROUND(retail_sales_num * 0.53, 4) AS volume_difference,
    previous_month_sales_rmb,
    mom_growth_pct,
    last_year_sales_rmb,
    yoy_growth_pct,
    yoy_status
FROM dm_monthly_business_metrics_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
ORDER BY month_id, platform_id;

-- Must return zero rows: no 2025 baseline is loaded.
SELECT *
FROM dm_monthly_business_metrics_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
  AND (last_year_sales_rmb IS NOT NULL
       OR yoy_growth_pct IS NOT NULL
       OR yoy_status <> 'NO_BASELINE');

-- Monthly DM must equal platform DWS.
SELECT d.month_id, d.platform_id,
       d.retail_sales_rmb - p.total_sales_rmb AS money_difference,
       d.retail_sales_num - p.total_sales_num AS num_difference,
       d.shop_count - p.shop_count AS shop_difference
FROM dm_monthly_business_metrics_2026_gj d
JOIN dws_platform_month_summary_2026_gj p
  ON p.month_id = d.month_id AND p.platform_id = d.platform_id
WHERE d.month_id BETWEEN 202601 AND 202606
ORDER BY d.month_id, d.platform_id;

-- Must return zero rows.
SELECT month_id, platform_id, company_name, COUNT(*) AS duplicate_count
FROM dm_enterprise_sales_rank_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
GROUP BY month_id, platform_id, company_name
HAVING COUNT(*) > 1;

