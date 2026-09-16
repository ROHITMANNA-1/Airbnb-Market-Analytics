"""
02_feature_engineering.py
--------------------------
Airbnb Market Analytics & Investment Platform — Phase 1

THE CORE DATA LOGIC OF THIS PROJECT:
Inside Airbnb does not publish revenue or occupancy directly. We derive them
from calendar.csv, where each row is one (listing_id, date) with an
`available` flag:
    available = False ('f')  ->  treated as a BOOKED night
    available = True  ('t')  ->  treated as an OPEN/unbooked night

    occupancy_rate = booked_nights / total_nights_in_calendar_window
    revenue_estimate = SUM(price) for all booked nights

This is an approximation used throughout the Inside Airbnb analytics
community — hosts occasionally block dates for personal reasons rather than
bookings, so treat these as *estimates*, not ground truth. That caveat is
documented in docs/DATA_DICTIONARY.md and should be repeated in the README.

Run from the project root, AFTER 01_data_cleaning.py:
    python scripts/02_feature_engineering.py
"""

import os
from datetime import datetime

import numpy as np
import pandas as pd

PROCESSED_DIR = os.path.join("data", "processed")
TODAY = pd.Timestamp(datetime.now().date())


def print_section(title: str) -> None:
    print("\n" + "=" * 70)
    print(title)
    print("=" * 70)


# ----------------------------------------------------------------------
# 1. DERIVE OCCUPANCY & REVENUE FROM calendar_clean.csv
# ----------------------------------------------------------------------
def build_listing_level_calendar_metrics(calendar: pd.DataFrame) -> pd.DataFrame:
    print_section("Deriving Revenue & Occupancy from calendar_clean.csv")

    grouped = calendar.groupby("listing_id")
    agg = grouped.agg(
        total_nights_tracked=("date", "count"),
        booked_nights=("available", lambda s: int((~s).sum())),
        calendar_start=("date", "min"),
        calendar_end=("date", "max"),
    ).reset_index()

    # Revenue: sum of price on booked (available == False) nights
    booked_mask = calendar.assign(is_booked=~calendar["available"])
    revenue = (
        booked_mask[booked_mask["is_booked"]]
        .groupby("listing_id")["price"]
        .sum()
        .rename("revenue_estimate")
        .reset_index()
    )

    # Average listed price on OPEN nights — this is the "asking price" we'll
    # compare against actual booked ADR to spot pricing opportunities later.
    avg_open_price = (
        calendar[calendar["available"]]
        .groupby("listing_id")["price"]
        .mean()
        .rename("avg_open_listing_price")
        .reset_index()
    )

    metrics = agg.merge(revenue, on="listing_id", how="left")
    metrics = metrics.merge(avg_open_price, on="listing_id", how="left")

    metrics["revenue_estimate"] = metrics["revenue_estimate"].fillna(0)
    metrics["occupancy_rate"] = (
        metrics["booked_nights"] / metrics["total_nights_tracked"]
    ).round(4)

    # ADR (Average Daily Rate) — revenue per BOOKED night. Core hospitality KPI.
    metrics["adr"] = np.where(
        metrics["booked_nights"] > 0,
        (metrics["revenue_estimate"] / metrics["booked_nights"]).round(2),
        0,
    )

    # RevPAR (Revenue Per Available night) — revenue spread across ALL
    # tracked nights, not just booked ones. The single most-cited metric in
    # short-term rental / hotel analytics for comparing performance across
    # listings regardless of size or price point.
    metrics["revpar"] = np.where(
        metrics["total_nights_tracked"] > 0,
        (metrics["revenue_estimate"] / metrics["total_nights_tracked"]).round(2),
        0,
    )

    print(f"Built calendar-derived metrics for {len(metrics):,} listings")
    return metrics.rename(columns={"listing_id": "id"})


# ----------------------------------------------------------------------
# 2. MONTHLY AGGREGATION (feeds seasonality analysis in SQL / Power BI)
# ----------------------------------------------------------------------
def build_monthly_calendar_agg(calendar: pd.DataFrame) -> pd.DataFrame:
    print_section("Building monthly seasonality aggregation")

    cal = calendar.copy()
    cal["year_month"] = cal["date"].dt.to_period("M").astype(str)
    cal["is_booked"] = ~cal["available"]

    monthly = (
        cal.groupby(["listing_id", "year_month"])
        .agg(
            nights_tracked=("date", "count"),
            nights_booked=("is_booked", "sum"),
            revenue=("price", lambda s: s[cal.loc[s.index, "is_booked"]].sum()),
        )
        .reset_index()
    )
    monthly["occupancy_rate"] = (
        monthly["nights_booked"] / monthly["nights_tracked"]
    ).round(4)

    print(f"Built {len(monthly):,} listing-month rows")
    return monthly.rename(columns={"listing_id": "id"})


# ----------------------------------------------------------------------
# 3. FEATURE ENGINEERING ON LISTINGS (host experience, price tiers, etc.)
# ----------------------------------------------------------------------
def engineer_listing_features(listings: pd.DataFrame) -> pd.DataFrame:
    print_section("Engineering listing-level features")

    df = listings.copy()

    # --- Host experience (years since they joined Airbnb) ---
    if "host_since" in df.columns:
        df["host_experience_years"] = (
            (TODAY - df["host_since"]).dt.days / 365.25
        ).round(1)
        experience_values = df["host_experience_years"].dropna()
        median_experience = (
            experience_values.median() if not experience_values.empty else 0
        )
        df["host_experience_years"] = df["host_experience_years"].fillna(
            0 if pd.isna(median_experience) else median_experience
        )
    else:
        df["host_experience_years"] = np.nan

    df["host_experience_tier"] = pd.cut(
        df["host_experience_years"],
        bins=[-0.01, 1, 3, 6, 100],
        labels=["New (<1yr)", "Growing (1-3yr)", "Established (3-6yr)", "Veteran (6yr+)"],
    )

    # --- Price category (quartile-based, per overall market) ---
    df["price_category"] = pd.qcut(
        df["price"], q=4, labels=["Budget", "Mid-Range", "Premium", "Luxury"], duplicates="drop"
    )

    # --- Listing tenure / activity recency ---
    if "first_review" in df.columns:
        df["listing_age_days"] = (TODAY - df["first_review"]).dt.days
    if "last_review" in df.columns:
        df["days_since_last_review"] = (TODAY - df["last_review"]).dt.days
        # No reviews in 12 months+ is a common "at risk of delisting" signal
        df["is_stale_listing"] = df["days_since_last_review"] > 365
        df["is_stale_listing"] = df["is_stale_listing"].fillna(True)  # never reviewed = stale

    # --- Composite review score (simple mean of sub-scores where present) ---
    review_subscores = [
        c for c in [
            "review_scores_cleanliness", "review_scores_checkin",
            "review_scores_communication", "review_scores_location",
            "review_scores_value",
        ] if c in df.columns
    ]
    if review_subscores:
        df["review_score_composite"] = df[review_subscores].mean(axis=1).round(2)

    # --- Amenity count (proxy for listing quality/investment level) ---
    if "amenities" in df.columns:
        df["amenity_count"] = df["amenities"].astype(str).apply(
            lambda x: len(x.strip("[]").split(",")) if x and x != "nan" else 0
        )

    print(f"Engineered features on {len(df):,} listings")
    return df


# ----------------------------------------------------------------------
# 4. SYNTHETIC FIELDS (clearly documented — needed for ROI/investment KPIs
#    that Inside Airbnb simply has no real-world data for)
# ----------------------------------------------------------------------
def add_synthetic_investment_fields(df: pd.DataFrame) -> pd.DataFrame:
    """
    Inside Airbnb has no property-value or acquisition-cost data, but the
    business problem explicitly asks "which areas offer the best ROI for
    investors" — impossible without an estimated asset value.

    We generate an ILLUSTRATIVE estimated_property_value using a transparent,
    documented rule (NOT a real appraisal):

        estimated_property_value =
            neighbourhood_median_price_per_bedroom
            * (bedrooms, min 1)
            * SYNTHETIC_MULTIPLIER

    The multiplier (250) approximates a rough price-to-daily-rate ratio seen
    in short-term-rental markets (annual gross yield ~10-15%). This is
    explicitly a portfolio-project simplification — every downstream ROI
    number derived from it should be labeled "estimated" in dashboards.
    See docs/DATA_DICTIONARY.md for the full disclosure.
    """
    print_section("Adding SYNTHETIC investment fields (clearly flagged)")

    SYNTHETIC_MULTIPLIER = 250
    df = df.copy()
    df["bedrooms_for_valuation"] = df["bedrooms"].fillna(1).clip(lower=1)

    neigh_col = (
        "neighbourhood_cleansed" if "neighbourhood_cleansed" in df.columns else None
    )
    if neigh_col:
        neigh_price_per_bedroom = (
            df.assign(price_per_bedroom=df["price"] / df["bedrooms_for_valuation"])
            .groupby(neigh_col)["price_per_bedroom"]
            .median()
            .rename("neighbourhood_median_price_per_bedroom")
        )
        df = df.merge(neigh_price_per_bedroom, on=neigh_col, how="left")
    else:
        df["neighbourhood_median_price_per_bedroom"] = (
            df["price"] / df["bedrooms_for_valuation"]
        ).median()

    df["estimated_property_value"] = (
        df["neighbourhood_median_price_per_bedroom"]
        * df["bedrooms_for_valuation"]
        * SYNTHETIC_MULTIPLIER
    ).round(0)

    df["is_synthetic_valuation"] = True  # explicit flag for downstream users

    print("Added: estimated_property_value (SYNTHETIC — see data dictionary)")
    return df


# ----------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------
if __name__ == "__main__":
    listings = pd.read_csv(
        os.path.join(PROCESSED_DIR, "listings_clean.csv"),
        parse_dates=["host_since", "first_review", "last_review"],
    )
    calendar = pd.read_csv(
        os.path.join(PROCESSED_DIR, "calendar_clean.csv"), parse_dates=["date"]
    )
    calendar["available"] = calendar["available"].astype(bool)

    # Step 1: revenue & occupancy from calendar
    calendar_metrics = build_listing_level_calendar_metrics(calendar)

    # Step 2: monthly seasonality table (separate export)
    monthly_agg = build_monthly_calendar_agg(calendar)

    # Step 3: listing-level feature engineering
    listings_featured = engineer_listing_features(listings)

    # Step 4: synthetic investment fields
    listings_featured = add_synthetic_investment_fields(listings_featured)

    # Step 5: assemble master table
    print_section("Assembling master analytics table")
    master = listings_featured.merge(calendar_metrics, on="id", how="left")

    # ROI proxy: annual revenue estimate vs. estimated property value
    master["estimated_annual_roi_pct"] = np.where(
        master["estimated_property_value"] > 0,
        (master["revenue_estimate"] / master["estimated_property_value"] * 100).round(2),
        np.nan,
    )

    # Pricing gap: listed (asking) price vs. actual booked ADR.
    # Positive = listing may be OVERPRICED relative to what it actually earns.
    # Negative = listing may be UNDERPRICED (booking out at a rate below its own asking price).
    master["pricing_gap"] = (master["price"] - master["adr"]).round(2)
    master["pricing_signal"] = np.select(
        [master["pricing_gap"] > 20, master["pricing_gap"] < -20],
        ["Possibly Overpriced", "Possibly Underpriced"],
        default="Well-Priced",
    )

    print(f"Master table shape: {master.shape}")

    # Step 6: export
    master.to_csv(os.path.join(PROCESSED_DIR, "master_analytics_table.csv"), index=False)
    monthly_agg.to_csv(os.path.join(PROCESSED_DIR, "calendar_monthly_agg.csv"), index=False)

    print_section("DONE")
    print("Wrote: master_analytics_table.csv, calendar_monthly_agg.csv")
    print("Next: python scripts/03_export_for_mysql.py")
