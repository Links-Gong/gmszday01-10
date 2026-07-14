SET NAMES utf8mb4;
USE ec_cross_ceshi;

CREATE TABLE IF NOT EXISTS dws_platform_month_summary_2026_gj (
    month_id           INT NOT NULL,
    platform_id        TINYINT NOT NULL,
    platform_name      VARCHAR(50) NOT NULL,
    total_sales_rmb    DECIMAL(38,2) NULL,
    total_sales_num    DECIMAL(38,4) NULL,
    shop_count         BIGINT NOT NULL,
    money_valid_rows   BIGINT NOT NULL,
    num_valid_rows     BIGINT NOT NULL,
    last_sales_rmb     DECIMAL(38,2) NULL,
    mom_growth_pct     DECIMAL(18,4) NULL COMMENT 'percentage, not ratio',
    created_time       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (month_id, platform_id),
    KEY idx_dws_platform_name (platform_name, month_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS dws_region_month_summary_2026_gj (
    id                  BIGINT NOT NULL AUTO_INCREMENT,
    month_id            INT NOT NULL,
    platform_id         TINYINT NOT NULL,
    platform_name       VARCHAR(50) NOT NULL,
    province            VARCHAR(255) NOT NULL,
    city                VARCHAR(255) NOT NULL,
    county              VARCHAR(255) NOT NULL,
    region_level        VARCHAR(20) NOT NULL,
    total_sales_rmb     DECIMAL(38,2) NULL,
    total_sales_num     DECIMAL(38,4) NULL,
    shop_count          BIGINT NOT NULL,
    money_valid_rows    BIGINT NOT NULL,
    num_valid_rows      BIGINT NOT NULL,
    created_time        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_region_level (month_id, platform_id, region_level),
    KEY idx_region_filter (month_id, platform_id, region_level,
                           province(50), city(50), county(50))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS dws_category_month_summary_2026_gj (
    id                  BIGINT NOT NULL AUTO_INCREMENT,
    month_id            INT NOT NULL,
    platform_id         TINYINT NOT NULL,
    platform_name       VARCHAR(50) NOT NULL,
    category_name       VARCHAR(255) NOT NULL,
    total_sales_rmb     DECIMAL(38,2) NULL,
    total_sales_num     DECIMAL(38,4) NULL,
    shop_count          BIGINT NOT NULL,
    money_valid_rows    BIGINT NOT NULL,
    created_time        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_category_filter (month_id, platform_id, category_name(100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS dws_category_month_top10_2026_gj (
    id                  BIGINT NOT NULL AUTO_INCREMENT,
    month_id            INT NOT NULL,
    platform_id         TINYINT NOT NULL,
    platform_name       VARCHAR(50) NOT NULL,
    category_name       VARCHAR(255) NOT NULL,
    total_sales_rmb     DECIMAL(38,2) NULL,
    total_sales_num     DECIMAL(38,4) NULL,
    shop_count          BIGINT NOT NULL,
    sales_pct           DECIMAL(18,4) NULL,
    category_rank       INT NOT NULL,
    created_time        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_category_rank (month_id, platform_id, category_rank)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

