-- Generated file. Re-run only this batch after a timeout or failure.
SET NAMES utf8mb4;
USE ec_cross_ceshi;
SET SESSION group_concat_max_len = 4096;
SET SESSION max_execution_time = 0;

SET @source_row_count = (SELECT COUNT(*) FROM ec_cross_border.ozon_shopinfo_202505_cn);
SET @empty_shop_id_count = (
    SELECT COUNT(*) FROM ec_cross_border.ozon_shopinfo_202505_cn
    WHERE NOT (shop_id IS NOT NULL AND UPPER(TRIM(CONVERT(REPLACE(REPLACE(CAST(shop_id AS BINARY), UNHEX('C2A0'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING utf8mb4))) NOT IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE'))
);
SET @valid_shop_count = (
    SELECT COUNT(DISTINCT TRIM(CONVERT(REPLACE(REPLACE(CAST(shop_id AS BINARY), UNHEX('C2A0'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING utf8mb4)))
    FROM ec_cross_border.ozon_shopinfo_202505_cn
    WHERE shop_id IS NOT NULL AND UPPER(TRIM(CONVERT(REPLACE(REPLACE(CAST(shop_id AS BINARY), UNHEX('C2A0'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING utf8mb4))) NOT IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
);

INSERT INTO etl_load_audit_2025_gj (
    batch_key, month_id, platform_id, platform_name, source_table,
    source_row_count, empty_shop_id_count, valid_shop_count,
    staged_row_count, target_row_count, status, message,
    started_time, completed_time
) VALUES (
    '202505-4', 202505, 4, 'Ozon', 'ozon_shopinfo_202505_cn',
    @source_row_count, @empty_shop_id_count, @valid_shop_count,
    NULL, NULL, 'RUNNING', 'Building isolated staging batch',
    CURRENT_TIMESTAMP, NULL
)
ON DUPLICATE KEY UPDATE
    source_table = VALUES(source_table),
    source_row_count = VALUES(source_row_count),
    empty_shop_id_count = VALUES(empty_shop_id_count),
    valid_shop_count = VALUES(valid_shop_count),
    staged_row_count = NULL,
    target_row_count = NULL,
    staged_sales_money_rmb = NULL,
    target_sales_money_rmb = NULL,
    status = 'RUNNING',
    message = 'Building isolated staging batch',
    started_time = CURRENT_TIMESTAMP,
    completed_time = NULL;

DELETE FROM stg_dwd_sales_detail_2025_gj
WHERE month_id = 202505 AND platform_id = 4;

INSERT INTO stg_dwd_sales_detail_2025_gj (
    month_id, platform_id, platform_name, shop_id, shop_name,
    company_name, company_address, country, province, city, county,
    sales_num, sales_money, currency_type, category_id, category_name,
    source_row_count, invalid_sales_num_count, invalid_sales_money_count,
    dim_match_flag
)
WITH cleaned AS (
    SELECT
        CASE WHEN o.shop_id IS NULL OR UPPER(TRIM(CONVERT(REPLACE(REPLACE(CAST(o.shop_id AS BINARY), UNHEX('C2A0'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING utf8mb4))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CONVERT(REPLACE(REPLACE(CAST(o.shop_id AS BINARY), UNHEX('C2A0'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING utf8mb4)) END AS shop_id,
        CASE WHEN o.goods_id IS NULL OR UPPER(TRIM(CAST(o.goods_id AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(o.goods_id AS CHAR)) END AS goods_id,
        CASE WHEN o.shop_name IS NULL OR UPPER(TRIM(CAST(o.shop_name AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(o.shop_name AS CHAR)) END AS shop_name,
        COALESCE(CASE WHEN o.company_cn IS NULL OR UPPER(TRIM(CAST(o.company_cn AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(o.company_cn AS CHAR)) END, CASE WHEN o.company IS NULL OR UPPER(TRIM(CAST(o.company AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(o.company AS CHAR)) END) AS company_name,
        COALESCE(CASE WHEN o.company_address IS NULL OR UPPER(TRIM(CAST(o.company_address AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(o.company_address AS CHAR)) END, CASE WHEN o.address IS NULL OR UPPER(TRIM(CAST(o.address AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(o.address AS CHAR)) END) AS company_address,
        CASE WHEN o.country IS NULL OR UPPER(TRIM(CAST(o.country AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(o.country AS CHAR)) END AS country,
        CASE WHEN o.province IS NULL OR UPPER(TRIM(CAST(o.province AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(o.province AS CHAR)) END AS province,
        CASE WHEN o.city IS NULL OR UPPER(TRIM(CAST(o.city AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(o.city AS CHAR)) END AS city,
        CASE WHEN o.county IS NULL OR UPPER(TRIM(CAST(o.county AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(o.county AS CHAR)) END AS county,
        CASE WHEN o.sales_num IS NULL OR UPPER(TRIM(CONVERT(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CAST(o.sales_num AS BINARY), UNHEX('EFBFA5'), UNHEX('')), UNHEX('EFBF84'), UNHEX('')), UNHEX('EFBC8C'), UNHEX('')), UNHEX('C2A5'), UNHEX('')), UNHEX('C2A0'), UNHEX('')), UNHEX('A5'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING latin1))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CONVERT(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CAST(o.sales_num AS BINARY), UNHEX('EFBFA5'), UNHEX('')), UNHEX('EFBF84'), UNHEX('')), UNHEX('EFBC8C'), UNHEX('')), UNHEX('C2A5'), UNHEX('')), UNHEX('C2A0'), UNHEX('')), UNHEX('A5'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING latin1)) END AS sales_num_raw,
        CASE WHEN o.sales_money IS NULL OR UPPER(TRIM(CONVERT(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CAST(o.sales_money AS BINARY), UNHEX('EFBFA5'), UNHEX('')), UNHEX('EFBF84'), UNHEX('')), UNHEX('EFBC8C'), UNHEX('')), UNHEX('C2A5'), UNHEX('')), UNHEX('C2A0'), UNHEX('')), UNHEX('A5'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING latin1))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CONVERT(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CAST(o.sales_money AS BINARY), UNHEX('EFBFA5'), UNHEX('')), UNHEX('EFBF84'), UNHEX('')), UNHEX('EFBC8C'), UNHEX('')), UNHEX('C2A5'), UNHEX('')), UNHEX('C2A0'), UNHEX('')), UNHEX('A5'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING latin1)) END AS sales_money_raw,
        CASE WHEN o.category_name_new IS NULL OR UPPER(TRIM(REGEXP_REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CAST(o.category_name_new AS CHAR), CHAR(13), ''), CHAR(10), ''), CHAR(9), ' '), CONVERT(UNHEX('C2A0') USING utf8mb4), ' '), '[[:space:]]+', ' '))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE', '未分类') THEN NULL ELSE TRIM(REGEXP_REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CAST(o.category_name_new AS CHAR), CHAR(13), ''), CHAR(10), ''), CHAR(9), ' '), CONVERT(UNHEX('C2A0') USING utf8mb4), ' '), '[[:space:]]+', ' ')) END AS category_name
    FROM ec_cross_border.ozon_shopinfo_202505_cn o
    WHERE o.shop_id IS NOT NULL AND UPPER(TRIM(CONVERT(REPLACE(REPLACE(CAST(o.shop_id AS BINARY), UNHEX('C2A0'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING utf8mb4))) NOT IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
), normalized AS (
    SELECT c.*,
           REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(sales_num_raw), 'US$', ''), 'USD', ''), 'RMB', ''), 'CNY', ''), '$', ''), ',', ''), ' ', '') AS sales_num_text,
           REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(sales_money_raw), 'US$', ''), 'USD', ''), 'RMB', ''), 'CNY', ''), '$', ''), ',', ''), ' ', '') AS sales_money_text
    FROM cleaned c
), typed AS (
    SELECT n.*,
           CASE WHEN sales_num_text REGEXP '^([0-9]+([.][0-9]+)?|[.][0-9]+)$'
                THEN CAST(sales_num_text AS DECIMAL(28,4)) END AS sales_num_value,
           CASE WHEN sales_money_text REGEXP '^([0-9]+([.][0-9]+)?|[.][0-9]+)$'
                THEN CAST(sales_money_text AS DECIMAL(28,4)) END AS sales_money_value,
           CASE WHEN sales_num_raw IS NOT NULL
                     AND NOT (sales_num_text REGEXP '^([0-9]+([.][0-9]+)?|[.][0-9]+)$')
                THEN 1 ELSE 0 END AS invalid_sales_num_flag,
           CASE WHEN sales_money_raw IS NOT NULL
                     AND NOT (sales_money_text REGEXP '^([0-9]+([.][0-9]+)?|[.][0-9]+)$')
                THEN 1 ELSE 0 END AS invalid_sales_money_flag
    FROM normalized n
), goods_deduplicated AS (
    SELECT
        shop_id,
        COALESCE(
            goods_id,
            CONCAT('__NULL__|', SHA2(CONCAT_WS('|',
                COALESCE(shop_name, '__NULL__'),
                COALESCE(company_name, '__NULL__'),
                COALESCE(company_address, '__NULL__'),
                COALESCE(country, '__NULL__'),
                COALESCE(province, '__NULL__'),
                COALESCE(city, '__NULL__'),
                COALESCE(county, '__NULL__'),
                COALESCE(sales_num_raw, '__NULL__'),
                COALESCE(sales_money_raw, '__NULL__'),
                COALESCE(category_name, '__NULL__')), 256))
        ) AS goods_key,
        MAX(shop_name) AS shop_name,
        MAX(company_name) AS company_name,
        MAX(company_address) AS company_address,
        MAX(country) AS country,
        MAX(province) AS province,
        MAX(city) AS city,
        MAX(county) AS county,
        MAX(category_name) AS category_name,
        MAX(sales_num_value) AS sales_num_value,
        MAX(sales_money_value) AS sales_money_value,
        MAX(invalid_sales_num_flag) AS invalid_sales_num_flag,
        MAX(invalid_sales_money_flag) AS invalid_sales_money_flag
    FROM typed
    GROUP BY shop_id,
             COALESCE(goods_id, CONCAT('__NULL__|', SHA2(CONCAT_WS('|',
                 COALESCE(shop_name, '__NULL__'),
                 COALESCE(company_name, '__NULL__'),
                 COALESCE(company_address, '__NULL__'),
                 COALESCE(country, '__NULL__'),
                 COALESCE(province, '__NULL__'),
                 COALESCE(city, '__NULL__'),
                 COALESCE(county, '__NULL__'),
                 COALESCE(sales_num_raw, '__NULL__'),
                 COALESCE(sales_money_raw, '__NULL__'),
                 COALESCE(category_name, '__NULL__')), 256)))
), aggregated AS (
    SELECT
        shop_id,
        MAX(shop_name) AS shop_name,
        MAX(company_name) AS company_name,
        MAX(company_address) AS company_address,
        MAX(country) AS country,
        MAX(province) AS province,
        MAX(city) AS city,
        MAX(county) AS county,
        SUM(sales_num_value) AS sales_num,
        ROUND(SUM(sales_money_value), 2) AS sales_money,
        NULLIF(
            SUBSTRING_INDEX(
                GROUP_CONCAT(
                    COALESCE(category_name, '__NULL__')
                    ORDER BY sales_money_value IS NULL,
                             sales_money_value DESC,
                             category_name,
                             goods_key
                    SEPARATOR '|#ROW#|'
                ),
                '|#ROW#|', 1
            ),
            '__NULL__'
        ) AS category_name,
        COUNT(*) AS source_row_count,
        SUM(invalid_sales_num_flag) AS invalid_sales_num_count,
        SUM(invalid_sales_money_flag) AS invalid_sales_money_count
    FROM goods_deduplicated
    GROUP BY shop_id
)
SELECT
    202505, 4, 'Ozon', a.shop_id, a.shop_name,
    COALESCE(d.company_name, a.company_name),
    COALESCE(d.company_address, a.company_address),
    a.country,
    COALESCE(a.province, d.province),
    COALESCE(a.city, d.city),
    COALESCE(a.county, d.county),
    a.sales_num, a.sales_money, 'RMB', NULL, a.category_name,
    a.source_row_count, a.invalid_sales_num_count,
    a.invalid_sales_money_count,
    CASE WHEN d.shop_id IS NULL THEN 0 ELSE 1 END
FROM aggregated a
LEFT JOIN stg_dim_company_basic_2026_gj d
  ON d.platform = 'ozon'
 AND d.platform_id = 4
 AND d.shop_id = a.shop_id;

SET @staged_row_count = (
    SELECT COUNT(*) FROM stg_dwd_sales_detail_2025_gj
    WHERE month_id = 202505 AND platform_id = 4
);
SET @staged_sales_money_rmb = (
    SELECT ROUND(SUM(sales_money), 2) FROM stg_dwd_sales_detail_2025_gj
    WHERE month_id = 202505 AND platform_id = 4
);

UPDATE etl_load_audit_2025_gj
SET staged_row_count = @staged_row_count,
    staged_sales_money_rmb = @staged_sales_money_rmb,
    status = 'STAGED',
    message = 'Staging complete; validating before promotion'
WHERE month_id = 202505 AND platform_id = 4;

CALL sp_promote_dwd_batch_2025_gj(202505, 4);

SELECT month_id, platform_id, platform_name, source_row_count,
       empty_shop_id_count, valid_shop_count, staged_row_count,
       target_row_count, staged_sales_money_rmb, target_sales_money_rmb,
       status, message, completed_time
FROM etl_load_audit_2025_gj
WHERE month_id = 202505 AND platform_id = 4;
