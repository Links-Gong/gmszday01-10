SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- Build a new V2 result. No existing DWD/DWS/DM table is changed.
CREATE TABLE dws_region_month_summary_v2_2026_gj (
    month_id INT NOT NULL,
    platform_id TINYINT NOT NULL,
    platform_name VARCHAR(50) NOT NULL,
    region_scope VARCHAR(30) NOT NULL,
    region_level VARCHAR(20) NOT NULL,
    province VARCHAR(255) NOT NULL,
    city VARCHAR(255) NOT NULL,
    county VARCHAR(255) NOT NULL,
    recovery_method VARCHAR(30) NOT NULL,
    total_sales_rmb DECIMAL(38,2) NULL,
    total_sales_num DECIMAL(38,4) NULL,
    shop_count BIGINT NOT NULL,
    source_shop_rows BIGINT NOT NULL,
    money_valid_rows BIGINT NOT NULL,
    num_valid_rows BIGINT NOT NULL,
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_region_v2_filter (
        month_id, platform_id, region_scope, region_level, province, city
    ),
    KEY idx_region_v2_county (
        month_id, region_scope, region_level, county
    ),
    KEY idx_region_v2_method (month_id, platform_id, recovery_method)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='2026H1区域证据恢复后的独立V2汇总';

CREATE TEMPORARY TABLE tmp_region_resolved_2026_gj (
    month_id INT NOT NULL,
    platform_id TINYINT NOT NULL,
    platform_name VARCHAR(50) NOT NULL,
    shop_id VARCHAR(255) NOT NULL,
    region_scope VARCHAR(30) NOT NULL,
    province VARCHAR(255) NOT NULL,
    city VARCHAR(255) NOT NULL,
    county VARCHAR(255) NOT NULL,
    recovery_method VARCHAR(30) NOT NULL,
    sales_money DECIMAL(28,2) NULL,
    sales_num DECIMAL(28,4) NULL,
    KEY idx_tmp_region_rollup (
        month_id, platform_id, region_scope,
        province(100), city(100), county(100)
    ),
    KEY idx_tmp_region_method (month_id, platform_id, recovery_method)
) ENGINE=InnoDB;

INSERT INTO tmp_region_resolved_2026_gj (
    month_id, platform_id, platform_name, shop_id,
    region_scope, province, city, county, recovery_method,
    sales_money, sales_num
)
WITH normalized AS (
    SELECT
        month_id, platform_id, platform_name, shop_id,
        sales_money, sales_num,
        CASE
            WHEN country IS NULL OR UPPER(TRIM(country)) IN
                 ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL
            ELSE UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                TRIM(country), ' ', ''), CHAR(9), ''), CHAR(10), ''),
                CHAR(13), ''), CONVERT(0xC2A0 USING utf8mb4), ''))
        END AS country_key,
        CASE
            WHEN province IS NULL OR UPPER(TRIM(province)) IN
                 ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE', '未知省份') THEN NULL
            ELSE LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                TRIM(province), ' ', ''), CHAR(9), ''), CHAR(10), ''),
                CHAR(13), ''), CONVERT(0xC2A0 USING utf8mb4), ''))
        END AS province_key,
        CASE
            WHEN city IS NULL OR UPPER(TRIM(city)) IN
                 ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE', '未知城市') THEN NULL
            ELSE LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                TRIM(city), ' ', ''), CHAR(9), ''), CHAR(10), ''),
                CHAR(13), ''), CONVERT(0xC2A0 USING utf8mb4), ''))
        END AS city_key,
        CASE
            WHEN county IS NULL OR UPPER(TRIM(county)) IN
                 ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE', '未知区县') THEN NULL
            ELSE LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                TRIM(county), ' ', ''), CHAR(9), ''), CHAR(10), ''),
                CHAR(13), ''), CONVERT(0xC2A0 USING utf8mb4), ''))
        END AS county_key,
        CASE
            WHEN company_address IS NULL OR UPPER(TRIM(company_address)) IN
                 ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL
            ELSE LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                TRIM(company_address), ' ', ''), CHAR(9), ''), CHAR(10), ''),
                CHAR(13), ''), CONVERT(0xC2A0 USING utf8mb4), ''))
        END AS address_key
    FROM dwd_sales_detail_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
),
matched AS (
    SELECT n.*,
        scope_map.region_scope AS declared_scope,
        scope_map.resolved_province AS scope_province,
        scope_map.resolved_city AS scope_city,
        scope_map.resolved_county AS scope_county,
        p.resolved_province AS p_province,
        pc.resolved_province AS pc_province,
        pc.resolved_city AS pc_city,
        pc.county_applicable AS pc_county_applicable,
        pk.resolved_province AS pk_province,
        pk.resolved_city AS pk_city,
        pk.resolved_county AS pk_county,
        mis.resolved_province AS mis_province,
        mis.resolved_city AS mis_city,
        mis.resolved_county AS mis_county,
        ck.resolved_province AS ck_province,
        ck.resolved_city AS ck_city,
        ck.resolved_county AS ck_county,
        shop.resolved_province AS shop_province,
        shop.resolved_city AS shop_city,
        shop.resolved_county AS shop_county,
        shop.county_applicable AS shop_county_applicable,
        addr.resolved_province AS addr_province,
        addr.resolved_city AS addr_city,
        addr.resolved_county AS addr_county,
        addr.county_applicable AS addr_county_applicable,
        parsed.resolved_province AS parsed_province,
        parsed.resolved_city AS parsed_city,
        parsed.resolved_county AS parsed_county,
        parsed.county_applicable AS parsed_county_applicable
    FROM normalized n
    LEFT JOIN dws_region_recovery_map_2026_gj scope_map
      ON scope_map.map_type = 'COUNTRY_SCOPE' AND scope_map.platform_id = 0
     AND scope_map.match_key_hash = UNHEX(SHA2(CONCAT('COUNTRY|', n.country_key), 256))
    LEFT JOIN dws_region_recovery_map_2026_gj p
      ON p.map_type = 'ADMIN_HIERARCHY' AND p.platform_id = 0
     AND p.match_key_hash = UNHEX(SHA2(CONCAT('P|', n.province_key), 256))
    LEFT JOIN dws_region_recovery_map_2026_gj pc
      ON pc.map_type = 'ADMIN_HIERARCHY' AND pc.platform_id = 0
     AND pc.match_key_hash = UNHEX(SHA2(CONCAT('PC|', n.province_key, '|', n.city_key), 256))
    LEFT JOIN dws_region_recovery_map_2026_gj pk
      ON pk.map_type = 'ADMIN_HIERARCHY' AND pk.platform_id = 0
     AND pk.match_key_hash = UNHEX(SHA2(CONCAT('PK|', n.province_key, '|', n.county_key), 256))
    LEFT JOIN dws_region_recovery_map_2026_gj mis
      ON mis.map_type = 'ADMIN_HIERARCHY' AND mis.platform_id = 0
     AND n.county_key IS NULL
     AND mis.match_key_hash = UNHEX(SHA2(CONCAT('PK|', n.province_key, '|', n.city_key), 256))
    LEFT JOIN dws_region_recovery_map_2026_gj ck
      ON ck.map_type = 'ADMIN_HIERARCHY' AND ck.platform_id = 0
     AND ck.match_key_hash = UNHEX(SHA2(CONCAT('CK|', n.city_key, '|', n.county_key), 256))
    LEFT JOIN dws_region_recovery_map_2026_gj shop
      ON shop.map_type = 'SHOP_HISTORY' AND shop.platform_id = n.platform_id
     AND shop.match_key_hash = UNHEX(SHA2(CONCAT('SHOP|', n.shop_id), 256))
    LEFT JOIN dws_region_recovery_map_2026_gj addr
      ON addr.map_type = 'EXACT_ADDRESS' AND addr.platform_id = n.platform_id
     AND addr.match_key_hash = UNHEX(SHA2(CONCAT('ADDR|', n.address_key), 256))
    LEFT JOIN dws_region_recovery_map_2026_gj parsed
      ON parsed.map_type = 'ADDRESS_PARSE' AND parsed.platform_id = n.platform_id
     AND parsed.match_key_hash = UNHEX(SHA2(CONCAT('ADDR|', n.address_key), 256))
),
admin_stage AS (
    SELECT *,
        COALESCE(pk_province, mis_province, pc_province, ck_province, p_province)
            AS admin_province,
        COALESCE(pk_city, mis_city, pc_city, ck_city) AS admin_city,
        COALESCE(pk_county, mis_county, ck_county) AS admin_county,
        CASE
            WHEN COALESCE(pk_county, mis_county, ck_county) IS NOT NULL THEN 1
            ELSE COALESCE(pc_county_applicable, 1)
        END AS admin_county_applicable,
        CASE
            WHEN pk_province IS NOT NULL
             AND province_key IS NOT NULL AND city_key IS NOT NULL AND county_key IS NOT NULL
             AND pc_city = pk_city THEN 'ORIGINAL'
            WHEN pc_province IS NOT NULL AND county_key IS NULL AND mis_province IS NULL
                THEN 'ORIGINAL'
            WHEN COALESCE(pk_province, mis_province, pc_province, ck_province, p_province)
                 IS NOT NULL THEN 'ADMIN_HIERARCHY'
            ELSE 'UNRESOLVED'
        END AS admin_method
    FROM matched
),
shop_stage AS (
    SELECT *,
        CASE
            WHEN declared_scope IN ('OVERSEAS', 'SPECIAL_REGION') THEN 0
            WHEN shop_province IS NULL THEN 0
            WHEN admin_province IS NOT NULL AND admin_province <> shop_province THEN 0
            WHEN admin_city IS NOT NULL AND admin_city <> shop_city THEN 0
            WHEN admin_county IS NOT NULL
             AND COALESCE(admin_county, '') <> COALESCE(shop_county, '') THEN 0
            WHEN admin_province IS NULL OR admin_city IS NULL
              OR (admin_county_applicable = 1 AND admin_county IS NULL
                  AND shop_county IS NOT NULL) THEN 1
            ELSE 0
        END AS shop_used
    FROM admin_stage
),
after_shop AS (
    SELECT *,
        COALESCE(admin_province, CASE WHEN shop_used = 1 THEN shop_province END)
            AS shop_stage_province,
        COALESCE(admin_city, CASE WHEN shop_used = 1 THEN shop_city END)
            AS shop_stage_city,
        COALESCE(admin_county, CASE WHEN shop_used = 1 THEN shop_county END)
            AS shop_stage_county,
        CASE WHEN admin_city IS NULL AND shop_used = 1
             THEN shop_county_applicable ELSE admin_county_applicable END
            AS shop_stage_county_applicable
    FROM shop_stage
),
address_stage AS (
    SELECT *,
        CASE
            WHEN declared_scope IN ('OVERSEAS', 'SPECIAL_REGION') THEN 0
            WHEN addr_province IS NULL OR shop_used = 1 THEN 0
            WHEN shop_stage_province IS NOT NULL
             AND shop_stage_province <> addr_province THEN 0
            WHEN shop_stage_city IS NOT NULL AND shop_stage_city <> addr_city THEN 0
            WHEN shop_stage_county IS NOT NULL
             AND COALESCE(shop_stage_county, '') <> COALESCE(addr_county, '') THEN 0
            WHEN shop_stage_province IS NULL OR shop_stage_city IS NULL
              OR (shop_stage_county_applicable = 1 AND shop_stage_county IS NULL
                  AND addr_county IS NOT NULL) THEN 1
            ELSE 0
        END AS address_used
    FROM after_shop
),
after_address AS (
    SELECT *,
        COALESCE(shop_stage_province, CASE WHEN address_used = 1 THEN addr_province END)
            AS address_stage_province,
        COALESCE(shop_stage_city, CASE WHEN address_used = 1 THEN addr_city END)
            AS address_stage_city,
        COALESCE(shop_stage_county, CASE WHEN address_used = 1 THEN addr_county END)
            AS address_stage_county,
        CASE WHEN shop_stage_city IS NULL AND address_used = 1
             THEN addr_county_applicable ELSE shop_stage_county_applicable END
            AS address_stage_county_applicable
    FROM address_stage
),
parse_stage AS (
    SELECT *,
        CASE
            WHEN declared_scope IN ('OVERSEAS', 'SPECIAL_REGION') THEN 0
            WHEN parsed_province IS NULL OR shop_used = 1 OR address_used = 1 THEN 0
            WHEN address_stage_province IS NOT NULL
             AND address_stage_province <> parsed_province THEN 0
            WHEN address_stage_city IS NOT NULL AND address_stage_city <> parsed_city THEN 0
            WHEN address_stage_county IS NOT NULL
             AND COALESCE(address_stage_county, '') <> COALESCE(parsed_county, '') THEN 0
            WHEN address_stage_province IS NULL OR address_stage_city IS NULL
              OR (address_stage_county_applicable = 1 AND address_stage_county IS NULL
                  AND parsed_county IS NOT NULL) THEN 1
            ELSE 0
        END AS parse_used
    FROM after_address
),
resolved AS (
    SELECT *,
        COALESCE(address_stage_province,
                 CASE WHEN parse_used = 1 THEN parsed_province END) AS final_province,
        COALESCE(address_stage_city,
                 CASE WHEN parse_used = 1 THEN parsed_city END) AS final_city,
        COALESCE(address_stage_county,
                 CASE WHEN parse_used = 1 THEN parsed_county END) AS final_county,
        CASE WHEN address_stage_city IS NULL AND parse_used = 1
             THEN parsed_county_applicable ELSE address_stage_county_applicable END
            AS final_county_applicable,
        CASE
            WHEN declared_scope IN ('OVERSEAS', 'SPECIAL_REGION') THEN declared_scope
            WHEN declared_scope = 'DOMESTIC' THEN 'DOMESTIC'
            WHEN COALESCE(address_stage_province,
                          CASE WHEN parse_used = 1 THEN parsed_province END) IS NOT NULL
                THEN 'DOMESTIC'
            ELSE 'UNKNOWN_SCOPE'
        END AS final_scope,
        CASE
            WHEN declared_scope IN ('OVERSEAS', 'SPECIAL_REGION') THEN 'COUNTRY_SCOPE'
            WHEN parse_used = 1 THEN 'ADDRESS_PARSE'
            WHEN address_used = 1 THEN 'EXACT_ADDRESS'
            WHEN shop_used = 1 THEN 'SHOP_HISTORY'
            WHEN admin_method <> 'UNRESOLVED' THEN admin_method
            WHEN declared_scope = 'DOMESTIC' THEN 'COUNTRY_SCOPE'
            ELSE 'UNRESOLVED'
        END AS final_method
    FROM parse_stage
)
SELECT
    month_id, platform_id, platform_name, shop_id,
    final_scope,
    CASE
        WHEN final_scope = 'OVERSEAS' THEN '境外'
        WHEN final_scope = 'SPECIAL_REGION' THEN scope_province
        WHEN final_scope = 'DOMESTIC' THEN COALESCE(final_province, '未知省份')
        ELSE '未知省份'
    END AS province,
    CASE
        WHEN final_scope IN ('OVERSEAS', 'SPECIAL_REGION')
            THEN COALESCE(scope_city, '不适用')
        WHEN final_scope = 'DOMESTIC' THEN COALESCE(final_city, '未知城市')
        ELSE '未知城市'
    END AS city,
    CASE
        WHEN final_scope IN ('OVERSEAS', 'SPECIAL_REGION') THEN '不适用'
        WHEN final_scope = 'DOMESTIC' AND final_county_applicable = 0 THEN '不适用'
        WHEN final_scope = 'DOMESTIC' THEN COALESCE(final_county, '未知区县')
        ELSE '未知区县'
    END AS county,
    final_method, sales_money, sales_num
FROM resolved;

INSERT INTO dws_region_month_summary_v2_2026_gj (
    month_id, platform_id, platform_name,
    region_scope, region_level, province, city, county, recovery_method,
    total_sales_rmb, total_sales_num, shop_count, source_shop_rows,
    money_valid_rows, num_valid_rows
)
-- The DWD unique key is month + platform + shop. Inside one loader batch,
-- COUNT(*) therefore equals the distinct shop count at every region group.
SELECT
    month_id, platform_id, platform_name,
    region_scope, '全国', '全国合计', '全部城市', '全部区县', recovery_method,
    SUM(sales_money), SUM(sales_num), COUNT(*), COUNT(*),
    SUM(sales_money IS NOT NULL), SUM(sales_num IS NOT NULL)
FROM tmp_region_resolved_2026_gj
GROUP BY month_id, platform_id, platform_name, region_scope, recovery_method;

INSERT INTO dws_region_month_summary_v2_2026_gj (
    month_id, platform_id, platform_name,
    region_scope, region_level, province, city, county, recovery_method,
    total_sales_rmb, total_sales_num, shop_count, source_shop_rows,
    money_valid_rows, num_valid_rows
)
SELECT
    month_id, platform_id, platform_name,
    region_scope, '省级', province, '全省小计', '全部区县', recovery_method,
    SUM(sales_money), SUM(sales_num), COUNT(*), COUNT(*),
    SUM(sales_money IS NOT NULL), SUM(sales_num IS NOT NULL)
FROM tmp_region_resolved_2026_gj
GROUP BY month_id, platform_id, platform_name,
         region_scope, province, recovery_method;

INSERT INTO dws_region_month_summary_v2_2026_gj (
    month_id, platform_id, platform_name,
    region_scope, region_level, province, city, county, recovery_method,
    total_sales_rmb, total_sales_num, shop_count, source_shop_rows,
    money_valid_rows, num_valid_rows
)
SELECT
    month_id, platform_id, platform_name,
    region_scope, '市级', province, city, '全市小计', recovery_method,
    SUM(sales_money), SUM(sales_num), COUNT(*), COUNT(*),
    SUM(sales_money IS NOT NULL), SUM(sales_num IS NOT NULL)
FROM tmp_region_resolved_2026_gj
GROUP BY month_id, platform_id, platform_name,
         region_scope, province, city, recovery_method;

INSERT INTO dws_region_month_summary_v2_2026_gj (
    month_id, platform_id, platform_name,
    region_scope, region_level, province, city, county, recovery_method,
    total_sales_rmb, total_sales_num, shop_count, source_shop_rows,
    money_valid_rows, num_valid_rows
)
SELECT
    month_id, platform_id, platform_name,
    region_scope, '区县级', province, city, county, recovery_method,
    SUM(sales_money), SUM(sales_num), COUNT(*), COUNT(*),
    SUM(sales_money IS NOT NULL), SUM(sales_num IS NOT NULL)
FROM tmp_region_resolved_2026_gj
GROUP BY month_id, platform_id, platform_name,
         region_scope, province, city, county, recovery_method;

SELECT month_id, platform_id, region_scope, recovery_method,
       SUM(total_sales_rmb) AS total_sales_rmb,
       SUM(source_shop_rows) AS source_shop_rows
FROM dws_region_month_summary_v2_2026_gj
WHERE region_level = '全国'
GROUP BY month_id, platform_id, region_scope, recovery_method
ORDER BY month_id, platform_id, region_scope, recovery_method;
