-- Preflight only: this file does not modify source or result tables.
SET NAMES utf8mb4;

SELECT VERSION() AS mysql_version,
       CASE WHEN VERSION() REGEXP '^8[.]' THEN 'PASS' ELSE 'FAIL: MySQL 8 required' END AS version_status;

-- Result 1: all 24 source tables must be OK.
WITH months AS (
    SELECT 202601 AS month_id UNION ALL SELECT 202602 UNION ALL SELECT 202603
    UNION ALL SELECT 202604 UNION ALL SELECT 202605 UNION ALL SELECT 202606
), platforms AS (
    SELECT 'SMT' AS platform_name, 'smt_shopinfo_' AS table_prefix, '' AS table_suffix
    UNION ALL SELECT 'Amazon', 'amazonus_shopinfo_', '_sales'
    UNION ALL SELECT 'Alibaba', 'alibabagj_shopinfo_', ''
    UNION ALL SELECT 'Ozon', 'ozon_shopinfo_', '_cn'
), expected AS (
    SELECT p.platform_name, m.month_id,
           CONCAT(p.table_prefix, m.month_id, p.table_suffix) AS table_name
    FROM months m CROSS JOIN platforms p
)
SELECT e.platform_name, e.month_id, e.table_name,
       CASE WHEN t.table_name IS NULL THEN 'MISSING' ELSE 'OK' END AS table_status,
       t.engine, t.table_rows
FROM expected e
LEFT JOIN information_schema.tables t
  ON t.table_schema = 'ec_cross_border'
 AND t.table_name = e.table_name
ORDER BY e.month_id,
         FIELD(e.platform_name, 'SMT', 'Amazon', 'Alibaba', 'Ozon');

-- Result 2: must return zero rows.
WITH months AS (
    SELECT 202601 AS month_id UNION ALL SELECT 202602 UNION ALL SELECT 202603
    UNION ALL SELECT 202604 UNION ALL SELECT 202605 UNION ALL SELECT 202606
), platform_requirements AS (
    SELECT 'SMT' AS platform_name, 'smt_shopinfo_' AS table_prefix, '' AS table_suffix,
           JSON_ARRAY('shop_id','shop_name','company','address','province','city','county',
                      'sales_num','sales_month','category_id','category_name',
                      'category_id_new','category_name_new') AS required_columns
    UNION ALL
    SELECT 'Amazon', 'amazonus_shopinfo_', '_sales',
           JSON_ARRAY('id','shop_id','shop_name','company','company_address','country',
                      'province','city','county','sales','sales_money',
                      'category_id_new','category_name_new')
    UNION ALL
    SELECT 'Alibaba', 'alibabagj_shopinfo_', '',
           JSON_ARRAY('shop_id','company','company_cn','company_address','address','country',
                      'province','city','county','sales','sales_money','category_id',
                      'category_name','category_id_new','category_name_new')
    UNION ALL
    SELECT 'Ozon', 'ozon_shopinfo_', '_cn',
           JSON_ARRAY('goods_id','shop_id','shop_name','company','company_cn','company_address',
                      'address','country','province','city','county','sales_num','sales_money')
), required AS (
    SELECT p.platform_name, m.month_id,
           CONCAT(p.table_prefix, m.month_id, p.table_suffix) AS table_name,
           j.column_name
    FROM months m
    CROSS JOIN platform_requirements p
    CROSS JOIN JSON_TABLE(
        p.required_columns, '$[*]' COLUMNS(column_name VARCHAR(64) PATH '$')
    ) j
)
SELECT r.platform_name, r.month_id, r.table_name, r.column_name AS missing_column
FROM required r
LEFT JOIN information_schema.columns c
  ON c.table_schema = 'ec_cross_border'
 AND c.table_name = r.table_name
 AND c.column_name = r.column_name
WHERE c.column_name IS NULL
ORDER BY r.month_id, r.platform_name, r.column_name;

-- Result 3: compare every month with the platform's 202601 schema; must return zero rows.
WITH months AS (
    SELECT 202602 AS month_id UNION ALL SELECT 202603 UNION ALL SELECT 202604
    UNION ALL SELECT 202605 UNION ALL SELECT 202606
), platforms AS (
    SELECT 'SMT' AS platform_name, 'smt_shopinfo_' AS table_prefix, '' AS table_suffix
    UNION ALL SELECT 'Amazon', 'amazonus_shopinfo_', '_sales'
    UNION ALL SELECT 'Alibaba', 'alibabagj_shopinfo_', ''
    UNION ALL SELECT 'Ozon', 'ozon_shopinfo_', '_cn'
), expected AS (
    SELECT p.platform_name, m.month_id,
           CONCAT(p.table_prefix, '202601', p.table_suffix) AS baseline_table,
           CONCAT(p.table_prefix, m.month_id, p.table_suffix) AS current_table
    FROM months m CROSS JOIN platforms p
)
SELECT e.platform_name, e.month_id, b.column_name,
       b.column_type AS baseline_type,
       c.column_type AS current_type,
       CASE WHEN c.column_name IS NULL THEN 'MISSING'
            WHEN c.column_type <> b.column_type THEN 'TYPE_CHANGED'
            ELSE 'OK' END AS drift_status
FROM expected e
JOIN information_schema.columns b
  ON b.table_schema = 'ec_cross_border'
 AND b.table_name = e.baseline_table
LEFT JOIN information_schema.columns c
  ON c.table_schema = 'ec_cross_border'
 AND c.table_name = e.current_table
 AND c.column_name = b.column_name
WHERE c.column_name IS NULL OR c.column_type <> b.column_type
ORDER BY e.platform_name, e.month_id, b.ordinal_position;

-- Dimension fields required by Day 3; must return zero rows.
WITH required AS (
    SELECT 'id' AS column_name UNION ALL SELECT 'platform' UNION ALL SELECT 'platform_id'
    UNION ALL SELECT 'shop_id' UNION ALL SELECT 'company' UNION ALL SELECT 'company_address'
    UNION ALL SELECT 'province' UNION ALL SELECT 'city' UNION ALL SELECT 'county'
    UNION ALL SELECT 'created_time' UNION ALL SELECT 'updated_time'
)
SELECT r.column_name AS missing_dim_column
FROM required r
LEFT JOIN information_schema.columns c
  ON c.table_schema = 'ec_cross_dw'
 AND c.table_name = 'dim_company_basic'
 AND c.column_name = r.column_name
WHERE c.column_name IS NULL;

