SET NAMES utf8mb4;
USE ec_cross_ceshi;

TRUNCATE TABLE stg_dim_company_basic_2026_gj;

INSERT INTO stg_dim_company_basic_2026_gj (
    platform, platform_id, shop_id, company_name, company_address,
    province, city, county
)
WITH ranked AS (
    SELECT
        LOWER(TRIM(CAST(platform AS CHAR))) AS platform,
        CAST(TRIM(CAST(platform_id AS CHAR)) AS UNSIGNED) AS platform_id,
        CONVERT(TRIM(CAST(shop_id AS CHAR)) USING utf8mb4)
            COLLATE utf8mb4_0900_ai_ci AS shop_id,
        CASE WHEN company IS NULL OR UPPER(TRIM(CAST(company AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
             THEN NULL ELSE TRIM(CAST(company AS CHAR)) END AS company_name,
        CASE WHEN company_address IS NULL OR UPPER(TRIM(CAST(company_address AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
             THEN NULL ELSE TRIM(CAST(company_address AS CHAR)) END AS company_address,
        CASE WHEN province IS NULL OR UPPER(TRIM(CAST(province AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
             THEN NULL ELSE TRIM(CAST(province AS CHAR)) END AS province,
        CASE WHEN city IS NULL OR UPPER(TRIM(CAST(city AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
             THEN NULL ELSE TRIM(CAST(city AS CHAR)) END AS city,
        CASE WHEN county IS NULL OR UPPER(TRIM(CAST(county AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
             THEN NULL ELSE TRIM(CAST(county AS CHAR)) END AS county,
        ROW_NUMBER() OVER (
            PARTITION BY LOWER(TRIM(CAST(platform AS CHAR))),
                         TRIM(CAST(platform_id AS CHAR)),
                         TRIM(CAST(shop_id AS CHAR))
            ORDER BY updated_time IS NULL, updated_time DESC,
                     created_time IS NULL, created_time DESC,
                     id DESC
        ) AS row_num
    FROM ec_cross_dw.dim_company_basic
    WHERE shop_id IS NOT NULL
      AND UPPER(TRIM(CAST(shop_id AS CHAR))) NOT IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
      AND (
            (LOWER(TRIM(CAST(platform AS CHAR))) = 'amus' AND TRIM(CAST(platform_id AS CHAR)) = '2')
         OR (LOWER(TRIM(CAST(platform AS CHAR))) = 'algj' AND TRIM(CAST(platform_id AS CHAR)) = '3')
         OR (LOWER(TRIM(CAST(platform AS CHAR))) = 'ozon' AND TRIM(CAST(platform_id AS CHAR)) = '4')
      )
)
SELECT platform, platform_id, shop_id, company_name, company_address,
       province, city, county
FROM ranked
WHERE row_num = 1;

SELECT platform, platform_id, COUNT(*) AS dim_shop_count
FROM stg_dim_company_basic_2026_gj
GROUP BY platform, platform_id
ORDER BY platform_id;
