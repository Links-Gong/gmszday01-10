# ODS / 源表预检

本层不复制 `ec_cross_border` 原始表，只记录 24 张月表的存在性、字段完整性和跨月字段漂移。

先运行 `sql/01_preflight_source_tables.sql`。只有以下条件同时满足才进入 DWD：

- `table_status` 全部为 `OK`；
- 缺少必需字段的查询返回 0 行；
- 相对 202601 的字段漂移查询返回 0 行；
- MySQL 主版本为 8。

