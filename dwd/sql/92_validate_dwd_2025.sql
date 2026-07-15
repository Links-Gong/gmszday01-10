SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- Must return 24 SUCCESS rows.
SELECT month_id, platform_id, platform_name, source_table,
       source_row_count, empty_shop_id_count, valid_shop_count,
       staged_row_count, target_row_count,
       staged_sales_money_rmb, target_sales_money_rmb,
       target_sales_money_rmb - staged_sales_money_rmb AS money_difference,
       status, started_time, completed_time
FROM etl_load_audit_2025_gj
ORDER BY month_id, platform_id;

-- Must return six months and four platforms per month.
SELECT month_id, platform_id, platform_name,
       COUNT(*) AS dwd_rows,
       SUM(source_row_count) AS deduplicated_source_rows,
       SUM(sales_money) AS total_sales_rmb,
       SUM(sales_num) AS total_sales_num
FROM dwd_sales_detail_2025_gj
WHERE month_id BETWEEN 202501 AND 202506
GROUP BY month_id, platform_id, platform_name
ORDER BY month_id, platform_id;

-- Must return zero rows.
SELECT month_id, platform_id, shop_id, COUNT(*) AS duplicate_count
FROM dwd_sales_detail_2025_gj
WHERE month_id BETWEEN 202501 AND 202506
GROUP BY month_id, platform_id, shop_id
HAVING COUNT(*) > 1;

-- DWD total must equal successful audit target total.
SELECT
    (SELECT COUNT(*) FROM dwd_sales_detail_2025_gj
      WHERE month_id BETWEEN 202501 AND 202506) AS actual_dwd_rows,
    (SELECT SUM(target_row_count) FROM etl_load_audit_2025_gj
      WHERE month_id BETWEEN 202501 AND 202506
        AND status = 'SUCCESS') AS audited_target_rows;
