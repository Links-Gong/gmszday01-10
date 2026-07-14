SET NAMES utf8mb4;
USE ec_cross_ceshi;

CREATE TABLE IF NOT EXISTS dm_monthly_business_metrics_2026_gj (
    month_id               INT NOT NULL,
    platform_id            TINYINT NOT NULL,
    platform_name          VARCHAR(50) NOT NULL,
    retail_sales_rmb       DECIMAL(38,2) NULL,
    retail_sales_num       DECIMAL(38,4) NULL,
    express_revenue_rmb    DECIMAL(38,2) NULL,
    express_volume         DECIMAL(38,4) NULL,
    previous_month_sales_rmb DECIMAL(38,2) NULL,
    mom_growth_pct         DECIMAL(18,4) NULL,
    last_year_sales_rmb    DECIMAL(38,2) NULL,
    yoy_growth_pct         DECIMAL(18,4) NULL,
    shop_count             BIGINT NOT NULL,
    valid_money_rows       BIGINT NOT NULL,
    metric_status          VARCHAR(50) NOT NULL,
    yoy_status             VARCHAR(50) NOT NULL,
    created_time           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (month_id, platform_id),
    KEY idx_dm_platform (platform_name, month_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS dm_enterprise_sales_rank_2026_gj (
    id                  BIGINT NOT NULL AUTO_INCREMENT,
    month_id            INT NOT NULL,
    platform_id         TINYINT NOT NULL,
    platform_name       VARCHAR(50) NOT NULL,
    company_name        VARCHAR(500) NOT NULL,
    total_sales_rmb     DECIMAL(38,2) NULL,
    total_sales_num     DECIMAL(38,4) NULL,
    shop_count          BIGINT NOT NULL,
    enterprise_rank     BIGINT NOT NULL,
    created_time        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_enterprise_rank (month_id, platform_id, enterprise_rank),
    KEY idx_enterprise_name (month_id, company_name(100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

