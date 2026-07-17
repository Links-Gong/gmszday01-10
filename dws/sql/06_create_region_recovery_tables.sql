SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- Safety boundary: this script only creates new project-owned tables.
-- It intentionally fails when a target table already exists so an existing
-- validated result cannot be overwritten by accident.

CREATE TABLE dim_region_standard_2026_gj (
    region_code VARCHAR(100) NOT NULL,
    region_level VARCHAR(20) NOT NULL,
    province_code VARCHAR(100) NULL,
    province_name VARCHAR(255) NULL,
    province_alias VARCHAR(255) NULL,
    city_code VARCHAR(100) NULL,
    city_name VARCHAR(255) NULL,
    city_alias VARCHAR(255) NULL,
    county_code VARCHAR(100) NULL,
    county_name VARCHAR(255) NULL,
    county_alias VARCHAR(255) NULL,
    city_has_counties TINYINT NOT NULL DEFAULT 0,
    source_reference VARCHAR(100) NOT NULL,
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (region_code),
    KEY idx_standard_province (province_name),
    KEY idx_standard_city (province_name, city_name),
    KEY idx_standard_county (province_name, county_name),
    KEY idx_standard_city_county (city_name, county_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='2026H1区域恢复使用的标准行政区快照';

INSERT INTO dim_region_standard_2026_gj (
    region_code, region_level,
    province_code, province_name, province_alias,
    city_code, city_name, city_alias,
    county_code, county_name, county_alias,
    city_has_counties, source_reference
)
WITH city_children AS (
    SELECT city_code, COUNT(*) AS county_count
    FROM ec_cross_ceshi.dim_region_1
    WHERE region_level = 'county'
      AND city_code IS NOT NULL
      AND TRIM(city_code) <> ''
    GROUP BY city_code
),
area_dedup AS (
    SELECT code, MAX(NULLIF(TRIM(area), '')) AS area
    FROM ec_cross_dw.dim_china_area_code
    WHERE code IS NOT NULL AND TRIM(code) <> ''
    GROUP BY code
)
SELECT
    r.region_code,
    r.region_level,
    NULLIF(TRIM(r.province_code), '') AS province_code,
    COALESCE(NULLIF(TRIM(p.area), ''), NULLIF(TRIM(r.province), '')) AS province_name,
    NULLIF(TRIM(r.province), '') AS province_alias,
    NULLIF(TRIM(r.city_code), '') AS city_code,
    CASE
        WHEN NULLIF(TRIM(r.city_code), '') IS NULL THEN NULL
        ELSE COALESCE(NULLIF(TRIM(c.area), ''), NULLIF(TRIM(r.city), ''))
    END AS city_name,
    NULLIF(TRIM(r.city), '') AS city_alias,
    NULLIF(TRIM(r.county_code), '') AS county_code,
    CASE
        WHEN NULLIF(TRIM(r.county_code), '') IS NULL THEN NULL
        ELSE COALESCE(NULLIF(TRIM(k.area), ''), NULLIF(TRIM(r.county), ''))
    END AS county_name,
    NULLIF(TRIM(r.county), '') AS county_alias,
    CASE WHEN COALESCE(cc.county_count, 0) > 0 THEN 1 ELSE 0 END,
    'dim_china_area_code+dim_region_1'
FROM ec_cross_ceshi.dim_region_1 r
LEFT JOIN area_dedup p
  ON p.code = r.province_code
LEFT JOIN area_dedup c
  ON c.code = r.city_code
LEFT JOIN area_dedup k
  ON k.code = r.county_code
LEFT JOIN city_children cc
  ON cc.city_code = r.city_code
WHERE r.region_code IS NOT NULL
  AND TRIM(r.region_code) <> '';

CREATE TABLE dws_region_recovery_map_2026_gj (
    map_type VARCHAR(30) NOT NULL,
    platform_id TINYINT NOT NULL,
    match_key TEXT NOT NULL,
    match_key_hash BINARY(32) NOT NULL,
    resolved_province VARCHAR(255) NULL,
    resolved_city VARCHAR(255) NULL,
    resolved_county VARCHAR(255) NULL,
    region_scope VARCHAR(30) NOT NULL DEFAULT 'DOMESTIC',
    county_applicable TINYINT NOT NULL DEFAULT 1,
    confidence_level VARCHAR(20) NOT NULL,
    evidence_rows BIGINT NOT NULL DEFAULT 0,
    first_month_id INT NULL,
    last_month_id INT NULL,
    created_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_region_recovery (map_type, platform_id, match_key_hash),
    KEY idx_region_recovery_lookup (platform_id, map_type, match_key_hash),
    KEY idx_region_recovery_result (
        region_scope,
        resolved_province(100), resolved_city(100), resolved_county(100)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='2026H1区域回填证据映射，不保存模糊或一对多结果';

SELECT region_level, COUNT(*) AS standard_rows
FROM dim_region_standard_2026_gj
GROUP BY region_level
ORDER BY region_level;
