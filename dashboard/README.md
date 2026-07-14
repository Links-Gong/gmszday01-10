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
- 多平台类目 TOP10、企业 TOP20 会在查询时重新汇总排名。
- 正增长使用红色、负增长使用绿色，符合中国业务看板习惯。
- 同比固定显示“无同期基期”，不能显示为 0%。

