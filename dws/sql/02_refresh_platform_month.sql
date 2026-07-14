SET NAMES utf8mb4;
USE ec_cross_ceshi;

DELETE FROM dws_platform_month_summary_2026_gj
WHERE month_id BETWEEN 202601 AND 202606;

INSERT INTO dws_platform_month_summary_2026_gj (
    month_id, platform_id, platform_name,
    total_sales_rmb, total_sales_num, shop_count,
    money_valid_rows, num_valid_rows,
    last_sales_rmb, mom_growth_pct
)
WITH monthly AS (
    SELECT
        month_id,
        platform_id,
        MAX(platform_name) AS platform_name,
        SUM(sales_money) AS total_sales_rmb,
        SUM(sales_num) AS total_sales_num,
        COUNT(DISTINCT shop_id) AS shop_count,
        SUM(sales_money IS NOT NULL) AS money_valid_rows,
        SUM(sales_num IS NOT NULL) AS num_valid_rows
    FROM dwd_sales_detail_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
    GROUP BY month_id, platform_id
), previous_period AS (
    SELECT
        m.*,
        LAG(month_id) OVER (PARTITION BY platform_id ORDER BY month_id) AS previous_month,
        LAG(total_sales_rmb) OVER (PARTITION BY platform_id ORDER BY month_id) AS previous_sales
    FROM monthly m
)
SELECT
    month_id, platform_id, platform_name,
    total_sales_rmb, total_sales_num, shop_count,
    money_valid_rows, num_valid_rows,
    CASE WHEN PERIOD_DIFF(month_id, previous_month) = 1
         THEN previous_sales ELSE NULL END AS last_sales_rmb,
    CASE WHEN PERIOD_DIFF(month_id, previous_month) <> 1
              OR previous_sales IS NULL OR previous_sales = 0
              OR total_sales_rmb IS NULL
         THEN NULL
         ELSE ROUND((total_sales_rmb - previous_sales) / previous_sales * 100, 4)
    END AS mom_growth_pct
FROM previous_period;

SELECT *
FROM dws_platform_month_summary_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
ORDER BY month_id, platform_id;

