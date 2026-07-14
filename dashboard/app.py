import os
import re
from typing import Any

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st
from plotly.subplots import make_subplots
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL


st.set_page_config(
    page_title="跨境电商业务监测",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown(
    """
    <style>
    :root { --accent: #b42318; --ink: #172026; --muted: #667085; }
    .stApp { background: #f6f7f8; color: var(--ink); }
    [data-testid="stMetric"] {
        background: #ffffff;
        border: 1px solid #e4e7ec;
        border-left: 3px solid var(--accent);
        border-radius: 4px;
        padding: 12px 14px;
        min-height: 112px;
    }
    [data-testid="stMetricLabel"] { color: var(--muted); }
    [data-testid="stSidebar"] { border-right: 1px solid #e4e7ec; }
    h1, h2, h3 { letter-spacing: 0; }
    </style>
    """,
    unsafe_allow_html=True,
)


PLATFORM_LABELS = {
    "SMT": "速卖通",
    "Amazon": "亚马逊美国",
    "Alibaba": "阿里巴巴国际站",
    "Ozon": "Ozon",
}

PROVINCE_COORDS = {
    "北京市": (39.9042, 116.4074),
    "天津市": (39.0842, 117.2009),
    "河北省": (38.0428, 114.5149),
    "山西省": (37.8706, 112.5489),
    "内蒙古自治区": (40.8175, 111.7652),
    "辽宁省": (41.8057, 123.4315),
    "吉林省": (43.8171, 125.3235),
    "黑龙江省": (45.8038, 126.5349),
    "上海市": (31.2304, 121.4737),
    "江苏省": (32.0603, 118.7969),
    "浙江省": (30.2741, 120.1551),
    "安徽省": (31.8206, 117.2272),
    "福建省": (26.0745, 119.2965),
    "江西省": (28.6820, 115.8579),
    "山东省": (36.6512, 117.1201),
    "河南省": (34.7466, 113.6254),
    "湖北省": (30.5928, 114.3055),
    "湖南省": (28.2282, 112.9388),
    "广东省": (23.1291, 113.2644),
    "广西壮族自治区": (22.8170, 108.3665),
    "海南省": (20.0440, 110.1999),
    "重庆市": (29.5630, 106.5516),
    "四川省": (30.5728, 104.0668),
    "贵州省": (26.6470, 106.6302),
    "云南省": (25.0389, 102.7183),
    "西藏自治区": (29.6520, 91.1721),
    "陕西省": (34.3416, 108.9398),
    "甘肃省": (36.0611, 103.8343),
    "青海省": (36.6171, 101.7782),
    "宁夏回族自治区": (38.4872, 106.2309),
    "新疆维吾尔自治区": (43.8256, 87.6168),
}


def secret(name: str, default: str = "") -> str:
    try:
        return str(st.secrets.get(name, os.getenv(name, default)))
    except Exception:
        return os.getenv(name, default)


def quote_table(name: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_]+(?:[.][A-Za-z0-9_]+)?", name):
        raise ValueError(f"Invalid SQL table identifier: {name}")
    return ".".join(f"`{part}`" for part in name.split("."))


DB_CONFIG = {
    "host": secret("DB_HOST", "127.0.0.1"),
    "port": int(secret("DB_PORT", "3306")),
    "user": secret("DB_USER"),
    "password": secret("DB_PASSWORD"),
    "database": secret("DB_NAME", "ec_cross_ceshi"),
}

DWD_TABLE = quote_table(secret("DWD_TABLE", "dwd_sales_detail_2026_gj"))
DM_TABLE = quote_table(secret("DM_TABLE", "dm_monthly_business_metrics_2026_gj"))
DWS_PLATFORM_TABLE = quote_table(
    secret("DWS_PLATFORM_TABLE", "dws_platform_month_summary_2026_gj")
)
DWS_REGION_TABLE = quote_table(
    secret("DWS_REGION_TABLE", "dws_region_month_summary_2026_gj")
)
DWS_CATEGORY_TABLE = quote_table(
    secret("DWS_CATEGORY_TABLE", "dws_category_month_summary_2026_gj")
)
DM_ENTERPRISE_TABLE = quote_table(
    secret("DM_ENTERPRISE_TABLE", "dm_enterprise_sales_rank_2026_gj")
)


@st.cache_resource
def database_engine():
    url = URL.create(
        "mysql+pymysql",
        username=DB_CONFIG["user"],
        password=DB_CONFIG["password"],
        host=DB_CONFIG["host"],
        port=DB_CONFIG["port"],
        database=DB_CONFIG["database"],
        query={"charset": "utf8mb4"},
    )
    return create_engine(
        url,
        pool_pre_ping=True,
        pool_recycle=1800,
        connect_args={"connect_timeout": 8},
    )


@st.cache_data(ttl=300, show_spinner=False)
def query_data(sql: str, params: dict[str, Any] | None = None) -> pd.DataFrame:
    with database_engine().connect() as connection:
        return pd.read_sql_query(text(sql), connection, params=params or {})


def add_in_filter(
    column: str,
    values: list[str],
    prefix: str,
    params: dict[str, Any],
) -> str:
    if not values:
        return "AND 1 = 0"
    placeholders = []
    for index, value in enumerate(values):
        key = f"{prefix}_{index}"
        placeholders.append(f":{key}")
        params[key] = value
    return f"AND {column} IN ({', '.join(placeholders)})"


def format_money(value: Any) -> str:
    if value is None or pd.isna(value):
        return "暂无数据"
    value = float(value)
    if abs(value) >= 100_000_000:
        return f"¥{value / 100_000_000:,.2f}亿"
    if abs(value) >= 10_000:
        return f"¥{value / 10_000:,.2f}万"
    return f"¥{value:,.2f}"


def format_count(value: Any) -> str:
    if value is None or pd.isna(value):
        return "暂无数据"
    return f"{float(value):,.0f}"


def month_label(value: Any) -> str:
    month = str(int(value))
    return f"{month[:4]}-{month[4:]}"


def previous_month(month_id: int) -> int:
    year, month = divmod(month_id, 100)
    return (year - 1) * 100 + 12 if month == 1 else year * 100 + month - 1


def style_chart(figure: go.Figure, height: int = 360) -> go.Figure:
    figure.update_layout(
        height=height,
        margin=dict(l=12, r=12, t=52, b=12),
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        legend_title_text="",
        font=dict(family="Microsoft YaHei, Arial", color="#344054"),
        title_font=dict(size=17, color="#172026"),
    )
    return figure


st.title("跨境电商业务监测")
st.caption("2026年1月至6月 · DWD → DWS → DM · 金额单位：人民币")

if not DB_CONFIG["user"]:
    st.error("尚未配置数据库账号，请填写 .streamlit/secrets.toml 后刷新页面。")
    st.stop()

try:
    dimensions = query_data(
        f"""
        SELECT DISTINCT month_id, platform_name
        FROM {DM_TABLE}
        WHERE month_id BETWEEN 202601 AND 202606
          AND platform_name IS NOT NULL
        ORDER BY month_id, platform_name
        """
    )
except Exception as exc:
    st.error(f"数据库连接或指标表读取失败：{exc}")
    st.info(f"请确认 {DB_CONFIG['database']}.{DM_TABLE} 已按 README 完成刷新。")
    st.stop()

if dimensions.empty:
    st.warning("指标表暂无 202601-202606 数据。")
    st.stop()

months = sorted(dimensions["month_id"].astype(int).unique().tolist())
platforms = sorted(
    dimensions["platform_name"].astype(str).unique().tolist(),
    key=lambda name: ["SMT", "Amazon", "Alibaba", "Ozon"].index(name)
    if name in ["SMT", "Amazon", "Alibaba", "Ozon"]
    else 99,
)

with st.sidebar:
    st.subheader("筛选条件")
    selected_months = st.select_slider(
        "月份范围",
        options=months,
        value=(months[0], months[-1]),
        format_func=month_label,
    )
    selected_platforms = st.multiselect(
        "平台",
        options=platforms,
        default=platforms,
        format_func=lambda value: PLATFORM_LABELS.get(value, value),
    )

if not selected_platforms:
    st.warning("至少选择一个平台。")
    st.stop()

start_month, end_month = selected_months
base_params: dict[str, Any] = {
    "start_month": int(start_month),
    "end_month": int(end_month),
}
platform_filter = add_in_filter(
    "platform_name", selected_platforms, "platform", base_params
)

province_options = query_data(
    f"""
    SELECT DISTINCT province
    FROM {DWS_REGION_TABLE}
    WHERE month_id BETWEEN :start_month AND :end_month
      AND region_level = '省级'
      {platform_filter}
      AND province NOT IN ('全国合计', '未知省份')
    ORDER BY province
    """,
    base_params,
)["province"].tolist()

with st.sidebar:
    selected_province = st.selectbox("省份", ["全部省份", *province_options])

city_params = dict(base_params)
province_filter = ""
if selected_province != "全部省份":
    province_filter = "AND province = :selected_province"
    city_params["selected_province"] = selected_province

city_options = query_data(
    f"""
    SELECT DISTINCT city
    FROM {DWS_REGION_TABLE}
    WHERE month_id BETWEEN :start_month AND :end_month
      AND region_level = '市级'
      {platform_filter}
      {province_filter}
      AND city NOT IN ('全部城市', '全省小计', '未知城市')
    ORDER BY city
    """,
    city_params,
)["city"].tolist()

with st.sidebar:
    selected_city = st.selectbox("城市", ["全部城市", *city_options])
    st.caption("查询结果缓存 5 分钟")

region_params = dict(city_params)
city_filter = ""
if selected_city != "全部城市":
    city_filter = "AND city = :selected_city"
    region_params["selected_city"] = selected_city

summary_params = dict(base_params)
summary_params["end_month_only"] = int(end_month)
summary = query_data(
    f"""
    SELECT
        SUM(retail_sales_rmb) AS retail_sales_rmb,
        SUM(retail_sales_num) AS retail_sales_num,
        SUM(express_revenue_rmb) AS express_revenue_rmb,
        SUM(express_volume) AS express_volume,
        SUM(shop_count) AS shop_count,
        SUM(valid_money_rows) AS valid_money_rows
    FROM {DM_TABLE}
    WHERE month_id = :end_month_only
      {platform_filter}
    """,
    summary_params,
).iloc[0]

trend = query_data(
    f"""
    SELECT month_id,
           SUM(retail_sales_rmb) AS retail_sales_rmb,
           SUM(retail_sales_num) AS retail_sales_num,
           SUM(express_revenue_rmb) AS express_revenue_rmb,
           SUM(express_volume) AS express_volume
    FROM {DM_TABLE}
    WHERE month_id BETWEEN :start_month AND :end_month
      {platform_filter}
    GROUP BY month_id
    ORDER BY month_id
    """,
    base_params,
)
trend["month"] = trend["month_id"].map(month_label)

latest_sales = summary["retail_sales_rmb"]
mom_delta = None
prior_id = previous_month(int(end_month))
current_row = trend[trend["month_id"] == int(end_month)]
prior_row = trend[trend["month_id"] == prior_id]
if not current_row.empty and not prior_row.empty:
    current_value = current_row.iloc[0]["retail_sales_rmb"]
    prior_value = prior_row.iloc[0]["retail_sales_rmb"]
    if pd.notna(current_value) and pd.notna(prior_value) and float(prior_value) != 0:
        mom_delta = (float(current_value) - float(prior_value)) / float(prior_value) * 100

k1, k2, k3, k4, k5 = st.columns(5)
k1.metric(
    "月零售额",
    format_money(latest_sales),
    delta="无上月基期" if mom_delta is None else f"{mom_delta:.2f}% 环比",
    delta_color="off" if mom_delta is None else "inverse",
)
k2.metric("月销量", format_count(summary["retail_sales_num"]))
k3.metric("快递收入估算", format_money(summary["express_revenue_rmb"]))
k4.metric("快递量估算", format_count(summary["express_volume"]))
k5.metric("活跃平台店铺", format_count(summary["shop_count"]))

if summary["shop_count"] and summary["valid_money_rows"] < summary["shop_count"]:
    coverage = float(summary["valid_money_rows"]) / float(summary["shop_count"]) * 100
    st.warning(f"所选月份销售额有效店铺覆盖率为 {coverage:.1f}%，缺失金额没有按 0 计算。")

left, right = st.columns(2)
with left:
    sales_figure = px.line(
        trend,
        x="month",
        y="retail_sales_rmb",
        markers=True,
        title="月度零售额趋势",
        labels={"month": "月份", "retail_sales_rmb": "零售额（元）"},
    )
    sales_figure.update_traces(line_color="#b42318")
    st.plotly_chart(style_chart(sales_figure), width="stretch")

with right:
    logistics_figure = make_subplots(specs=[[{"secondary_y": True}]])
    logistics_figure.add_trace(
        go.Scatter(
            x=trend["month"],
            y=trend["express_revenue_rmb"],
            name="快递收入（元）",
            mode="lines+markers",
            line=dict(color="#175cd3"),
        ),
        secondary_y=False,
    )
    logistics_figure.add_trace(
        go.Scatter(
            x=trend["month"],
            y=trend["express_volume"],
            name="快递量",
            mode="lines+markers",
            line=dict(color="#027a48"),
        ),
        secondary_y=True,
    )
    logistics_figure.update_layout(title="物流指标趋势")
    logistics_figure.update_yaxes(title_text="快递收入（元）", secondary_y=False)
    logistics_figure.update_yaxes(title_text="快递量", secondary_y=True)
    st.plotly_chart(style_chart(logistics_figure), width="stretch")

platform_mix = query_data(
    f"""
    SELECT platform_name, SUM(retail_sales_rmb) AS total_sales_rmb
    FROM {DM_TABLE}
    WHERE month_id BETWEEN :start_month AND :end_month
      {platform_filter}
    GROUP BY platform_name
    HAVING SUM(retail_sales_rmb) IS NOT NULL
    ORDER BY total_sales_rmb DESC
    """,
    base_params,
)
platform_mix["platform"] = platform_mix["platform_name"].map(
    lambda value: PLATFORM_LABELS.get(value, value)
)

category = query_data(
    f"""
    SELECT category_name, SUM(total_sales_rmb) AS total_sales_rmb
    FROM {DWS_CATEGORY_TABLE}
    WHERE month_id BETWEEN :start_month AND :end_month
      {platform_filter}
    GROUP BY category_name
    HAVING SUM(total_sales_rmb) IS NOT NULL
    ORDER BY total_sales_rmb DESC, category_name
    LIMIT 10
    """,
    base_params,
)

left, right = st.columns(2)
with left:
    if platform_mix.empty:
        st.info("所选范围没有有效平台销售额。")
    else:
        mix_figure = px.pie(
            platform_mix,
            names="platform",
            values="total_sales_rmb",
            hole=0.48,
            title="平台销售额分布",
            color_discrete_sequence=["#b42318", "#175cd3", "#027a48", "#f79009"],
        )
        st.plotly_chart(style_chart(mix_figure), width="stretch")

with right:
    if category.empty:
        st.info("所选范围没有有效类目销售额。")
    else:
        category_figure = px.bar(
            category.sort_values("total_sales_rmb"),
            x="total_sales_rmb",
            y="category_name",
            orientation="h",
            title="类目销售额 TOP10",
            labels={"total_sales_rmb": "销售额（元）", "category_name": "类目"},
            color_discrete_sequence=["#175cd3"],
        )
        st.plotly_chart(style_chart(category_figure), width="stretch")

county = query_data(
    f"""
    SELECT province, city, county,
           SUM(total_sales_rmb) AS total_sales_rmb,
           SUM(shop_count) AS shop_count
    FROM {DWS_REGION_TABLE}
    WHERE month_id BETWEEN :start_month AND :end_month
      AND region_level = '区县级'
      {platform_filter}
      {province_filter}
      {city_filter}
    GROUP BY province, city, county
    HAVING SUM(total_sales_rmb) IS NOT NULL
    ORDER BY total_sales_rmb DESC
    LIMIT 15
    """,
    region_params,
)
if not county.empty:
    county["region"] = county[["province", "city", "county"]].agg(" / ".join, axis=1)

enterprise_params = dict(base_params)
enterprise_params["end_month_only"] = int(end_month)
enterprise = query_data(
    f"""
    WITH combined AS (
        SELECT company_name,
               SUM(total_sales_rmb) AS total_sales_rmb,
               SUM(total_sales_num) AS total_sales_num,
               SUM(shop_count) AS shop_count
        FROM {DM_ENTERPRISE_TABLE}
        WHERE month_id = :end_month_only
          {platform_filter}
        GROUP BY company_name
    ), ranked AS (
        SELECT combined.*,
               RANK() OVER (ORDER BY total_sales_rmb IS NULL,
                                     total_sales_rmb DESC) AS enterprise_rank
        FROM combined
    )
    SELECT enterprise_rank, company_name, total_sales_rmb,
           total_sales_num, shop_count
    FROM ranked
    WHERE enterprise_rank <= 20
    ORDER BY enterprise_rank, company_name
    """,
    enterprise_params,
)

left, right = st.columns([1, 1.15])
with left:
    if county.empty:
        st.info("所选区域没有有效区县销售额。")
    else:
        county_figure = px.bar(
            county.sort_values("total_sales_rmb"),
            x="total_sales_rmb",
            y="region",
            orientation="h",
            title="区县销售额 TOP15",
            labels={"total_sales_rmb": "销售额（元）", "region": "区县"},
            color_discrete_sequence=["#027a48"],
        )
        st.plotly_chart(style_chart(county_figure, 460), width="stretch")

with right:
    st.subheader("企业销售排行")
    if enterprise.empty:
        st.info("所选范围没有有效企业销售额。")
    else:
        display_enterprise = enterprise.rename(
            columns={
                "enterprise_rank": "排名",
                "company_name": "企业",
                "total_sales_rmb": "销售额（元）",
                "total_sales_num": "销量",
                "shop_count": "平台店铺数",
            }
        )
        st.dataframe(
            display_enterprise,
            width="stretch",
            hide_index=True,
            column_config={
                "销售额（元）": st.column_config.NumberColumn(format="¥ %.2f"),
                "销量": st.column_config.NumberColumn(format="%.0f"),
            },
            height=420,
        )

st.subheader("平台月度变化")
change_params = dict(base_params)
change_params["end_month_only"] = int(end_month)
changes = query_data(
    f"""
    SELECT platform_name, retail_sales_rmb, mom_growth_pct,
           yoy_growth_pct, yoy_status
    FROM {DM_TABLE}
    WHERE month_id = :end_month_only
      {platform_filter}
    ORDER BY platform_id
    """,
    change_params,
)
if changes.empty:
    st.info("所选月份没有平台指标。")
else:
    cards = st.columns(len(changes))
    for card, (_, row) in zip(cards, changes.iterrows()):
        platform_label = PLATFORM_LABELS.get(row["platform_name"], row["platform_name"])
        if pd.isna(row["mom_growth_pct"]):
            delta = "无上月基期"
            delta_color = "off"
        else:
            delta = f"{float(row['mom_growth_pct']):.2f}% 环比"
            delta_color = "inverse"
        card.metric(
            platform_label,
            format_money(row["retail_sales_rmb"]),
            delta=delta,
            delta_color=delta_color,
        )
    st.caption("同比：本版本未装载 2025 年同期，所有平台均为“无同期基期”，不显示 0%。")

map_params = dict(region_params)
map_level = "市级" if selected_city != "全部城市" else "省级"
map_params["map_level"] = map_level
province_map = query_data(
    f"""
    SELECT province, SUM(total_sales_rmb) AS total_sales_rmb
    FROM {DWS_REGION_TABLE}
    WHERE month_id BETWEEN :start_month AND :end_month
      AND region_level = :map_level
      {platform_filter}
      {province_filter}
      {city_filter}
      AND province NOT IN ('全国合计', '未知省份')
    GROUP BY province
    HAVING SUM(total_sales_rmb) IS NOT NULL
    """,
    map_params,
)
if not province_map.empty:
    province_map["lat"] = province_map["province"].map(
        lambda value: PROVINCE_COORDS.get(value, (None, None))[0]
    )
    province_map["lon"] = province_map["province"].map(
        lambda value: PROVINCE_COORDS.get(value, (None, None))[1]
    )
    province_map = province_map.dropna(subset=["lat", "lon"])

st.subheader("省域销售分布")
if province_map.empty:
    st.info("所选范围没有可映射的省份销售额。")
else:
    map_figure = px.scatter_map(
        province_map,
        lat="lat",
        lon="lon",
        size="total_sales_rmb",
        color="total_sales_rmb",
        hover_name="province",
        hover_data={"lat": False, "lon": False, "total_sales_rmb": ":,.2f"},
        color_continuous_scale="YlOrRd",
        zoom=3,
        center={"lat": 35.5, "lon": 104.0},
        title="省级销售额分布",
    )
    map_figure.update_layout(map_style="carto-positron")
    st.plotly_chart(style_chart(map_figure, 520), width="stretch")

st.caption("口径：快递收入=零售额×15%；快递量=销量×53%；地图坐标为省会近似位置。")

