SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- Day9 summary. This script is read-only and does not rebuild any table.
-- The DWD row-count contract is the cleaned shop-month grain, not raw rows.
WITH checks AS (
    SELECT
        'DWD-01' AS check_id,
        'DWD' AS layer,
        '2025 load batches succeeded' AS check_name,
        24 AS expected_value,
        SUM(status = 'SUCCESS') AS actual_value,
        SUM(status = 'SUCCESS') - 24 AS difference_value,
        CASE WHEN COUNT(*) = 24
                  AND SUM(status = 'SUCCESS') = 24
                  AND SUM(ABS(COALESCE(target_sales_money_rmb, 0)
                              - COALESCE(staged_sales_money_rmb, 0)) > 0.005) = 0
             THEN 'PASS' ELSE 'FAIL' END AS status,
        'All 202501-202506 platform batches must be committed' AS note
    FROM etl_load_audit_2025_gj

    UNION ALL
    SELECT 'DWD-02', 'DWD', '2026 load batches succeeded', 24,
           SUM(status = 'SUCCESS'), SUM(status = 'SUCCESS') - 24,
           CASE WHEN COUNT(*) = 24
                     AND SUM(status = 'SUCCESS') = 24
                     AND SUM(ABS(COALESCE(target_sales_money_rmb, 0)
                                 - COALESCE(staged_sales_money_rmb, 0)) > 0.005) = 0
                THEN 'PASS' ELSE 'FAIL' END,
           'All 202601-202606 platform batches must be committed'
    FROM etl_load_audit_2026_gj

    UNION ALL
    SELECT 'DWD-03', 'DWD', '2025 DWD rows equal audited target',
           SUM(target_row_count),
           (SELECT COUNT(*) FROM dwd_sales_detail_2025_gj
             WHERE month_id BETWEEN 202501 AND 202506),
           (SELECT COUNT(*) FROM dwd_sales_detail_2025_gj
             WHERE month_id BETWEEN 202501 AND 202506) - SUM(target_row_count),
           CASE WHEN SUM(target_row_count) =
                          (SELECT COUNT(*) FROM dwd_sales_detail_2025_gj
                            WHERE month_id BETWEEN 202501 AND 202506)
                THEN 'PASS' ELSE 'FAIL' END,
           'Target rows equal cleaned valid shop-month rows'
    FROM etl_load_audit_2025_gj WHERE status = 'SUCCESS'

    UNION ALL
    SELECT 'DWD-04', 'DWD', '2026 DWD rows equal audited target',
           SUM(target_row_count),
           (SELECT COUNT(*) FROM dwd_sales_detail_2026_gj
             WHERE month_id BETWEEN 202601 AND 202606),
           (SELECT COUNT(*) FROM dwd_sales_detail_2026_gj
             WHERE month_id BETWEEN 202601 AND 202606) - SUM(target_row_count),
           CASE WHEN SUM(target_row_count) =
                          (SELECT COUNT(*) FROM dwd_sales_detail_2026_gj
                            WHERE month_id BETWEEN 202601 AND 202606)
                THEN 'PASS' ELSE 'FAIL' END,
           'Target rows equal cleaned valid shop-month rows'
    FROM etl_load_audit_2026_gj WHERE status = 'SUCCESS'

    UNION ALL
    SELECT 'DWD-05', 'DWD', 'DWD month-platform groups', 48,
           (SELECT COUNT(*) FROM (
                SELECT month_id, platform_id FROM dwd_sales_detail_2025_gj
                 WHERE month_id BETWEEN 202501 AND 202506
                 GROUP BY month_id, platform_id
                UNION ALL
                SELECT month_id, platform_id FROM dwd_sales_detail_2026_gj
                 WHERE month_id BETWEEN 202601 AND 202606
                 GROUP BY month_id, platform_id
            ) g),
           (SELECT COUNT(*) FROM (
                SELECT month_id, platform_id FROM dwd_sales_detail_2025_gj
                 WHERE month_id BETWEEN 202501 AND 202506
                 GROUP BY month_id, platform_id
                UNION ALL
                SELECT month_id, platform_id FROM dwd_sales_detail_2026_gj
                 WHERE month_id BETWEEN 202601 AND 202606
                 GROUP BY month_id, platform_id
            ) g) - 48,
           CASE WHEN (SELECT COUNT(*) FROM (
                SELECT month_id, platform_id FROM dwd_sales_detail_2025_gj
                 WHERE month_id BETWEEN 202501 AND 202506 GROUP BY month_id, platform_id
                UNION ALL
                SELECT month_id, platform_id FROM dwd_sales_detail_2026_gj
                 WHERE month_id BETWEEN 202601 AND 202606 GROUP BY month_id, platform_id
           ) g) = 48 THEN 'PASS' ELSE 'FAIL' END,
           'Six months times four platforms for each year'

    UNION ALL
    SELECT 'DWD-06', 'DWD', 'Formal DWD empty shop IDs', 0,
           (SELECT COUNT(*) FROM dwd_sales_detail_2025_gj
             WHERE shop_id IS NULL OR TRIM(shop_id) = '')
           +
           (SELECT COUNT(*) FROM dwd_sales_detail_2026_gj
             WHERE shop_id IS NULL OR TRIM(shop_id) = ''),
           (SELECT COUNT(*) FROM dwd_sales_detail_2025_gj
             WHERE shop_id IS NULL OR TRIM(shop_id) = '')
           +
           (SELECT COUNT(*) FROM dwd_sales_detail_2026_gj
             WHERE shop_id IS NULL OR TRIM(shop_id) = ''),
           CASE WHEN
               (SELECT COUNT(*) FROM dwd_sales_detail_2025_gj
                 WHERE shop_id IS NULL OR TRIM(shop_id) = '')
               +
               (SELECT COUNT(*) FROM dwd_sales_detail_2026_gj
                 WHERE shop_id IS NULL OR TRIM(shop_id) = '') = 0
           THEN 'PASS' ELSE 'FAIL' END,
           'Empty shop IDs remain only in audit statistics'

    UNION ALL
    SELECT 'DWD-07', 'DWD', 'DWD shop-month uniqueness', 0,
           COUNT(*), COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
           'No duplicate month_id + platform_id + shop_id keys in either year'
    FROM (
        SELECT month_id, platform_id, shop_id
        FROM dwd_sales_detail_2025_gj
        WHERE month_id BETWEEN 202501 AND 202506
        GROUP BY month_id, platform_id, shop_id
        HAVING COUNT(*) > 1
        UNION ALL
        SELECT month_id, platform_id, shop_id
        FROM dwd_sales_detail_2026_gj
        WHERE month_id BETWEEN 202601 AND 202606
        GROUP BY month_id, platform_id, shop_id
        HAVING COUNT(*) > 1
    ) duplicate_shop

    UNION ALL
    SELECT 'DWS-01', 'DWS', '2025 platform-month rows', 24, COUNT(*), COUNT(*) - 24,
           CASE WHEN COUNT(*) = 24 THEN 'PASS' ELSE 'FAIL' END,
           'Baseline summary has six months and four platforms'
    FROM dws_platform_month_summary_2025_gj
    WHERE month_id BETWEEN 202501 AND 202506

    UNION ALL
    SELECT 'DWS-02', 'DWS', '2026 platform-month rows', 24, COUNT(*), COUNT(*) - 24,
           CASE WHEN COUNT(*) = 24 THEN 'PASS' ELSE 'FAIL' END,
           'Business summary has six months and four platforms'
    FROM dws_platform_month_summary_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606

    UNION ALL
    SELECT 'DWS-03', 'DWS', '2026 platform totals reconcile to DWD', 0,
           SUM(ABS(p.total_sales_rmb - d.dwd_money) > 0.01
               OR ABS(p.total_sales_num - d.dwd_num) > 0.0001
               OR p.shop_count <> d.dwd_shops),
           SUM(ABS(p.total_sales_rmb - d.dwd_money) > 0.01
               OR ABS(p.total_sales_num - d.dwd_num) > 0.0001
               OR p.shop_count <> d.dwd_shops),
           CASE WHEN SUM(ABS(p.total_sales_rmb - d.dwd_money) > 0.01
                         OR ABS(p.total_sales_num - d.dwd_num) > 0.0001
                         OR p.shop_count <> d.dwd_shops) = 0
                THEN 'PASS' ELSE 'FAIL' END,
           'Money, volume and shop count are checked per platform-month'
    FROM dws_platform_month_summary_2026_gj p
    JOIN (
        SELECT month_id, platform_id, SUM(sales_money) AS dwd_money,
               SUM(sales_num) AS dwd_num, COUNT(*) AS dwd_shops
        FROM dwd_sales_detail_2026_gj
        WHERE month_id BETWEEN 202601 AND 202606
        GROUP BY month_id, platform_id
    ) d USING (month_id, platform_id)

    UNION ALL
    SELECT 'DWS-04', 'DWS', 'National region totals reconcile', 0,
           SUM(ABS(r.total_sales_rmb - p.total_sales_rmb) > 0.01
               OR ABS(r.total_sales_num - p.total_sales_num) > 0.0001
               OR r.shop_count <> p.shop_count),
           SUM(ABS(r.total_sales_rmb - p.total_sales_rmb) > 0.01
               OR ABS(r.total_sales_num - p.total_sales_num) > 0.0001
               OR r.shop_count <> p.shop_count),
           CASE WHEN SUM(ABS(r.total_sales_rmb - p.total_sales_rmb) > 0.01
                         OR ABS(r.total_sales_num - p.total_sales_num) > 0.0001
                         OR r.shop_count <> p.shop_count) = 0
                THEN 'PASS' ELSE 'FAIL' END,
           'Only region_level=National is compared with platform totals'
    FROM dws_platform_month_summary_2026_gj p
    JOIN dws_region_month_summary_2026_gj r
      ON r.month_id = p.month_id AND r.platform_id = p.platform_id
     AND r.region_level = '全国'
    WHERE p.month_id BETWEEN 202601 AND 202606

    UNION ALL
    SELECT 'DWS-05', 'DWS', 'Category totals reconcile', 0,
           SUM(ABS(c.category_money - p.total_sales_rmb) > 0.01
               OR ABS(c.category_num - p.total_sales_num) > 0.0001),
           SUM(ABS(c.category_money - p.total_sales_rmb) > 0.01
               OR ABS(c.category_num - p.total_sales_num) > 0.0001),
           CASE WHEN SUM(ABS(c.category_money - p.total_sales_rmb) > 0.01
                         OR ABS(c.category_num - p.total_sales_num) > 0.0001) = 0
                THEN 'PASS' ELSE 'FAIL' END,
           'Unclassified rows are retained in the category base summary'
    FROM dws_platform_month_summary_2026_gj p
    JOIN (
        SELECT month_id, platform_id, SUM(total_sales_rmb) AS category_money,
               SUM(total_sales_num) AS category_num
        FROM dws_category_month_summary_2026_gj
        WHERE month_id BETWEEN 202601 AND 202606
        GROUP BY month_id, platform_id
    ) c USING (month_id, platform_id)

    UNION ALL
    SELECT 'DWS-06', 'DWS', 'January month-over-month baseline is NULL', 0,
           COUNT(*), COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
           '202601 has no previous month inside the 2026 result set'
    FROM dws_platform_month_summary_2026_gj
    WHERE month_id = 202601
      AND (last_sales_rmb IS NOT NULL OR mom_growth_pct IS NOT NULL)

    UNION ALL
    SELECT 'DWS-07', 'DWS', 'Category TOP10 ranks valid', 0, COUNT(*), COUNT(*),
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Each platform-month rank is between 1 and 10 and not duplicated'
    FROM (
        SELECT month_id, platform_id, category_rank
        FROM dws_category_month_top10_2026_gj
        WHERE month_id BETWEEN 202601 AND 202606
        GROUP BY month_id, platform_id, category_rank
        HAVING COUNT(*) > 1 OR category_rank NOT BETWEEN 1 AND 10
    ) bad_rank

    UNION ALL
    SELECT 'DWS-08', 'DWS', '2025 platform totals reconcile to DWD', 0,
           SUM(ABS(p.total_sales_rmb - d.dwd_money) > 0.01
               OR ABS(p.total_sales_num - d.dwd_num) > 0.0001
               OR p.shop_count <> d.dwd_shops),
           SUM(ABS(p.total_sales_rmb - d.dwd_money) > 0.01
               OR ABS(p.total_sales_num - d.dwd_num) > 0.0001
               OR p.shop_count <> d.dwd_shops),
           CASE WHEN SUM(ABS(p.total_sales_rmb - d.dwd_money) > 0.01
                         OR ABS(p.total_sales_num - d.dwd_num) > 0.0001
                         OR p.shop_count <> d.dwd_shops) = 0
                THEN 'PASS' ELSE 'FAIL' END,
           'Baseline money, volume and shop count are checked per platform-month'
    FROM dws_platform_month_summary_2025_gj p
    JOIN (
        SELECT month_id, platform_id, SUM(sales_money) AS dwd_money,
               SUM(sales_num) AS dwd_num, COUNT(*) AS dwd_shops
        FROM dwd_sales_detail_2025_gj
        WHERE month_id BETWEEN 202501 AND 202506
        GROUP BY month_id, platform_id
    ) d USING (month_id, platform_id)

    UNION ALL
    SELECT 'DM-01', 'DM', 'Monthly business metric rows', 24, COUNT(*), COUNT(*) - 24,
           CASE WHEN COUNT(*) = 24 THEN 'PASS' ELSE 'FAIL' END,
           'Six months times four platforms'
    FROM dm_monthly_business_metrics_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606

    UNION ALL
    SELECT 'DM-02', 'DM', 'Express formulas valid', 0,
           SUM(ABS(express_revenue_rmb - ROUND(retail_sales_rmb * 0.15, 2)) > 0.01
               OR ABS(express_volume - ROUND(retail_sales_num * 0.53, 4)) > 0.0001),
           SUM(ABS(express_revenue_rmb - ROUND(retail_sales_rmb * 0.15, 2)) > 0.01
               OR ABS(express_volume - ROUND(retail_sales_num * 0.53, 4)) > 0.0001),
           CASE WHEN SUM(ABS(express_revenue_rmb - ROUND(retail_sales_rmb * 0.15, 2)) > 0.01
                         OR ABS(express_volume - ROUND(retail_sales_num * 0.53, 4)) > 0.0001) = 0
                THEN 'PASS' ELSE 'FAIL' END,
           'Revenue=retail*15%; volume=sales number*53%'
    FROM dm_monthly_business_metrics_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606

    UNION ALL
    SELECT 'DM-03', 'DM', 'Year-over-year metrics calculated', 24,
           SUM(yoy_status = 'CALCULATED'), SUM(yoy_status = 'CALCULATED') - 24,
           CASE WHEN COUNT(*) = 24 AND SUM(yoy_status = 'CALCULATED') = 24
                     AND SUM(ABS(yoy_growth_pct - ROUND(
                         (retail_sales_rmb - last_year_sales_rmb)
                         / NULLIF(last_year_sales_rmb, 0) * 100, 4)) > 0.0001) = 0
                THEN 'PASS' ELSE 'FAIL' END,
           'Each 2026 month is joined to the same 2025 month'
    FROM dm_monthly_business_metrics_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606

    UNION ALL
    SELECT 'DM-04', 'DM', 'Manual YoY: 202601 SMT', -15.4042,
           yoy_growth_pct, yoy_growth_pct - (-15.4042),
           CASE WHEN ABS(yoy_growth_pct - (-15.4042)) <= 0.0001
                THEN 'PASS' ELSE 'FAIL' END,
           'Recomputed from 7457153513.54 and 8815040918.60'
    FROM dm_monthly_business_metrics_2026_gj
    WHERE month_id = 202601 AND platform_id = 1

    UNION ALL
    SELECT 'DM-05', 'DM', 'Enterprise rank contains data', 1,
           COUNT(*) > 0, (COUNT(*) > 0) - 1,
           CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END,
           CONCAT('Actual enterprise rank rows: ', COUNT(*))
    FROM dm_enterprise_sales_rank_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606

    UNION ALL
    SELECT 'DM-06', 'DM', 'Enterprise rank grain is unique', 0,
           COUNT(*), COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
           'No duplicate month_id + platform_id + company_name groups'
    FROM (
        SELECT month_id, platform_id, company_name
        FROM dm_enterprise_sales_rank_2026_gj
        WHERE month_id BETWEEN 202601 AND 202606
        GROUP BY month_id, platform_id, company_name
        HAVING COUNT(*) > 1
    ) duplicate_enterprise
)
SELECT
    check_id,
    layer,
    check_name,
    CAST(expected_value AS CHAR) AS expected_value,
    CAST(actual_value AS CHAR) AS actual_value,
    CAST(difference_value AS CHAR) AS difference_value,
    status,
    CURRENT_TIMESTAMP AS checked_at,
    note
FROM checks
ORDER BY check_id;

-- Detail 1: raw-to-DWD row bridge. The difference is expected and explained.
SELECT
    2025 AS data_year, month_id, platform_id, platform_name,
    source_row_count, empty_shop_id_count, valid_shop_count,
    target_row_count,
    source_row_count - empty_shop_id_count - target_row_count AS deduplicated_or_collapsed_rows,
    target_sales_money_rmb - staged_sales_money_rmb AS money_difference,
    status
FROM etl_load_audit_2025_gj
UNION ALL
SELECT
    2026, month_id, platform_id, platform_name,
    source_row_count, empty_shop_id_count, valid_shop_count,
    target_row_count,
    source_row_count - empty_shop_id_count - target_row_count,
    target_sales_money_rmb - staged_sales_money_rmb,
    status
FROM etl_load_audit_2026_gj
ORDER BY data_year, month_id, platform_id;

-- Detail 2: DWS platform reconciliation for both years.
WITH dwd AS (
    SELECT 2025 AS data_year, month_id, platform_id,
           SUM(sales_money) AS dwd_money, SUM(sales_num) AS dwd_num,
           COUNT(*) AS dwd_shop_count
    FROM dwd_sales_detail_2025_gj
    WHERE month_id BETWEEN 202501 AND 202506
    GROUP BY month_id, platform_id
    UNION ALL
    SELECT 2026, month_id, platform_id,
           SUM(sales_money), SUM(sales_num), COUNT(*)
    FROM dwd_sales_detail_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
    GROUP BY month_id, platform_id
), dws AS (
    SELECT 2025 AS data_year, month_id, platform_id, platform_name,
           total_sales_rmb, total_sales_num, shop_count
    FROM dws_platform_month_summary_2025_gj
    WHERE month_id BETWEEN 202501 AND 202506
    UNION ALL
    SELECT 2026, month_id, platform_id, platform_name,
           total_sales_rmb, total_sales_num, shop_count
    FROM dws_platform_month_summary_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
)
SELECT dws.data_year, dws.month_id, dws.platform_id, dws.platform_name,
       dws.total_sales_rmb - dwd.dwd_money AS money_difference,
       dws.total_sales_num - dwd.dwd_num AS num_difference,
       dws.shop_count - dwd.dwd_shop_count AS shop_difference
FROM dws JOIN dwd USING (data_year, month_id, platform_id)
ORDER BY data_year, month_id, platform_id;

-- Detail 3: DM formula and YoY evidence.
SELECT
    month_id, platform_id, platform_name,
    retail_sales_rmb, previous_month_sales_rmb, mom_growth_pct,
    last_year_sales_rmb, yoy_growth_pct, yoy_status,
    express_revenue_rmb - ROUND(retail_sales_rmb * 0.15, 2) AS revenue_difference,
    express_volume - ROUND(retail_sales_num * 0.53, 4) AS volume_difference,
    yoy_growth_pct - ROUND(
        (retail_sales_rmb - last_year_sales_rmb)
        / NULLIF(last_year_sales_rmb, 0) * 100, 4
    ) AS yoy_difference
FROM dm_monthly_business_metrics_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
ORDER BY month_id, platform_id;

-- Detail 4: small enterprise-rank sample only.
SELECT month_id, platform_id, platform_name, company_name,
       total_sales_rmb, total_sales_num, shop_count, enterprise_rank
FROM dm_enterprise_sales_rank_2026_gj
WHERE month_id IN (202601, 202606)
  AND enterprise_rank <= 5
ORDER BY month_id, platform_id, enterprise_rank, company_name;

-- Detail 5: data-quality facts. NULL and true zero remain separate.
SELECT
    2025 AS data_year, month_id, platform_id, platform_name,
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
FROM dwd_sales_detail_2025_gj
WHERE month_id BETWEEN 202501 AND 202506
GROUP BY month_id, platform_id, platform_name
UNION ALL
SELECT
    2026, month_id, platform_id, platform_name,
    COUNT(*),
    SUM(invalid_sales_num_count), SUM(invalid_sales_money_count),
    SUM(sales_num IS NULL), SUM(sales_num = 0),
    SUM(sales_money IS NULL), SUM(sales_money = 0),
    SUM(dim_match_flag = 1),
    ROUND(SUM(dim_match_flag = 1) / NULLIF(COUNT(*), 0) * 100, 4),
    SUM(province IS NULL OR TRIM(province) = ''),
    SUM(city IS NULL OR TRIM(city) = ''),
    SUM(county IS NULL OR TRIM(county) = '')
FROM dwd_sales_detail_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
GROUP BY month_id, platform_id, platform_name
ORDER BY data_year, month_id, platform_id;
