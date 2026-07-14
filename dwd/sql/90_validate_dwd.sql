SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- Must return 24 SUCCESS rows.
SELECT month_id, platform_id, platform_name, source_table,
       source_row_count, empty_shop_id_count, valid_shop_count,
       staged_row_count, target_row_count,
       staged_sales_money_rmb, target_sales_money_rmb,
       target_sales_money_rmb - staged_sales_money_rmb AS money_difference,
       status, started_time, completed_time
FROM etl_load_audit_2026_gj
ORDER BY month_id, platform_id;

-- Must return six months and four platforms per month.
SELECT month_id, platform_id, platform_name,
       COUNT(*) AS dwd_rows,
       SUM(source_row_count) AS deduplicated_source_rows,
       SUM(sales_money) AS total_sales_rmb,
       SUM(sales_num) AS total_sales_num
FROM dwd_sales_detail_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
GROUP BY month_id, platform_id, platform_name
ORDER BY month_id, platform_id;

-- Must return zero rows.
SELECT month_id, platform_id, shop_id, COUNT(*) AS duplicate_count
FROM dwd_sales_detail_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
GROUP BY month_id, platform_id, shop_id
HAVING COUNT(*) > 1;

-- Data-quality output. NULL and real zero are reported separately.
SELECT
    month_id,
    platform_id,
    platform_name,
    COUNT(*) AS row_count,
    SUM(invalid_sales_num_count) AS invalid_sales_num_count,
    SUM(invalid_sales_money_count) AS invalid_sales_money_count,
    SUM(sales_num IS NULL) AS null_sales_num_rows,
    SUM(sales_num = 0) AS zero_sales_num_rows,
    SUM(sales_money IS NULL) AS null_sales_money_rows,
    SUM(sales_money = 0) AS zero_sales_money_rows,
    SUM(dim_match_flag = 1) AS dim_matched_rows,
    ROUND(SUM(dim_match_flag = 1) / NULLIF(COUNT(*), 0) * 100, 4) AS dim_match_pct,
    SUM(province IS NULL OR TRIM(province) = '') AS missing_province_rows,
    SUM(city IS NULL OR TRIM(city) = '') AS missing_city_rows,
    SUM(county IS NULL OR TRIM(county) = '') AS missing_county_rows
FROM dwd_sales_detail_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
GROUP BY month_id, platform_id, platform_name
ORDER BY month_id, platform_id;

-- DWD total must equal successful audit target total.
SELECT
    (SELECT COUNT(*) FROM dwd_sales_detail_2026_gj
      WHERE month_id BETWEEN 202601 AND 202606) AS actual_dwd_rows,
    (SELECT SUM(target_row_count) FROM etl_load_audit_2026_gj
      WHERE month_id BETWEEN 202601 AND 202606 AND status = 'SUCCESS') AS audited_target_rows;

