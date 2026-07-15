SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- Run dm/sql/02_refresh_monthly_metrics.sql first, then apply the 2025
-- platform-month baseline. A missing or zero baseline never becomes 0%.
UPDATE dm_monthly_business_metrics_2026_gj current_data
LEFT JOIN dws_platform_month_summary_2025_gj previous_data
  ON previous_data.platform_id = current_data.platform_id
 AND previous_data.month_id = current_data.month_id - 100
SET current_data.last_year_sales_rmb = previous_data.total_sales_rmb,
    current_data.yoy_growth_pct =
        CASE
            WHEN previous_data.month_id IS NULL
              OR previous_data.total_sales_rmb IS NULL
              OR previous_data.total_sales_rmb = 0
              OR current_data.retail_sales_rmb IS NULL
            THEN NULL
            ELSE ROUND(
                (current_data.retail_sales_rmb - previous_data.total_sales_rmb)
                / previous_data.total_sales_rmb * 100,
                4
            )
        END,
    current_data.yoy_status =
        CASE
            WHEN previous_data.month_id IS NULL THEN 'NO_BASELINE'
            WHEN previous_data.total_sales_rmb IS NULL THEN 'NULL_BASELINE'
            WHEN previous_data.total_sales_rmb = 0 THEN 'ZERO_BASELINE'
            WHEN current_data.retail_sales_rmb IS NULL THEN 'NULL_CURRENT'
            ELSE 'CALCULATED'
        END
WHERE current_data.month_id BETWEEN 202601 AND 202606;

-- Must return 24 rows. CALCULATED rows must have a non-NULL YoY value.
SELECT month_id, platform_id, platform_name,
       retail_sales_rmb, last_year_sales_rmb,
       yoy_growth_pct, yoy_status
FROM dm_monthly_business_metrics_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
ORDER BY month_id, platform_id;
