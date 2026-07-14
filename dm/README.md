# Day5-Day6 DM

本层生成两类业务结果：

- 月度业务指标：零售额、销量、快递收入估算、快递量估算、环比和店铺数。
- 企业销售排行：按月份、平台和企业聚合，并在每个平台内排名。

本次只有 2026 上半年，没有 2025 同期，因此：

```text
last_year_sales_rmb = NULL
yoy_growth_pct      = NULL
yoy_status          = NO_BASELINE
```

不能把缺少基期解释为同比 0%。

