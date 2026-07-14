SET NAMES utf8mb4;

-- Sample duplicated Ozon shop-product keys before DWD aggregation.
-- Each query is independent; run one month at a time if the client is slow.
SELECT 202601 AS month_id, TRIM(CAST(shop_id AS CHAR)) AS shop_id,
       TRIM(CAST(goods_id AS CHAR)) AS goods_id, COUNT(*) AS source_rows
FROM ec_cross_border.ozon_shopinfo_202601_cn
WHERE shop_id IS NOT NULL AND TRIM(CAST(shop_id AS CHAR)) <> ''
  AND goods_id IS NOT NULL AND TRIM(CAST(goods_id AS CHAR)) <> ''
GROUP BY TRIM(CAST(shop_id AS CHAR)), TRIM(CAST(goods_id AS CHAR))
HAVING COUNT(*) > 1
ORDER BY source_rows DESC LIMIT 20;

SELECT 202602 AS month_id, TRIM(CAST(shop_id AS CHAR)) AS shop_id,
       TRIM(CAST(goods_id AS CHAR)) AS goods_id, COUNT(*) AS source_rows
FROM ec_cross_border.ozon_shopinfo_202602_cn
WHERE shop_id IS NOT NULL AND TRIM(CAST(shop_id AS CHAR)) <> ''
  AND goods_id IS NOT NULL AND TRIM(CAST(goods_id AS CHAR)) <> ''
GROUP BY TRIM(CAST(shop_id AS CHAR)), TRIM(CAST(goods_id AS CHAR))
HAVING COUNT(*) > 1
ORDER BY source_rows DESC LIMIT 20;

SELECT 202603 AS month_id, TRIM(CAST(shop_id AS CHAR)) AS shop_id,
       TRIM(CAST(goods_id AS CHAR)) AS goods_id, COUNT(*) AS source_rows
FROM ec_cross_border.ozon_shopinfo_202603_cn
WHERE shop_id IS NOT NULL AND TRIM(CAST(shop_id AS CHAR)) <> ''
  AND goods_id IS NOT NULL AND TRIM(CAST(goods_id AS CHAR)) <> ''
GROUP BY TRIM(CAST(shop_id AS CHAR)), TRIM(CAST(goods_id AS CHAR))
HAVING COUNT(*) > 1
ORDER BY source_rows DESC LIMIT 20;

SELECT 202604 AS month_id, TRIM(CAST(shop_id AS CHAR)) AS shop_id,
       TRIM(CAST(goods_id AS CHAR)) AS goods_id, COUNT(*) AS source_rows
FROM ec_cross_border.ozon_shopinfo_202604_cn
WHERE shop_id IS NOT NULL AND TRIM(CAST(shop_id AS CHAR)) <> ''
  AND goods_id IS NOT NULL AND TRIM(CAST(goods_id AS CHAR)) <> ''
GROUP BY TRIM(CAST(shop_id AS CHAR)), TRIM(CAST(goods_id AS CHAR))
HAVING COUNT(*) > 1
ORDER BY source_rows DESC LIMIT 20;

SELECT 202605 AS month_id, TRIM(CAST(shop_id AS CHAR)) AS shop_id,
       TRIM(CAST(goods_id AS CHAR)) AS goods_id, COUNT(*) AS source_rows
FROM ec_cross_border.ozon_shopinfo_202605_cn
WHERE shop_id IS NOT NULL AND TRIM(CAST(shop_id AS CHAR)) <> ''
  AND goods_id IS NOT NULL AND TRIM(CAST(goods_id AS CHAR)) <> ''
GROUP BY TRIM(CAST(shop_id AS CHAR)), TRIM(CAST(goods_id AS CHAR))
HAVING COUNT(*) > 1
ORDER BY source_rows DESC LIMIT 20;

SELECT 202606 AS month_id, TRIM(CAST(shop_id AS CHAR)) AS shop_id,
       TRIM(CAST(goods_id AS CHAR)) AS goods_id, COUNT(*) AS source_rows
FROM ec_cross_border.ozon_shopinfo_202606_cn
WHERE shop_id IS NOT NULL AND TRIM(CAST(shop_id AS CHAR)) <> ''
  AND goods_id IS NOT NULL AND TRIM(CAST(goods_id AS CHAR)) <> ''
GROUP BY TRIM(CAST(shop_id AS CHAR)), TRIM(CAST(goods_id AS CHAR))
HAVING COUNT(*) > 1
ORDER BY source_rows DESC LIMIT 20;

