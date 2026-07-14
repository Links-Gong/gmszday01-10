SET NAMES utf8mb4;
USE ec_cross_ceshi;

CREATE TABLE IF NOT EXISTS dwd_sales_detail_2026_gj (
    id                        BIGINT NOT NULL AUTO_INCREMENT,
    month_id                  INT NOT NULL COMMENT 'YYYYMM',
    platform_id               TINYINT NOT NULL COMMENT '1=SMT,2=Amazon,3=Alibaba,4=Ozon',
    platform_name             VARCHAR(50) NOT NULL,
    shop_id                   VARCHAR(255) NOT NULL,
    shop_name                 VARCHAR(500) NULL,
    company_name              VARCHAR(500) NULL,
    company_address           VARCHAR(1000) NULL,
    country                   VARCHAR(255) NULL,
    province                  VARCHAR(255) NULL,
    city                      VARCHAR(255) NULL,
    county                    VARCHAR(255) NULL,
    sales_num                 DECIMAL(28,4) NULL,
    sales_money               DECIMAL(28,2) NULL COMMENT 'RMB',
    currency_type             VARCHAR(10) NOT NULL DEFAULT 'RMB',
    category_id               VARCHAR(100) NULL,
    category_name             VARCHAR(255) NULL,
    source_row_count          BIGINT NOT NULL DEFAULT 0,
    invalid_sales_num_count   BIGINT NOT NULL DEFAULT 0,
    invalid_sales_money_count BIGINT NOT NULL DEFAULT 0,
    dim_match_flag            TINYINT NOT NULL DEFAULT 0,
    created_time              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_month_platform_shop (month_id, platform_id, shop_id),
    KEY idx_platform_month (platform_id, month_id),
    KEY idx_region_month (month_id, province, city, county),
    KEY idx_category_month (month_id, category_name),
    KEY idx_company_month (month_id, company_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='2026H1 four-platform shop-month DWD';

CREATE TABLE IF NOT EXISTS stg_dwd_sales_detail_2026_gj (
    month_id                  INT NOT NULL,
    platform_id               TINYINT NOT NULL,
    platform_name             VARCHAR(50) NOT NULL,
    shop_id                   VARCHAR(255) NOT NULL,
    shop_name                 VARCHAR(500) NULL,
    company_name              VARCHAR(500) NULL,
    company_address           VARCHAR(1000) NULL,
    country                   VARCHAR(255) NULL,
    province                  VARCHAR(255) NULL,
    city                      VARCHAR(255) NULL,
    county                    VARCHAR(255) NULL,
    sales_num                 DECIMAL(28,4) NULL,
    sales_money               DECIMAL(28,2) NULL,
    currency_type             VARCHAR(10) NOT NULL DEFAULT 'RMB',
    category_id               VARCHAR(100) NULL,
    category_name             VARCHAR(255) NULL,
    source_row_count          BIGINT NOT NULL DEFAULT 0,
    invalid_sales_num_count   BIGINT NOT NULL DEFAULT 0,
    invalid_sales_money_count BIGINT NOT NULL DEFAULT 0,
    dim_match_flag            TINYINT NOT NULL DEFAULT 0,
    PRIMARY KEY (month_id, platform_id, shop_id),
    KEY idx_stg_batch (month_id, platform_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Restartable DWD batch staging';

CREATE TABLE IF NOT EXISTS stg_dim_company_basic_2026_gj (
    platform       VARCHAR(20) NOT NULL,
    platform_id    TINYINT NOT NULL,
    shop_id        VARCHAR(255) NOT NULL,
    company_name   VARCHAR(500) NULL,
    company_address VARCHAR(1000) NULL,
    province       VARCHAR(255) NULL,
    city           VARCHAR(255) NULL,
    county         VARCHAR(255) NULL,
    PRIMARY KEY (platform, platform_id, shop_id),
    KEY idx_dim_platform_shop (platform_id, shop_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Latest deduplicated company dimension rows';

CREATE TABLE IF NOT EXISTS etl_load_audit_2026_gj (
    batch_key                 VARCHAR(30) NOT NULL,
    month_id                  INT NOT NULL,
    platform_id               TINYINT NOT NULL,
    platform_name             VARCHAR(50) NOT NULL,
    source_table              VARCHAR(128) NOT NULL,
    source_row_count          BIGINT NULL,
    empty_shop_id_count       BIGINT NULL,
    valid_shop_count          BIGINT NULL,
    staged_row_count          BIGINT NULL,
    target_row_count          BIGINT NULL,
    staged_sales_money_rmb    DECIMAL(38,2) NULL,
    target_sales_money_rmb    DECIMAL(38,2) NULL,
    status                    VARCHAR(20) NOT NULL,
    message                   VARCHAR(500) NULL,
    started_time              DATETIME NOT NULL,
    completed_time            DATETIME NULL,
    PRIMARY KEY (batch_key),
    UNIQUE KEY uk_audit_month_platform (month_id, platform_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DROP PROCEDURE IF EXISTS sp_promote_dwd_batch_2026_gj;
DELIMITER $$
CREATE PROCEDURE sp_promote_dwd_batch_2026_gj(
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
        UPDATE etl_load_audit_2026_gj
           SET status = 'FAILED',
               message = 'Validation or transactional promotion failed',
               completed_time = CURRENT_TIMESTAMP
         WHERE month_id = p_month_id AND platform_id = p_platform_id;
        RESIGNAL;
    END;

    SELECT valid_shop_count
      INTO v_expected_rows
      FROM etl_load_audit_2026_gj
     WHERE month_id = p_month_id AND platform_id = p_platform_id;

    SELECT COUNT(*), ROUND(SUM(sales_money), 2)
      INTO v_staged_rows, v_staged_money
      FROM stg_dwd_sales_detail_2026_gj
     WHERE month_id = p_month_id AND platform_id = p_platform_id;

    IF v_expected_rows IS NULL OR v_staged_rows <> v_expected_rows THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Staged row count does not equal valid source shop count';
    END IF;

    START TRANSACTION;

    DELETE FROM dwd_sales_detail_2026_gj
     WHERE month_id = p_month_id AND platform_id = p_platform_id;

    INSERT INTO dwd_sales_detail_2026_gj (
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
    FROM stg_dwd_sales_detail_2026_gj
    WHERE month_id = p_month_id AND platform_id = p_platform_id;

    SET v_target_rows = ROW_COUNT();
    IF v_target_rows <> v_staged_rows THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Target insert count does not equal staged row count';
    END IF;

    COMMIT;

    SELECT ROUND(SUM(sales_money), 2)
      INTO v_target_money
      FROM dwd_sales_detail_2026_gj
     WHERE month_id = p_month_id AND platform_id = p_platform_id;

    UPDATE etl_load_audit_2026_gj
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

