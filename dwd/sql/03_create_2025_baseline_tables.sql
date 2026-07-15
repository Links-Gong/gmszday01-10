SET NAMES utf8mb4;
USE ec_cross_ceshi;

-- Run dwd/sql/01_create_tables.sql first. The 2025 baseline uses the same
-- schema and the shared deduplicated company dimension stage as 2026.
CREATE TABLE IF NOT EXISTS dwd_sales_detail_2025_gj
LIKE dwd_sales_detail_2026_gj;

CREATE TABLE IF NOT EXISTS stg_dwd_sales_detail_2025_gj
LIKE stg_dwd_sales_detail_2026_gj;

CREATE TABLE IF NOT EXISTS etl_load_audit_2025_gj
LIKE etl_load_audit_2026_gj;

DROP PROCEDURE IF EXISTS sp_promote_dwd_batch_2025_gj;
DELIMITER $$
CREATE PROCEDURE sp_promote_dwd_batch_2025_gj(
    IN p_month_id INT,
    IN p_platform_id TINYINT
)
BEGIN
    DECLARE v_expected_rows BIGINT DEFAULT NULL;
    DECLARE v_staged_rows BIGINT DEFAULT 0;
    DECLARE v_target_rows BIGINT DEFAULT 0;
    DECLARE v_staged_money DECIMAL(38,2) DEFAULT NULL;
    DECLARE v_target_money DECIMAL(38,2) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        UPDATE etl_load_audit_2025_gj
           SET status = 'FAILED',
               message = 'Validation or transactional promotion failed',
               completed_time = CURRENT_TIMESTAMP
         WHERE month_id = p_month_id AND platform_id = p_platform_id;
        RESIGNAL;
    END;

    SELECT valid_shop_count
      INTO v_expected_rows
      FROM etl_load_audit_2025_gj
     WHERE month_id = p_month_id AND platform_id = p_platform_id;

    SELECT COUNT(*), ROUND(SUM(sales_money), 2)
      INTO v_staged_rows, v_staged_money
      FROM stg_dwd_sales_detail_2025_gj
     WHERE month_id = p_month_id AND platform_id = p_platform_id;

    IF v_expected_rows IS NULL OR v_staged_rows <> v_expected_rows THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Staged row count does not equal valid source shop count';
    END IF;

    START TRANSACTION;

    DELETE FROM dwd_sales_detail_2025_gj
     WHERE month_id = p_month_id AND platform_id = p_platform_id;

    INSERT INTO dwd_sales_detail_2025_gj (
        month_id, platform_id, platform_name, shop_id, shop_name,
        company_name, company_address, country, province, city, county,
        sales_num, sales_money, currency_type, category_id, category_name,
        source_row_count, invalid_sales_num_count, invalid_sales_money_count,
        dim_match_flag
    )
    SELECT
        month_id, platform_id, platform_name, shop_id, shop_name,
        company_name, company_address, country, province, city, county,
        sales_num, sales_money, currency_type, category_id, category_name,
        source_row_count, invalid_sales_num_count, invalid_sales_money_count,
        dim_match_flag
    FROM stg_dwd_sales_detail_2025_gj
    WHERE month_id = p_month_id AND platform_id = p_platform_id;

    SET v_target_rows = ROW_COUNT();
    IF v_target_rows <> v_staged_rows THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Target insert count does not equal staged row count';
    END IF;

    COMMIT;

    SELECT ROUND(SUM(sales_money), 2)
      INTO v_target_money
      FROM dwd_sales_detail_2025_gj
     WHERE month_id = p_month_id AND platform_id = p_platform_id;

    UPDATE etl_load_audit_2025_gj
       SET staged_row_count = v_staged_rows,
           target_row_count = v_target_rows,
           staged_sales_money_rmb = v_staged_money,
           target_sales_money_rmb = v_target_money,
           status = 'SUCCESS',
           message = 'Batch validated and committed',
           completed_time = CURRENT_TIMESTAMP
     WHERE month_id = p_month_id AND platform_id = p_platform_id;
END$$
DELIMITER ;
