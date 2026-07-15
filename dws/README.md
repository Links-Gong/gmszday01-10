# Day4 DWS

本层只读取 `dwd_sales_detail_2026_gj`，生成平台月、区域月、类目月三类汇总。

- 平台月：保存上月销售额和环比百分比。
- 区域月：保留平台维度，并用 `region_level` 区分全国、省级、市级和区县级。
- 类目月：基础表保留全部类目，TOP10 表按月、平台排名。
- Ozon 的类目在 DWD 中保持 `NULL`，汇总展示为“未分类”。

刷新脚本只删除 202601-202606，不影响同名表中范围外的数据。

同比基期使用 `sql/05_create_refresh_platform_month_2025.sql`，从
`dwd_sales_detail_2025_gj` 生成24行 `dws_platform_month_summary_2025_gj`。
