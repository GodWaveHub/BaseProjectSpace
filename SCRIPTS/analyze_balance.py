# -*- coding: utf-8 -*-
"""残高データから月次・年次の収入(増加)・支出(減少)を集計・図示し、将来を予測するスクリプト。

入力: money/data.txt (タブ区切り: 日付, ざんだか)
出力: money/output/ 配下にPNGグラフとサマリCSV
"""
import os
import sys

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter

# 日本語フォント設定(Windows想定)
for font in ["Yu Gothic", "Meiryo", "MS Gothic"]:
    try:
        matplotlib.rcParams["font.family"] = font
        break
    except Exception:
        continue
matplotlib.rcParams["axes.unicode_minus"] = False

BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATA_PATH = os.path.join(BASE, "money", "data.txt")
if not os.path.exists(DATA_PATH):
    # worktree に data.txt が無い場合は本体プロジェクトを参照
    alt = r"c:\kanba\ai\projects\BaseProjectSpace\money\data.txt"
    if os.path.exists(alt):
        DATA_PATH = alt
OUT_DIR = os.path.join(BASE, "money", "output")
os.makedirs(OUT_DIR, exist_ok=True)

# ---------- データ読み込み ----------
df = pd.read_csv(DATA_PATH, sep="\t", header=0, names=["date", "balance"])
df["date"] = pd.to_datetime(df["date"], format="%Y/%m/%d %H:%M")
df = df.dropna().sort_values("date").reset_index(drop=True)

yen_fmt = FuncFormatter(lambda v, _: f"{v/10000:,.0f}万")

# ---------- 月次集計 (各月の最終残高 -> 前月差分) ----------
monthly = df.set_index("date")["balance"].resample("ME").last().dropna()
monthly_diff = monthly.diff().dropna()
m_income = monthly_diff.clip(lower=0)   # 増加分 = 純収入
m_expense = (-monthly_diff).clip(lower=0)  # 減少分 = 純支出

# ---------- 年次集計 ----------
yearly = df.set_index("date")["balance"].resample("YE").last().dropna()
yearly_diff = yearly.diff().dropna()
y_income = yearly_diff.clip(lower=0)
y_expense = (-yearly_diff).clip(lower=0)

# ---------- 図1: 残高推移 ----------
fig, ax = plt.subplots(figsize=(14, 6))
ax.plot(df["date"], df["balance"], color="#1f77b4", lw=1.5)
ax.fill_between(df["date"], df["balance"], alpha=0.15, color="#1f77b4")
ax.set_title("残高推移 (2003-2026)", fontsize=14)
ax.set_ylabel("残高 (円)")
ax.yaxis.set_major_formatter(yen_fmt)
ax.grid(alpha=0.3)
fig.tight_layout()
fig.savefig(os.path.join(OUT_DIR, "01_balance_trend.png"), dpi=120)
plt.close(fig)

# ---------- 図2: 月次 増加(収入)/減少(支出) ----------
fig, ax = plt.subplots(figsize=(14, 6))
ax.bar(m_income.index, m_income.values, width=20, color="#2ca02c", label="増加(純収入)")
ax.bar(m_expense.index, -m_expense.values, width=20, color="#d62728", label="減少(純支出)")
ax.axhline(0, color="black", lw=0.8)
ax.set_title("月次の残高増減 (増加=純収入 / 減少=純支出)", fontsize=14)
ax.set_ylabel("増減額 (円)")
ax.yaxis.set_major_formatter(yen_fmt)
ax.legend()
ax.grid(alpha=0.3)
fig.tight_layout()
fig.savefig(os.path.join(OUT_DIR, "02_monthly_income_expense.png"), dpi=120)
plt.close(fig)

# ---------- 図3: 年次 増加/減少 と 純増 ----------
years = yearly_diff.index.year
fig, ax = plt.subplots(figsize=(14, 6))
ax.bar(years - 0.2, y_income.values, width=0.4, color="#2ca02c", label="増加(純収入)")
ax.bar(years + 0.2, -y_expense.values, width=0.4, color="#d62728", label="減少(純支出)")
ax.plot(years, yearly_diff.values, color="#1f77b4", marker="o", lw=1.5, label="年間純増額")
ax.axhline(0, color="black", lw=0.8)
ax.set_title("年次の残高増減", fontsize=14)
ax.set_ylabel("金額 (円)")
ax.yaxis.set_major_formatter(yen_fmt)
ax.set_xticks(years[::2])
ax.legend()
ax.grid(alpha=0.3)
fig.tight_layout()
fig.savefig(os.path.join(OUT_DIR, "03_yearly_income_expense.png"), dpi=120)
plt.close(fig)

# ---------- 予測 ----------
# データが完全な期間(2008年以降)で回帰。近年の傾向を重視するため直近10年でも回帰。
ts = df.set_index("date")["balance"]
t0 = ts.index[0]
x_all = np.array([(d - t0).days for d in ts.index], dtype=float)
y_all = ts.values.astype(float)

def fit_linear(mask):
    coef = np.polyfit(x_all[mask], y_all[mask], 1)
    return coef  # (slope per day, intercept)

mask_recent10 = ts.index >= (ts.index[-1] - pd.DateOffset(years=10))
mask_recent5 = ts.index >= (ts.index[-1] - pd.DateOffset(years=5))
coef10 = fit_linear(np.asarray(mask_recent10))
coef5 = fit_linear(np.asarray(mask_recent5))

# 二次式(全期間): 緩やかな加速を捉える
coef_q = np.polyfit(x_all, y_all, 2)

future_end = pd.Timestamp("2036-12-31")
future_dates = pd.date_range(ts.index[-1], future_end, freq="ME")
xf = np.array([(d - t0).days for d in future_dates], dtype=float)

pred10 = np.polyval(coef10, xf)
pred5 = np.polyval(coef5, xf)
pred_q = np.polyval(coef_q, xf)

fig, ax = plt.subplots(figsize=(14, 6))
ax.plot(ts.index, y_all, color="#1f77b4", lw=1.5, label="実績")
ax.plot(future_dates, pred5, "--", color="#2ca02c", label=f"直近5年線形 (+{coef5[0]*365.25/10000:,.0f}万円/年)")
ax.plot(future_dates, pred10, "--", color="#ff7f0e", label=f"直近10年線形 (+{coef10[0]*365.25/10000:,.0f}万円/年)")
ax.plot(future_dates, pred_q, "--", color="#9467bd", label="全期間二次近似(加速傾向)")
ax.set_title("残高の将来予測 (~2036年)", fontsize=14)
ax.set_ylabel("残高 (円)")
ax.yaxis.set_major_formatter(yen_fmt)
ax.legend()
ax.grid(alpha=0.3)
fig.tight_layout()
fig.savefig(os.path.join(OUT_DIR, "04_forecast.png"), dpi=120)
plt.close(fig)

# ---------- サマリ出力 ----------
summary = pd.DataFrame({
    "年末残高": yearly.values,
}, index=yearly.index.year)
summary["年間純増"] = summary["年末残高"].diff()
summary.to_csv(os.path.join(OUT_DIR, "yearly_summary.csv"), encoding="utf-8-sig")

md = pd.DataFrame({"月末残高": monthly, "前月比増減": monthly.diff()})
md.to_csv(os.path.join(OUT_DIR, "monthly_summary.csv"), encoding="utf-8-sig")

# コンソールサマリ
print("=== 年次サマリ (直近10年) ===")
print(summary.tail(10).to_string())
print()
recent5_annual = coef5[0] * 365.25
recent10_annual = coef10[0] * 365.25
print(f"直近5年の増加ペース : 約 {recent5_annual/10000:,.0f} 万円/年 (約 {recent5_annual/12/10000:,.1f} 万円/月)")
print(f"直近10年の増加ペース: 約 {recent10_annual/10000:,.0f} 万円/年 (約 {recent10_annual/12/10000:,.1f} 万円/月)")
print()
for target_year in [2027, 2030, 2033, 2036]:
    d = pd.Timestamp(f"{target_year}-12-31")
    xd = (d - t0).days
    p5 = np.polyval(coef5, xd)
    p10 = np.polyval(coef10, xd)
    pq = np.polyval(coef_q, xd)
    print(f"{target_year}年末予測: 5年線形 {p5/10000:,.0f}万円 / 10年線形 {p10/10000:,.0f}万円 / 二次近似 {pq/10000:,.0f}万円")

print()
print(f"出力先: {OUT_DIR}")
