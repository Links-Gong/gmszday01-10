SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- 1. Standard hierarchy and evidence-map integrity.
SELECT 'standard_region_rows' AS check_name, COUNT(*) AS actual_value
FROM dim_region_standard_2026_gj
UNION ALL
SELECT 'duplicate_region_codes', COUNT(*)
FROM (
    SELECT region_code
    FROM dim_region_standard_2026_gj
    GROUP BY region_code
    HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'invalid_recovery_map_rows', COUNT(*)
FROM dws_region_recovery_map_2026_gj
WHERE match_key IS NULL OR match_key = ''
   OR match_key_hash IS NULL
   OR confidence_level <> 'HIGH'
   OR region_scope NOT IN ('DOMESTIC', 'OVERSEAS', 'SPECIAL_REGION');

-- 2. The 24 month-platform totals must remain identical to DWD.
WITH dwd AS (
    SELECT month_id, platform_id,
           SUM(sales_money) AS sales_money,
           SUM(sales_num) AS sales_num,
           COUNT(*) AS shop_count
    FROM dwd_sales_detail_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
    GROUP BY month_id, platform_id
),
v2 AS (
    SELECT month_id, platform_id,
           SUM(total_sales_rmb) AS sales_money,
           SUM(total_sales_num) AS sales_num,
           SUM(shop_count) AS shop_count
    FROM dws_region_month_summary_v2_final_2026_gj
    WHERE region_level = '全国'
    GROUP BY month_id, platform_id
)
SELECT
    d.month_id, d.platform_id,
    d.sales_money AS dwd_sales_money,
    v.sales_money AS v2_sales_money,
    ROUND(COALESCE(v.sales_money, 0) - COALESCE(d.sales_money, 0), 2)
        AS money_difference,
    d.sales_num AS dwd_sales_num,
    v.sales_num AS v2_sales_num,
    ROUND(COALESCE(v.sales_num, 0) - COALESCE(d.sales_num, 0), 4)
        AS num_difference,
    d.shop_count AS dwd_shop_count,
    v.shop_count AS v2_shop_count,
    v.shop_count - d.shop_count AS shop_difference,
    CASE
        WHEN ABS(COALESCE(v.sales_money, 0) - COALESCE(d.sales_money, 0)) <= 0.01
         AND ABS(COALESCE(v.sales_num, 0) - COALESCE(d.sales_num, 0)) <= 0.0001
         AND v.shop_count = d.shop_count
        THEN 'PASS' ELSE 'FAIL'
    END AS status
FROM dwd d
LEFT JOIN v2 v
  ON v.month_id = d.month_id AND v.platform_id = d.platform_id
ORDER BY d.month_id, d.platform_id;

-- 3. Coverage by scope and recovery method. This is the audit basis for the
-- four dashboard quality indicators.
SELECT
    region_scope,
    recovery_method,
    SUM(source_shop_rows) AS source_shop_rows,
    SUM(total_sales_rmb) AS total_sales_rmb,
    ROUND(
        SUM(total_sales_rmb)
        / NULLIF((
            SELECT SUM(total_sales_rmb)
            FROM dws_region_month_summary_v2_final_2026_gj
            WHERE region_level = '全国'
        ), 0) * 100,
        4
    ) AS sales_pct
FROM dws_region_month_summary_v2_final_2026_gj
WHERE region_level = '全国'
GROUP BY region_scope, recovery_method
ORDER BY region_scope, recovery_method;

-- 4. Before/after county-location coverage at the same county-level grain.
SELECT
    'before' AS version,
    SUM(total_sales_rmb) AS total_sales_rmb,
    SUM(CASE
        WHEN province NOT IN ('未知省份', '全国合计')
         AND city NOT IN ('未知城市', '全部城市', '全省小计')
         AND county NOT IN ('未知区县', '全部区县', '全市小计')
        THEN total_sales_rmb ELSE 0 END) AS located_county_sales_rmb
FROM dws_region_month_summary_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
  AND region_level = '区县级'
UNION ALL
SELECT
    'after',
    SUM(total_sales_rmb),
    SUM(CASE
        WHEN region_scope = 'DOMESTIC'
         AND province <> '未知省份'
         AND city <> '未知城市'
         AND county NOT IN ('未知区县', '不适用')
        THEN total_sales_rmb ELSE 0 END)
FROM dws_region_month_summary_v2_final_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
  AND region_level = '区县级';

-- 5. The query used by the dashboard must never return an unknown or
-- non-applicable county in the ranking.
SELECT province, city, county,
       SUM(total_sales_rmb) AS total_sales_rmb
FROM dws_region_month_summary_v2_final_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
  AND region_level = '区县级'
  AND region_scope = 'DOMESTIC'
  AND province <> '未知省份'
  AND city <> '未知城市'
  AND county NOT IN ('未知区县', '不适用')
GROUP BY province, city, county
ORDER BY total_sales_rmb DESC
LIMIT 15;

-- 6. Representative hierarchy corrections.
SELECT map_type, match_key,
       resolved_province, resolved_city, resolved_county,
       confidence_level
FROM dws_region_recovery_map_2026_gj
WHERE map_type = 'ADMIN_HIERARCHY'
  AND (
      match_key LIKE 'PK|广东%|宝安%'
      OR match_key LIKE 'PK|广东%|白云%'
      OR match_key LIKE 'PK|上海%|浦东%'
  )
ORDER BY match_key;

-- 7. Amazon US sales must be protected from China-region recovery.
SELECT
    (SELECT SUM(sales_money)
     FROM dwd_sales_detail_2026_gj
     WHERE month_id BETWEEN 202601 AND 202606
       AND platform_id = 2
       AND UPPER(TRIM(country)) = 'US') AS amazon_us_sales_rmb,
    (SELECT SUM(total_sales_rmb)
     FROM dws_region_month_summary_v2_final_2026_gj
     WHERE month_id BETWEEN 202601 AND 202606
       AND platform_id = 2
       AND region_level = '全国'
       AND region_scope = 'OVERSEAS') AS amazon_overseas_sales_rmb,
    (SELECT SUM(total_sales_rmb)
     FROM dws_region_month_summary_v2_final_2026_gj
     WHERE month_id BETWEEN 202601 AND 202606
       AND platform_id = 2
       AND region_level = '全国'
       AND region_scope = 'DOMESTIC'
       AND recovery_method = 'COUNTRY_SCOPE') AS amazon_domestic_country_only_rmb;
