# Day7-Day8 Streamlit 看板

## 前置条件

先按根目录 README 完成 DWD、DWS 和 DM 刷新。看板默认读取所有 `_2026_gj` 表，不读取旧成果。

## 配置

```powershell
Copy-Item .streamlit\secrets.toml.example .streamlit\secrets.toml
```

编辑 `.streamlit/secrets.toml`，填写数据库账号。真实密码文件已加入 `.gitignore`，不要提交或放入 README。

## 启动

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m streamlit run app.py
```

## 指标与联动

- 月份和平台影响全部图表。
- 省份、城市用于区域下拉、区县排行和地图。
- 多平台类目 TOP10 会在查询时重新汇总排名。
- 企业排行读取 DM 已计算的每平台 TOP20；选择多个平台时分别展示，
  不在页面运行时重新聚合完整企业排行表。
- 正增长使用红色、负增长使用绿色，符合中国业务看板习惯。
- 装载2025平台月基期并刷新DM后显示实际同比；缺失或0基期仍显示“无可用同期基期”。

## 地区筛选口径

- 省份统一显示标准行政区名称，例如“云南”和“云南省”合并为“云南省”。
- 城市中同时存在简称和“市”后缀时合并，例如“昆明”和“昆明市”。
- 非行政区值不进入筛选列表，但底层数据不删除。
- 选择标准名称时会同时匹配其全部原始别名，避免漏计销售额。
