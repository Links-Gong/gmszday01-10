# 2026 上半年跨境电商实训成果

本目录是基于 202601-202606 的版本

## 数据链路

```text
ec_cross_border 月表
        |
        v
ec_cross_ceshi.dwd_sales_detail_2026_gj
        |
        v
DWS 平台 / 区域 / 类目汇总
        |
        v
DM 月度指标 / 企业排行
        |
        v
Streamlit 看板
        |
        v
Day9 全链路验证
```

## 固定口径

- 月份：202601-202606。
- 平台：SMT=1、Amazon=2、Alibaba=3、Ozon=4。
- DWD 粒度：`month_id + platform_id + shop_id`，每店铺每月一行。
- 销售额统一为人民币：SMT 和 Amazon 乘 7.2，Alibaba 乘 2.25，Ozon 原值。
- 可选装载 202501-202506 作为同比基期；未装载或基期为0时，同比保持 SQL `NULL`。
- 真实 0 保留；缺失值和非法数值不替换成 0。

## 执行顺序

1. 运行 `ods/sql/01_preflight_source_tables.sql`。缺表、缺字段、字段漂移查询必须返回 0 行。
2. 运行 `dwd/sql/01_create_tables.sql`。
3. 运行 `dwd/sql/02_refresh_dim_stage.sql`。
4. 按文件名顺序运行 `dwd/sql/load` 下 24 个批次脚本。一个脚本完成后再执行下一个。
5. 运行 `dwd/sql/90_validate_dwd.sql` 和 `dwd/sql/91_validate_ozon_dedup.sql`。验证
6. 依次运行 `dws/sql/01_create_tables.sql`、三个刷新脚本和验证脚本。
7. 依次运行 `dm/sql/01_create_tables.sql`、两个刷新脚本和验证脚本。
8. 按 `dashboard/README.md` 配置并启动看板。
9. 运行 `validation/sql/01_day9_end_to_end_validation.sql`，并查看
   `validation/README.md` 中的 Day9 验证结论。

### 可选：装载2025同比基期

1. 运行 `dwd/sql/03_create_2025_baseline_tables.sql`。
2. 用 `dwd/tools/generate_load_scripts.py --year 2025` 生成脚本。
3. 按文件名顺序运行 `dwd/sql/load_2025` 下24个批次脚本。
4. 运行 `dwd/sql/92_validate_dwd_2025.sql`，确认24批全部成功。
5. 运行 `dws/sql/05_create_refresh_platform_month_2025.sql`，确认返回24行。
6. 重新运行 `dm/sql/02_refresh_monthly_metrics.sql`，再运行
   `dm/sql/04_refresh_yoy_from_2025.sql` 和 `dm/sql/90_validate_dm.sql`。

## 超时与重跑

每个平台月份先写入 `stg_dwd_sales_detail_2026_gj`。只有暂存行数等于源表有效店铺数时，存储过程才会在事务中替换正式表对应批次。

- 暂存阶段超时：正式 DWD 不受影响，直接重跑当前脚本。
- 正式提升阶段报错：先在当前连接执行 `ROLLBACK;`，然后重跑当前脚本。
- 不用 `TRUNCATE` 正式 DWD

## 结果归档

每层 `results` 目录都有应导出的查询清单，并保留 SQL 文件名作为结果文件名前缀。

## Day9 验证

- 验证报告：`validation/README.md`
- 统一只读 SQL：`validation/sql/01_day9_end_to_end_validation.sql`
- PASS/FAIL 汇总：`validation/results/day9_validation_summary.csv`
- 看板组件检查：`validation/results/06_dashboard_checks.csv`

当前 2025/2026 DWD、DWS、DM 和同比对账均已通过。省市别名已在看板层统一，
企业排行直接读取 DM 的每平台 TOP20，避免运行时扫描完整排行表。
