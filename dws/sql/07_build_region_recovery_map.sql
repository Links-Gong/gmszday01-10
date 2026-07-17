SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- This script only populates the new recovery table created by step 06.
-- Existing DWD/DWS/DM tables are read-only inputs.

INSERT INTO dws_region_recovery_map_2026_gj (
    map_type, platform_id, match_key, match_key_hash,
    resolved_province, resolved_city, resolved_county,
    region_scope, county_applicable, confidence_level,
    evidence_rows, first_month_id, last_month_id
)
WITH province_keys AS (
    SELECT DISTINCT
        province_code,
        LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            TRIM(province_name), ' ', ''), CHAR(9), ''), CHAR(10), ''),
            CHAR(13), ''), CONVERT(0xC2A0 USING utf8mb4), '')) AS region_key,
        province_name
    FROM dim_region_standard_2026_gj
    WHERE province_name IS NOT NULL
    UNION
    SELECT DISTINCT
        province_code,
        LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            TRIM(province_alias), ' ', ''), CHAR(9), ''), CHAR(10), ''),
            CHAR(13), ''), CONVERT(0xC2A0 USING utf8mb4), '')),
        province_name
    FROM dim_region_standard_2026_gj
    WHERE province_alias IS NOT NULL
),
city_keys AS (
    SELECT DISTINCT
        province_code, city_code,
        LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            TRIM(city_name), ' ', ''), CHAR(9), ''), CHAR(10), ''),
            CHAR(13), ''), CONVERT(0xC2A0 USING utf8mb4), '')) AS region_key,
        province_name, city_name, city_has_counties
    FROM dim_region_standard_2026_gj
    WHERE city_name IS NOT NULL
    UNION
    SELECT DISTINCT
        province_code, city_code,
        LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            TRIM(city_alias), ' ', ''), CHAR(9), ''), CHAR(10), ''),
            CHAR(13), ''), CONVERT(0xC2A0 USING utf8mb4), '')),
        province_name, city_name, city_has_counties
    FROM dim_region_standard_2026_gj
    WHERE city_alias IS NOT NULL
),
county_keys AS (
    SELECT DISTINCT
        province_code, city_code, county_code,
        LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            TRIM(county_name), ' ', ''), CHAR(9), ''), CHAR(10), ''),
            CHAR(13), ''), CONVERT(0xC2A0 USING utf8mb4), '')) AS region_key,
        province_name, city_name, county_name
    FROM dim_region_standard_2026_gj
    WHERE county_name IS NOT NULL
    UNION
    SELECT DISTINCT
        province_code, city_code, county_code,
        LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            TRIM(county_alias), ' ', ''), CHAR(9), ''), CHAR(10), ''),
            CHAR(13), ''), CONVERT(0xC2A0 USING utf8mb4), '')),
        province_name, city_name, county_name
    FROM dim_region_standard_2026_gj
    WHERE county_alias IS NOT NULL
),
admin_candidates AS (
    SELECT
        CONCAT('P|', p.region_key) AS match_key,
        p.province_name AS resolved_province,
        NULL AS resolved_city,
        NULL AS resolved_county,
        1 AS county_applicable
    FROM province_keys p

    UNION ALL
    SELECT
        CONCAT('PC|', p.region_key, '|', c.region_key),
        c.province_name, c.city_name, NULL,
        c.city_has_counties
    FROM province_keys p
    JOIN city_keys c ON c.province_code = p.province_code

    UNION ALL
    SELECT
        CONCAT('PK|', p.region_key, '|', k.region_key),
        k.province_name, k.city_name, k.county_name, 1
    FROM province_keys p
    JOIN county_keys k ON k.province_code = p.province_code

    UNION ALL
    SELECT
        CONCAT('CK|', c.region_key, '|', k.region_key),
        k.province_name, k.city_name, k.county_name, 1
    FROM city_keys c
    JOIN county_keys k ON k.city_code = c.city_code
),
unique_admin AS (
    SELECT
        match_key,
        MAX(resolved_province) AS resolved_province,
        MAX(resolved_city) AS resolved_city,
        MAX(resolved_county) AS resolved_county,
        MAX(county_applicable) AS county_applicable,
        COUNT(*) AS evidence_rows
    FROM admin_candidates
    WHERE match_key IS NOT NULL AND match_key <> ''
    GROUP BY match_key
    HAVING COUNT(DISTINCT CONCAT_WS('|',
        COALESCE(resolved_province, '#'),
        COALESCE(resolved_city, '#'),
        COALESCE(resolved_county, '#')
    )) = 1
)
SELECT
    'ADMIN_HIERARCHY', 0, match_key, UNHEX(SHA2(match_key, 256)),
    resolved_province, resolved_city, resolved_county,
    'DOMESTIC', county_applicable, 'HIGH', evidence_rows, NULL, NULL
FROM unique_admin;

-- Country scope is a guardrail. Explicit overseas values are classified
-- before any China-region evidence can be considered.
INSERT INTO dws_region_recovery_map_2026_gj (
    map_type, platform_id, match_key, match_key_hash,
    resolved_province, resolved_city, resolved_county,
    region_scope, county_applicable, confidence_level,
    evidence_rows, first_month_id, last_month_id
)
WITH country_values AS (
    SELECT
        UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            TRIM(country), ' ', ''), CHAR(9), ''), CHAR(10), ''),
            CHAR(13), ''), CONVERT(0xC2A0 USING utf8mb4), '')) AS country_key,
        MAX(TRIM(country)) AS country_label,
        COUNT(*) AS evidence_rows,
        MIN(month_id) AS first_month_id,
        MAX(month_id) AS last_month_id
    FROM dwd_sales_detail_2026_gj
    WHERE month_id BETWEEN 202601 AND 202606
      AND country IS NOT NULL
      AND TRIM(country) <> ''
      AND UPPER(TRIM(country)) NOT IN ('-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
      AND TRIM(country) REGEXP '[[:alpha:]]'
    GROUP BY UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        TRIM(country), ' ', ''), CHAR(9), ''), CHAR(10), ''),
        CHAR(13), ''), CONVERT(0xC2A0 USING utf8mb4), ''))
),
classified AS (
    SELECT
        CONCAT('COUNTRY|', country_key) AS match_key,
        CASE
            WHEN country_key IN ('CN', 'CHINA', 'PRC', '中国', '中国大陆') THEN NULL
            WHEN country_key IN ('TAIWANCHINA', 'TAIWAN', '中国台湾', '台湾') THEN '台湾省'
            WHEN country_key IN ('HONGKONGSARCHINA', 'HONGKONG', '中国香港', '香港')
                THEN '香港特别行政区'
            WHEN country_key IN ('MACAUSARCHINA', 'MACAU', '中国澳门', '澳门')
                THEN '澳门特别行政区'
            ELSE '境外'
        END AS resolved_province,
        CASE
            WHEN country_key IN ('CN', 'CHINA', 'PRC', '中国', '中国大陆') THEN NULL
            WHEN country_key IN (
                'TAIWANCHINA', 'TAIWAN', '中国台湾', '台湾',
                'HONGKONGSARCHINA', 'HONGKONG', '中国香港', '香港',
                'MACAUSARCHINA', 'MACAU', '中国澳门', '澳门'
            ) THEN '不适用'
            ELSE country_label
        END AS resolved_city,
        CASE
            WHEN country_key IN ('CN', 'CHINA', 'PRC', '中国', '中国大陆') THEN NULL
            ELSE '不适用'
        END AS resolved_county,
        CASE
            WHEN country_key IN ('CN', 'CHINA', 'PRC', '中国', '中国大陆') THEN 'DOMESTIC'
            WHEN country_key IN (
                'TAIWANCHINA', 'TAIWAN', '中国台湾', '台湾',
                'HONGKONGSARCHINA', 'HONGKONG', '中国香港', '香港',
                'MACAUSARCHINA', 'MACAU', '中国澳门', '澳门'
            ) THEN 'SPECIAL_REGION'
            ELSE 'OVERSEAS'
        END AS region_scope,
        CASE WHEN country_key IN ('CN', 'CHINA', 'PRC', '中国', '中国大陆')
             THEN 1 ELSE 0 END AS county_applicable,
        evidence_rows, first_month_id, last_month_id
    FROM country_values
)
SELECT
    'COUNTRY_SCOPE', 0, match_key, UNHEX(SHA2(match_key, 256)),
    resolved_province, resolved_city, resolved_county,
    region_scope, county_applicable, 'HIGH',
    evidence_rows, first_month_id, last_month_id
FROM classified;

CREATE TEMPORARY TABLE tmp_region_known_evidence_2026_gj (
    platform_id TINYINT NOT NULL,
    shop_id VARCHAR(255) NOT NULL,
    address_key VARCHAR(1200) NULL,
    address_key_hash BINARY(32) NULL,
    resolved_province VARCHAR(255) NOT NULL,
    resolved_city VARCHAR(255) NOT NULL,
    resolved_county VARCHAR(255) NULL,
    county_applicable TINYINT NOT NULL,
    month_id INT NOT NULL,
    KEY idx_tmp_shop (platform_id, shop_id),
    KEY idx_tmp_address (platform_id, address_key_hash)
) ENGINE=InnoDB;

INSERT INTO tmp_region_known_evidence_2026_gj (
    platform_id, shop_id, address_key, address_key_hash,
    resolved_province, resolved_city, resolved_county,
    county_applicable, month_id
)
WITH normalized AS (
    SELECT
        month_id, platform_id, shop_id,
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
        ck.resolved_county AS ck_county
    FROM normalized n
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
),
resolved AS (
    SELECT *,
        COALESCE(pk_province, mis_province, pc_province, ck_province, p_province)
            AS resolved_province,
        COALESCE(pk_city, mis_city, pc_city, ck_city) AS resolved_city,
        COALESCE(pk_county, mis_county, ck_county) AS resolved_county,
        CASE
            WHEN COALESCE(pk_county, mis_county, ck_county) IS NOT NULL THEN 1
            ELSE COALESCE(pc_county_applicable, 1)
        END AS county_applicable
    FROM matched
)
SELECT
    platform_id, shop_id, address_key,
    CASE WHEN address_key IS NULL THEN NULL ELSE UNHEX(SHA2(CONCAT('ADDR|', address_key), 256)) END,
    resolved_province, resolved_city, resolved_county,
    county_applicable, month_id
FROM resolved
WHERE resolved_province IS NOT NULL
  AND resolved_city IS NOT NULL
  AND (resolved_county IS NOT NULL OR county_applicable = 0)
  AND (
      country_key IS NULL
      OR country_key IN ('CN', 'CHINA', 'PRC', '中国', '中国大陆')
  );

INSERT INTO dws_region_recovery_map_2026_gj (
    map_type, platform_id, match_key, match_key_hash,
    resolved_province, resolved_city, resolved_county,
    region_scope, county_applicable, confidence_level,
    evidence_rows, first_month_id, last_month_id
)
SELECT
    'SHOP_HISTORY', platform_id,
    CONCAT('SHOP|', shop_id),
    UNHEX(SHA2(CONCAT('SHOP|', shop_id), 256)),
    MAX(resolved_province), MAX(resolved_city), MAX(resolved_county),
    'DOMESTIC', MAX(county_applicable), 'HIGH',
    COUNT(*), MIN(month_id), MAX(month_id)
FROM tmp_region_known_evidence_2026_gj
GROUP BY platform_id, shop_id
HAVING COUNT(DISTINCT CONCAT_WS('|',
    resolved_province,
    resolved_city,
    COALESCE(resolved_county, '#NOT_APPLICABLE')
)) = 1;

INSERT INTO dws_region_recovery_map_2026_gj (
    map_type, platform_id, match_key, match_key_hash,
    resolved_province, resolved_city, resolved_county,
    region_scope, county_applicable, confidence_level,
    evidence_rows, first_month_id, last_month_id
)
SELECT
    'EXACT_ADDRESS', platform_id,
    CONCAT('ADDR|', MAX(address_key)),
    address_key_hash,
    MAX(resolved_province), MAX(resolved_city), MAX(resolved_county),
    'DOMESTIC', MAX(county_applicable), 'HIGH',
    COUNT(*), MIN(month_id), MAX(month_id)
FROM tmp_region_known_evidence_2026_gj
WHERE address_key IS NOT NULL
GROUP BY platform_id, address_key_hash
HAVING COUNT(DISTINCT CONCAT_WS('|',
    resolved_province,
    resolved_city,
    COALESCE(resolved_county, '#NOT_APPLICABLE')
)) = 1;

SELECT map_type, platform_id,
       COUNT(*) AS mapping_count,
       SUM(evidence_rows) AS evidence_rows,
       MIN(first_month_id) AS first_month_id,
       MAX(last_month_id) AS last_month_id
FROM dws_region_recovery_map_2026_gj
GROUP BY map_type, platform_id
ORDER BY map_type, platform_id;
