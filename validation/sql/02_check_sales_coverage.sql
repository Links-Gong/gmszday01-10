-- 2026H1 sales coverage investigation
-- Safety: every statement in this file is read-only SELECT.
-- Run one query block at a time if the database client has a short timeout.

/* --------------------------------------------------------------------------
   1. Monthly overall coverage

   money_valid_pct = shops with non-NULL sales_money / all DWD shop rows.
   A real zero is valid and is not counted as missing.
   Expected 202606 result: 442900 / 2232952 = 19.8347%.
   -------------------------------------------------------------------------- */
SELECT
    month_id,
    COUNT(*) AS shop_rows,
    SUM(CASE WHEN sales_money IS NOT NULL THEN 1 ELSE 0 END) AS money_valid_rows,
    SUM(CASE WHEN sales_money IS NULL THEN 1 ELSE 0 END) AS money_null_rows,
    SUM(CASE WHEN sales_money = 0 THEN 1 ELSE 0 END) AS money_zero_rows,
    SUM(CASE WHEN sales_money > 0 THEN 1 ELSE 0 END) AS money_positive_rows,
    ROUND(
        SUM(CASE WHEN sales_money IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100,
        4
    ) AS money_valid_pct
FROM ec_cross_ceshi.dwd_sales_detail_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
GROUP BY month_id
ORDER BY month_id;


/* --------------------------------------------------------------------------
   2. 202606 platform breakdown

   This identifies which platform lowers the overall coverage rate.
   invalid_* counts test whether non-empty source values were rejected during
   numeric cleaning.
   -------------------------------------------------------------------------- */
SELECT
    platform_id,
    platform_name,
    COUNT(*) AS shop_rows,
    SUM(CASE WHEN sales_money IS NOT NULL THEN 1 ELSE 0 END) AS money_valid_rows,
    SUM(CASE WHEN sales_money IS NULL THEN 1 ELSE 0 END) AS money_null_rows,
    SUM(CASE WHEN sales_money = 0 THEN 1 ELSE 0 END) AS money_zero_rows,
    SUM(CASE WHEN sales_money > 0 THEN 1 ELSE 0 END) AS money_positive_rows,
    ROUND(
        SUM(CASE WHEN sales_money IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100,
        4
    ) AS money_valid_pct,
    SUM(CASE WHEN sales_num IS NOT NULL THEN 1 ELSE 0 END) AS num_valid_rows,
    SUM(CASE WHEN sales_num IS NULL THEN 1 ELSE 0 END) AS num_null_rows,
    ROUND(
        SUM(CASE WHEN sales_num IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100,
        4
    ) AS num_valid_pct,
    SUM(CASE
        WHEN sales_money IS NULL AND sales_num IS NOT NULL THEN 1 ELSE 0
    END) AS money_null_but_num_valid_rows,
    SUM(invalid_sales_money_count) AS invalid_money_source_rows,
    SUM(invalid_sales_num_count) AS invalid_num_source_rows
FROM ec_cross_ceshi.dwd_sales_detail_2026_gj
WHERE month_id = 202606
GROUP BY platform_id, platform_name
ORDER BY platform_id;


/* --------------------------------------------------------------------------
   3. SMT raw source coverage

   SMT currently maps sales_month to DWD sales_money. sales_money is checked as
   a possible alternative. OCTET_LENGTH(CAST(... AS BINARY)) avoids conversion
   errors from malformed text bytes.
   -------------------------------------------------------------------------- */
SELECT
    COUNT(*) AS raw_rows,
    SUM(CASE WHEN shop_id IS NULL THEN 1 ELSE 0 END) AS null_shop_id_rows,
    SUM(CASE
        WHEN sales_num IS NOT NULL
         AND OCTET_LENGTH(CAST(sales_num AS BINARY)) > 0
        THEN 1 ELSE 0
    END) AS sales_num_nonempty_rows,
    SUM(CASE
        WHEN sales_money IS NOT NULL
         AND OCTET_LENGTH(CAST(sales_money AS BINARY)) > 0
        THEN 1 ELSE 0
    END) AS sales_money_nonempty_rows,
    SUM(CASE
        WHEN sales_month IS NOT NULL
         AND OCTET_LENGTH(CAST(sales_month AS BINARY)) > 0
        THEN 1 ELSE 0
    END) AS sales_month_nonempty_rows,
    SUM(CASE
        WHEN (sales_month IS NULL OR OCTET_LENGTH(CAST(sales_month AS BINARY)) = 0)
         AND sales_money IS NOT NULL
         AND OCTET_LENGTH(CAST(sales_money AS BINARY)) > 0
        THEN 1 ELSE 0
    END) AS month_empty_but_money_present_rows,
    SUM(CASE
        WHEN sales_month IS NOT NULL
         AND OCTET_LENGTH(CAST(sales_month AS BINARY)) > 0
         AND (sales_money IS NULL OR OCTET_LENGTH(CAST(sales_money AS BINARY)) = 0)
        THEN 1 ELSE 0
    END) AS month_present_but_money_empty_rows
FROM ec_cross_border.smt_shopinfo_202606;


/* --------------------------------------------------------------------------
   4. Amazon raw source coverage
   -------------------------------------------------------------------------- */
SELECT
    COUNT(*) AS raw_rows,
    SUM(CASE WHEN shop_id IS NULL THEN 1 ELSE 0 END) AS null_shop_id_rows,
    SUM(CASE WHEN sales_money IS NULL THEN 1 ELSE 0 END) AS money_null_rows,
    SUM(CASE
        WHEN sales_money IS NOT NULL
         AND OCTET_LENGTH(CAST(sales_money AS BINARY)) = 0
        THEN 1 ELSE 0
    END) AS money_empty_rows,
    SUM(CASE WHEN sales IS NULL THEN 1 ELSE 0 END) AS num_null_rows,
    SUM(CASE
        WHEN sales IS NOT NULL
         AND OCTET_LENGTH(CAST(sales AS BINARY)) = 0
        THEN 1 ELSE 0
    END) AS num_empty_rows
FROM ec_cross_border.amazonus_shopinfo_202606_sales;


/* --------------------------------------------------------------------------
   5. Alibaba raw source coverage

   The raw table can contain duplicate shop records. This query only diagnoses
   source-field completeness; DWD coverage should be checked at shop grain in
   query 2.
   -------------------------------------------------------------------------- */
SELECT
    COUNT(*) AS raw_rows,
    SUM(CASE WHEN shop_id IS NULL THEN 1 ELSE 0 END) AS null_shop_id_rows,
    SUM(CASE WHEN sales_money IS NULL THEN 1 ELSE 0 END) AS money_null_rows,
    SUM(CASE
        WHEN sales_money IS NOT NULL
         AND OCTET_LENGTH(CAST(sales_money AS BINARY)) = 0
        THEN 1 ELSE 0
    END) AS money_empty_rows,
    SUM(CASE WHEN sales IS NULL THEN 1 ELSE 0 END) AS num_null_rows,
    SUM(CASE
        WHEN sales IS NOT NULL
         AND OCTET_LENGTH(CAST(sales AS BINARY)) = 0
        THEN 1 ELSE 0
    END) AS num_empty_rows
FROM ec_cross_border.alibabagj_shopinfo_202606;


/* --------------------------------------------------------------------------
   6. Ozon raw source coverage
   -------------------------------------------------------------------------- */
SELECT
    COUNT(*) AS raw_rows,
    SUM(CASE WHEN shop_id IS NULL THEN 1 ELSE 0 END) AS null_shop_id_rows,
    SUM(CASE WHEN sales_money IS NULL THEN 1 ELSE 0 END) AS money_null_rows,
    SUM(CASE
        WHEN sales_money IS NOT NULL
         AND OCTET_LENGTH(CAST(sales_money AS BINARY)) = 0
        THEN 1 ELSE 0
    END) AS money_empty_rows,
    SUM(CASE WHEN sales_num IS NULL THEN 1 ELSE 0 END) AS num_null_rows,
    SUM(CASE
        WHEN sales_num IS NOT NULL
         AND OCTET_LENGTH(CAST(sales_num AS BINARY)) = 0
        THEN 1 ELSE 0
    END) AS num_empty_rows
FROM ec_cross_border.ozon_shopinfo_202606_cn;


/* --------------------------------------------------------------------------
   7. Determine whether missingness is persistent or only a June issue

   Stable low coverage across all six months suggests a structural source-data
   characteristic. A sudden one-month drop suggests an upstream collection or
   loading incident.
   -------------------------------------------------------------------------- */
SELECT
    month_id,
    platform_id,
    MAX(platform_name) AS platform_name,
    COUNT(*) AS shop_rows,
    SUM(CASE WHEN sales_money IS NOT NULL THEN 1 ELSE 0 END) AS money_valid_rows,
    ROUND(
        SUM(CASE WHEN sales_money IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100,
        4
    ) AS money_valid_pct,
    SUM(CASE WHEN sales_num IS NOT NULL THEN 1 ELSE 0 END) AS num_valid_rows,
    ROUND(
        SUM(CASE WHEN sales_num IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100,
        4
    ) AS num_valid_pct
FROM ec_cross_ceshi.dwd_sales_detail_2026_gj
WHERE month_id BETWEEN 202601 AND 202606
GROUP BY month_id, platform_id
ORDER BY month_id, platform_id;


/* --------------------------------------------------------------------------
   8. Missing in June but valid in another 2026H1 month

   This is diagnostic only. Historical values must not be copied into June.
   -------------------------------------------------------------------------- */
SELECT
    june.platform_id,
    MAX(june.platform_name) AS platform_name,
    COUNT(*) AS june_missing_shops,
    SUM(CASE WHEN history.shop_id IS NOT NULL THEN 1 ELSE 0 END)
        AS valid_in_other_month_shops,
    ROUND(
        SUM(CASE WHEN history.shop_id IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100,
        4
    ) AS valid_in_other_month_pct
FROM ec_cross_ceshi.dwd_sales_detail_2026_gj june
LEFT JOIN (
    SELECT DISTINCT platform_id, shop_id
    FROM ec_cross_ceshi.dwd_sales_detail_2026_gj
    WHERE month_id BETWEEN 202601 AND 202605
      AND sales_money IS NOT NULL
) history
  ON history.platform_id = june.platform_id
 AND history.shop_id = june.shop_id
WHERE june.month_id = 202606
  AND june.sales_money IS NULL
GROUP BY june.platform_id
ORDER BY june.platform_id;
