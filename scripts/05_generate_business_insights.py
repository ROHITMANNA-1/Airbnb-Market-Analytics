"""
05_generate_business_insights.py
---------------------------------
Builds a concise, data-backed business insight pack from the engineered
tables. The outputs are designed to be used beside the Power BI report:
    data/processed/business_insights.csv
    docs/BUSINESS_INSIGHTS_ACTUAL.md

Run after scripts/02_feature_engineering.py:
    python scripts/05_generate_business_insights.py
"""

import os

import pandas as pd


PROCESSED_DIR = os.path.join("data", "processed")
INSIGHTS_PATH = os.path.join(PROCESSED_DIR, "business_insights.csv")
REPORT_PATH = os.path.join("docs", "BUSINESS_INSIGHTS_ACTUAL.md")


def money(value: float) -> str:
    return f"${value:,.0f}"


def pct(value: float) -> str:
    return f"{value:.1%}"


def build_insights(master: pd.DataFrame, monthly: pd.DataFrame) -> pd.DataFrame:
    total_revenue = master["revenue_estimate"].sum()
    weighted_occupancy = master["booked_nights"].sum() / master["total_nights_tracked"].sum()
    revpar = total_revenue / master["total_nights_tracked"].sum()

    neighborhood = (
        master.groupby("neighbourhood_cleansed", dropna=False)
        .agg(
            Listings=("id", "count"),
            Revenue=("revenue_estimate", "sum"),
            BookedNights=("booked_nights", "sum"),
            TrackedNights=("total_nights_tracked", "sum"),
            AvgROI=("estimated_annual_roi_pct", "mean"),
            AvgReview=("review_score_composite", "mean"),
        )
        .assign(Occupancy=lambda x: x["BookedNights"] / x["TrackedNights"])
    )
    neighborhood["RevenueShare"] = neighborhood["Revenue"] / total_revenue

    superhost = master.groupby("host_is_superhost").agg(
        Revenue=("revenue_estimate", "sum"),
        BookedNights=("booked_nights", "sum"),
        TrackedNights=("total_nights_tracked", "sum"),
    )
    superhost["RevPAR"] = superhost["Revenue"] / superhost["TrackedNights"]
    superhost_gap = (
        superhost.loc[True, "RevPAR"] / superhost.loc[False, "RevPAR"] - 1
        if True in superhost.index and False in superhost.index
        else float("nan")
    )

    stale_count = int(master["is_stale_listing"].fillna(True).sum())
    pricing_opportunities = int((master["pricing_signal"] != "Well-Priced").sum())
    peak_month = monthly.groupby("year_month")["revenue"].sum().idxmax()
    low_month = monthly.groupby("year_month")["revenue"].sum().idxmin()
    top_three_share = neighborhood.nlargest(3, "Revenue")["RevenueShare"].sum()
    top_revpar_area = neighborhood.nlargest(1, "Revenue").index[0]
    top_roi_area = neighborhood.nlargest(1, "AvgROI").index[0]

    rows = [
        {
            "InsightID": "EXEC-01",
            "Theme": "Executive",
            "Finding": f"The market contains {len(master):,} priced listings and generates {money(total_revenue)} in estimated revenue at {pct(weighted_occupancy)} weighted occupancy.",
            "Recommendation": "Use the top-revenue neighborhoods as the acquisition baseline, but evaluate RevPAR and inventory depth before adding supply.",
            "Caveat": "Revenue and occupancy are estimates from availability flags, not verified reservations.",
        },
        {
            "InsightID": "EXEC-02",
            "Theme": "Revenue concentration",
            "Finding": f"The top three neighborhoods contribute {pct(top_three_share)} of estimated revenue; {top_revpar_area} is the largest revenue market.",
            "Recommendation": "Protect the core market while testing expansion in smaller areas with strong RevPAR and occupancy.",
            "Caveat": "Neighborhood performance is sensitive to the current listing mix.",
        },
        {
            "InsightID": "SEAS-01",
            "Theme": "Seasonality",
            "Finding": f"Estimated revenue peaks in {peak_month} and bottoms in {low_month}; monthly occupancy should drive seasonal pricing rules.",
            "Recommendation": "Create a seasonal pricing calendar and review it monthly against occupancy and RevPAR.",
            "Caveat": "This dataset is a single forward-looking calendar window, not a multi-year trend.",
        },
        {
            "InsightID": "HOST-01",
            "Theme": "Host performance",
            "Finding": f"Superhost RevPAR is {pct(superhost_gap)} above non-superhost RevPAR in the tracked window.",
            "Recommendation": "Prioritize coaching and Superhost-readiness campaigns for hosts close to the quality threshold.",
            "Caveat": "The comparison is observational and does not prove that status alone causes the revenue gap.",
        },
        {
            "InsightID": "QUALITY-01",
            "Theme": "Guest experience",
            "Finding": f"{stale_count:,} listings are stale under the 365-day review rule, creating a recoverable reactivation audience.",
            "Recommendation": "Launch a win-back workflow with listing refresh prompts and a short-term booking incentive.",
            "Caveat": "No recent review can mean inactivity, not necessarily poor guest experience.",
        },
        {
            "InsightID": "PRICING-01",
            "Theme": "Pricing",
            "Finding": f"{pricing_opportunities:,} listings are flagged by the pricing-gap rule; this export has no calendar price column, so most listings cannot show a meaningful realized-ADR gap.",
            "Recommendation": "Treat pricing signals as provisional and refresh with nightly calendar prices before automating host recommendations.",
            "Caveat": "Calendar prices were backfilled from listings.csv base price for this source export.",
        },
        {
            "InsightID": "INVEST-01",
            "Theme": "Investment",
            "Finding": f"{top_roi_area} ranks highest on estimated ROI under the current valuation proxy.",
            "Recommendation": "Use this page to prioritize diligence, not as an investment recommendation; replace the proxy with independent property-value data.",
            "Caveat": "Property values and ROI are synthetic estimates derived from Airbnb pricing data.",
        },
    ]
    return pd.DataFrame(rows)


def write_report(insights: pd.DataFrame, master: pd.DataFrame) -> None:
    report = [
        "# Business Insights from Current Data",
        "",
        "This report is generated from the current processed Airbnb snapshot. Refresh it with `python scripts/05_generate_business_insights.py` after rerunning the pipeline.",
        "",
    ]
    for _, row in insights.iterrows():
        report.extend([
            f"## {row['InsightID']} - {row['Theme']}",
            f"**Finding:** {row['Finding']}",
            "",
            f"**Recommendation:** {row['Recommendation']}",
            "",
            f"**Caveat:** {row['Caveat']}",
            "",
        ])
    report.extend([
        "## Dashboard KPI snapshot",
        "",
        f"- Listings analyzed: {len(master):,}",
        f"- Estimated revenue: {money(master['revenue_estimate'].sum())}",
        f"- Weighted occupancy: {pct(master['booked_nights'].sum() / master['total_nights_tracked'].sum())}",
        f"- RevPAR: {money(master['revenue_estimate'].sum() / master['total_nights_tracked'].sum())}",
        "",
    ])
    with open(REPORT_PATH, "w", encoding="utf-8") as report_file:
        report_file.write("\n".join(report))


if __name__ == "__main__":
    master = pd.read_csv(os.path.join(PROCESSED_DIR, "master_analytics_table.csv"))
    monthly = pd.read_csv(os.path.join(PROCESSED_DIR, "calendar_monthly_agg.csv"))
    insights = build_insights(master, monthly)
    insights.to_csv(INSIGHTS_PATH, index=False)
    write_report(insights, master)
    print(f"Wrote {INSIGHTS_PATH}")
    print(f"Wrote {REPORT_PATH}")