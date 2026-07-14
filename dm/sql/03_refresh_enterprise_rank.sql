SET NAMES utf8mb4;
USE ec_cross_ceshi;

DELETE FROM dm_enterprise_sales_rank_2026_gj
WHERE month_id BETWEEN 202601 AND 202606;

INSERT INTO dm_enterprise_sales_rank_2026_gj (
    month_id, platform_id, platform_name, company_name,
    total_sales_rmb, total_sales_num, shop_count, enterprise_rank
)
WITH enterprise_summary AS (
    SELECT
        month_id,
        platform_id,
        MAX(platform_name) AS platform_name,
        COALESCE(
            NULLIF(TRIM(company_name), ''),
            CONCAT('未知企业-P', platform_id, '-', shop_id)
        ) AS company_name,
        SUM(sales_money) AS total_sales_rmb,
        SUM(sales_num) AS total_sales_num,
        COUNT(DISTINCT shop_id) AS shop_count
    FROM dwd_sales_detail_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
    GROUP BY month_id, platform_id,
             COALESCE(NULLIF(TRIM(company_name), ''),
                      CONCAT('未知企业-P', platform_id, '-', shop_id))
), ranked AS (
    SELECT
        e.*,
        RANK() OVER (
            PARTITION BY month_id, platform_id
            ORDER BY total_sales_rmb IS NULL,
                     total_sales_rmb DESC
        ) AS enterprise_rank
    FROM enterprise_summary e
)
SELECT
    month_id, platform_id, platform_name, company_name,
    total_sales_rmb, total_sales_num, shop_count, enterprise_rank
FROM ranked;

SELECT *
FROM dm_enterprise_sales_rank_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
  AND enterprise_rank <= 20
ORDER BY month_id, platform_id, enterprise_rank, company_name;
