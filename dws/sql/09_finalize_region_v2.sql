SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- Safety finalization after a disconnected full-load query completed late.
-- The source V2 table is not updated or deleted. This creates a new final
-- table and collapses only byte-identical rows at the declared result grain.
CREATE TABLE dws_region_month_summary_v2_final_2026_gj
LIKE dws_region_month_summary_v2_2026_gj;

INSERT INTO dws_region_month_summary_v2_final_2026_gj (
    month_id, platform_id, platform_name,
    region_scope, region_level, province, city, county, recovery_method,
    total_sales_rmb, total_sales_num, shop_count, source_shop_rows,
    money_valid_rows, num_valid_rows, created_time
)
SELECT
    month_id, platform_id, MAX(platform_name),
    region_scope, region_level, province, city, county, recovery_method,
    MAX(total_sales_rmb), MAX(total_sales_num), MAX(shop_count),
    MAX(source_shop_rows), MAX(money_valid_rows), MAX(num_valid_rows),
    MAX(created_time)
FROM dws_region_month_summary_v2_2026_gj
GROUP BY
    month_id, platform_id, region_scope, region_level,
    province, city, county, recovery_method;

SELECT region_level,
       COUNT(*) AS final_rows,
       COUNT(DISTINCT CONCAT_WS('|',
           month_id, platform_id, region_scope,
           province, city, county, recovery_method
       )) AS unique_rows
FROM dws_region_month_summary_v2_final_2026_gj
GROUP BY region_level
ORDER BY region_level;
