-- Generated file. Re-run only this batch after a timeout or failure.
SET NAMES utf8mb4;
USE ec_cross_ceshi;
SET SESSION group_concat_max_len = 4096;
SET SESSION max_execution_time = 0;

SET @source_row_count = (SELECT COUNT(*) FROM ec_cross_border.smt_shopinfo_202604);
SET @empty_shop_id_count = (
    SELECT COUNT(*) FROM ec_cross_border.smt_shopinfo_202604
    WHERE NOT (shop_id IS NOT NULL AND UPPER(TRIM(CONVERT(REPLACE(REPLACE(CAST(shop_id AS BINARY), UNHEX('C2A0'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING utf8mb4))) NOT IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE'))
);
SET @valid_shop_count = (
    SELECT COUNT(DISTINCT TRIM(CONVERT(REPLACE(REPLACE(CAST(shop_id AS BINARY), UNHEX('C2A0'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING utf8mb4)))
    FROM ec_cross_border.smt_shopinfo_202604
    WHERE shop_id IS NOT NULL AND UPPER(TRIM(CONVERT(REPLACE(REPLACE(CAST(shop_id AS BINARY), UNHEX('C2A0'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING utf8mb4))) NOT IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
);

INSERT INTO etl_load_audit_2026_gj (
    batch_key, month_id, platform_id, platform_name, source_table,
    source_row_count, empty_shop_id_count, valid_shop_count,
    staged_row_count, target_row_count, status, message,
    started_time, completed_time
) VALUES (
    '202604-1', 202604, 1, 'SMT', 'smt_shopinfo_202604',
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

DELETE FROM stg_dwd_sales_detail_2026_gj
WHERE month_id = 202604 AND platform_id = 1;

INSERT INTO stg_dwd_sales_detail_2026_gj (
    month_id, platform_id, platform_name, shop_id, shop_name,
    company_name, company_address, country, province, city, county,
    sales_num, sales_money, currency_type, category_id, category_name,
    source_row_count, invalid_sales_num_count, invalid_sales_money_count,
    dim_match_flag
)
WITH cleaned AS (
    SELECT
        CASE WHEN s.shop_id IS NULL OR UPPER(TRIM(CONVERT(REPLACE(REPLACE(CAST(s.shop_id AS BINARY), UNHEX('C2A0'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING utf8mb4))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CONVERT(REPLACE(REPLACE(CAST(s.shop_id AS BINARY), UNHEX('C2A0'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING utf8mb4)) END AS shop_id,
        CASE WHEN s.shop_name IS NULL OR UPPER(TRIM(CAST(s.shop_name AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(s.shop_name AS CHAR)) END AS shop_name,
        CASE WHEN s.company IS NULL OR UPPER(TRIM(CAST(s.company AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(s.company AS CHAR)) END AS company_name,
        CASE WHEN s.address IS NULL OR UPPER(TRIM(CAST(s.address AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(s.address AS CHAR)) END AS company_address,
        NULL AS country,
        CASE WHEN s.province IS NULL OR UPPER(TRIM(CAST(s.province AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(s.province AS CHAR)) END AS province,
        CASE WHEN s.city IS NULL OR UPPER(TRIM(CAST(s.city AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(s.city AS CHAR)) END AS city,
        CASE WHEN s.county IS NULL OR UPPER(TRIM(CAST(s.county AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(s.county AS CHAR)) END AS county,
        CASE WHEN s.sales_num IS NULL OR UPPER(TRIM(CONVERT(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CAST(s.sales_num AS BINARY), UNHEX('EFBFA5'), UNHEX('')), UNHEX('EFBF84'), UNHEX('')), UNHEX('EFBC8C'), UNHEX('')), UNHEX('C2A5'), UNHEX('')), UNHEX('C2A0'), UNHEX('')), UNHEX('A5'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING latin1))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CONVERT(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CAST(s.sales_num AS BINARY), UNHEX('EFBFA5'), UNHEX('')), UNHEX('EFBF84'), UNHEX('')), UNHEX('EFBC8C'), UNHEX('')), UNHEX('C2A5'), UNHEX('')), UNHEX('C2A0'), UNHEX('')), UNHEX('A5'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING latin1)) END AS sales_num_raw,
        CASE WHEN s.sales_month IS NULL OR UPPER(TRIM(CONVERT(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CAST(s.sales_month AS BINARY), UNHEX('EFBFA5'), UNHEX('')), UNHEX('EFBF84'), UNHEX('')), UNHEX('EFBC8C'), UNHEX('')), UNHEX('C2A5'), UNHEX('')), UNHEX('C2A0'), UNHEX('')), UNHEX('A5'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING latin1))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CONVERT(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CAST(s.sales_month AS BINARY), UNHEX('EFBFA5'), UNHEX('')), UNHEX('EFBF84'), UNHEX('')), UNHEX('EFBC8C'), UNHEX('')), UNHEX('C2A5'), UNHEX('')), UNHEX('C2A0'), UNHEX('')), UNHEX('A5'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING latin1)) END AS sales_money_raw,
        COALESCE(CASE WHEN s.category_id_new IS NULL OR UPPER(TRIM(CAST(s.category_id_new AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(s.category_id_new AS CHAR)) END, CASE WHEN s.category_id IS NULL OR UPPER(TRIM(CAST(s.category_id AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(s.category_id AS CHAR)) END) AS category_id,
        COALESCE(CASE WHEN s.category_name_new IS NULL OR UPPER(TRIM(CAST(s.category_name_new AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(s.category_name_new AS CHAR)) END, CASE WHEN s.category_name IS NULL OR UPPER(TRIM(CAST(s.category_name AS CHAR))) IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE') THEN NULL ELSE TRIM(CAST(s.category_name AS CHAR)) END) AS category_name
    FROM ec_cross_border.smt_shopinfo_202604 s
    WHERE s.shop_id IS NOT NULL AND UPPER(TRIM(CONVERT(REPLACE(REPLACE(CAST(s.shop_id AS BINARY), UNHEX('C2A0'), UNHEX('')), UNHEX('A0'), UNHEX('')) USING utf8mb4))) NOT IN ('', '-', '--', 'NULL', 'N/A', 'NA', 'NAN', 'NONE')
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
)
SELECT
    202604, 1, 'SMT', shop_id, shop_name,
    company_name, company_address, country, province, city, county,
    sales_num_value,
    CASE WHEN sales_money_value IS NULL THEN NULL
         ELSE ROUND(sales_money_value * 7.2, 2) END,
    'RMB', category_id, category_name,
    1, invalid_sales_num_flag, invalid_sales_money_flag, 0
FROM typed;

SET @staged_row_count = (
    SELECT COUNT(*) FROM stg_dwd_sales_detail_2026_gj
    WHERE month_id = 202604 AND platform_id = 1
);
SET @staged_sales_money_rmb = (
    SELECT ROUND(SUM(sales_money), 2) FROM stg_dwd_sales_detail_2026_gj
    WHERE month_id = 202604 AND platform_id = 1
);

UPDATE etl_load_audit_2026_gj
SET staged_row_count = @staged_row_count,
    staged_sales_money_rmb = @staged_sales_money_rmb,
    status = 'STAGED',
    message = 'Staging complete; validating before promotion'
WHERE month_id = 202604 AND platform_id = 1;

CALL sp_promote_dwd_batch_2026_gj(202604, 1);

SELECT month_id, platform_id, platform_name, source_row_count,
       empty_shop_id_count, valid_shop_count, staged_row_count,
       target_row_count, staged_sales_money_rmb, target_sales_money_rmb,
       status, message, completed_time
FROM etl_load_audit_2026_gj
WHERE month_id = 202604 AND platform_id = 1;
