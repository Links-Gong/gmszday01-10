SET NAMES utf8mb4;
USE ec_cross_ceshi;

DELETE FROM dws_region_month_summary_2026_gj
WHERE month_id BETWEEN 202601 AND 202606;

INSERT INTO dws_region_month_summary_2026_gj (
    month_id, platform_id, platform_name,
    province, city, county, region_level,
    total_sales_rmb, total_sales_num, shop_count,
    money_valid_rows, num_valid_rows
)
WITH normalized AS (
    SELECT
        month_id,
        platform_id,
        platform_name,
        COALESCE(NULLIF(TRIM(province), ''), '未知省份') AS province,
        COALESCE(NULLIF(TRIM(city), ''), '未知城市') AS city,
        COALESCE(NULLIF(TRIM(county), ''), '未知区县') AS county,
        shop_id,
        sales_money,
        sales_num
    FROM dwd_sales_detail_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
)
SELECT
    month_id,
    platform_id,
    platform_name,
    CASE WHEN GROUPING(province) = 1 THEN '全国合计' ELSE province END,
    CASE WHEN GROUPING(province) = 1 THEN '全部城市'
         WHEN GROUPING(city) = 1 THEN '全省小计'
         ELSE city END,
    CASE WHEN GROUPING(province) = 1 THEN '全部区县'
         WHEN GROUPING(city) = 1 THEN '全部区县'
         WHEN GROUPING(county) = 1 THEN '全市小计'
         ELSE county END,
    CASE WHEN GROUPING(province) = 1 THEN '全国'
         WHEN GROUPING(city) = 1 THEN '省级'
         WHEN GROUPING(county) = 1 THEN '市级'
         ELSE '区县级' END,
    SUM(sales_money),
    SUM(sales_num),
    COUNT(DISTINCT shop_id),
    SUM(sales_money IS NOT NULL),
    SUM(sales_num IS NOT NULL)
FROM normalized
GROUP BY month_id, platform_id, platform_name, province, city, county WITH ROLLUP
HAVING GROUPING(month_id) = 0
   AND GROUPING(platform_id) = 0
   AND GROUPING(platform_name) = 0;

SELECT month_id, platform_id, platform_name, province, city, county,
       region_level, total_sales_rmb, total_sales_num, shop_count
FROM dws_region_month_summary_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
ORDER BY month_id, platform_id,
         FIELD(region_level, '全国', '省级', '市级', '区县级'),
         province, city, county
LIMIT 500;

