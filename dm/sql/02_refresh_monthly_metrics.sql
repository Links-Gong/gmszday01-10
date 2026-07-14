SET NAMES utf8mb4;
USE ec_cross_ceshi;

DELETE FROM dm_monthly_business_metrics_2026_gj
WHERE month_id BETWEEN 202601 AND 202606;

INSERT INTO dm_monthly_business_metrics_2026_gj (
    month_id, platform_id, platform_name,
    retail_sales_rmb, retail_sales_num,
    express_revenue_rmb, express_volume,
    previous_month_sales_rmb, mom_growth_pct,
    last_year_sales_rmb, yoy_growth_pct,
    shop_count, valid_money_rows,
    metric_status, yoy_status
)
SELECT
    month_id,
    platform_id,
    platform_name,
    total_sales_rmb,
    total_sales_num,
    CASE WHEN total_sales_rmb IS NULL THEN NULL
         ELSE ROUND(total_sales_rmb * 0.15, 2) END,
    CASE WHEN total_sales_num IS NULL THEN NULL
         ELSE ROUND(total_sales_num * 0.53, 4) END,
    last_sales_rmb,
    mom_growth_pct,
    NULL,
    NULL,
    shop_count,
    money_valid_rows,
    CASE WHEN total_sales_rmb IS NULL THEN '销售额全部缺失'
         ELSE '数据有效' END,
    'NO_BASELINE'
FROM dws_platform_month_summary_2026_gj
WHERE month_id BETWEEN 202601 AND 202606;

SELECT *
FROM dm_monthly_business_metrics_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
ORDER BY month_id, platform_id;

