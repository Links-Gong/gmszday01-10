# Day3 DWD

## 目标表

`ec_cross_ceshi.dwd_sales_detail_2026_gj`，业务唯一键为：

```text
month_id + platform_id + shop_id
```

## 批次机制

`sql/load` 中每个文件只处理一个月、一个平台。脚本先重建该批次的暂存数据，再调用 `sp_promote_dwd_batch_2026_gj` 校验并事务性提升。


## 混合编码处理

部分源表的店铺 ID 或数值字段含原始 `0xA0` 不间断空格。装载模板会先在二进制层清除 `C2A0/A0` 和常见货币符号，再按原 UTF-8 解码，避免字符集转换中断或非 ASCII 店铺 ID 被按字节展开。真实 0 仍然保留。

## 脚本维护

24 个批次脚本由 `tools/generate_load_scripts.py` 生成。月份或模板变化时修改生成器，不要手工改其中一个月造成口径漂移。

生成2025同比基期脚本：

```powershell
..\dashboard\.venv\Scripts\python.exe tools\generate_load_scripts.py --year 2025
```

脚本输出到 `sql/load_2025`，写入独立的 `_2025_gj` 表。先运行
`sql/03_create_2025_baseline_tables.sql`，再按月份、平台依次运行24个脚本。
2025和2026共用 `stg_dim_company_basic_2026_gj`，因此维表暂存只需按
`sql/02_refresh_dim_stage.sql` 刷新。
