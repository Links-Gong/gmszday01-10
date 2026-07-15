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
```

## 固定口径

- 月份：202601-202606。
- 平台：SMT=1、Amazon=2、Alibaba=3、Ozon=4。
- DWD 粒度：`month_id + platform_id + shop_id`，每店铺每月一行。
- 销售额统一为人民币：SMT 和 Amazon 乘 7.2，Alibaba 乘 2.25，Ozon 原值。
- 本次没有做 2025 同期，同比字段保持 SQL `NULL`，看板显示“无同期基期”。
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

## 超时与重跑

每个平台月份先写入 `stg_dwd_sales_detail_2026_gj`。只有暂存行数等于源表有效店铺数时，存储过程才会在事务中替换正式表对应批次。

- 暂存阶段超时：正式 DWD 不受影响，直接重跑当前脚本。
- 正式提升阶段报错：先在当前连接执行 `ROLLBACK;`，然后重跑当前脚本。
- 不用 `TRUNCATE` 正式 DWD

## 结果归档

每层 `results` 目录都有应导出的查询清单，并保留 SQL 文件名作为结果文件名前缀。

