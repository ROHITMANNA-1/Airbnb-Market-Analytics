"""
01_data_cleaning.py
--------------------
Airbnb Market Analytics & Investment Platform — Phase 1

Reads raw Inside Airbnb files (listings.csv, calendar.csv, reviews.csv),
cleans types, handles missing values, and treats outliers. Writes clean
versions to data/processed/ for downstream feature engineering.

Run from the project root:
    python scripts/01_data_cleaning.py
"""

import os
import re
import numpy as np
import pandas as pd

# ----------------------------------------------------------------------
# CONFIG
# ----------------------------------------------------------------------
RAW_DIR = os.path.join("data", "raw")
PROCESSED_DIR = os.path.join("data", "processed")

LISTINGS_PATH = os.path.join(RAW_DIR, "listings.csv")
CALENDAR_PATH = os.path.join(RAW_DIR, "calendar.csv")
REVIEWS_PATH = os.path.join(RAW_DIR, "reviews.csv")

os.makedirs(PROCESSED_DIR, exist_ok=True)


# ----------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------
def clean_price_column(series: pd.Series) -> pd.Series:
    """
    Inside Airbnb prices arrive as strings like '$1,250.00'.
    Strip $ and commas, coerce to float. Invalid parses become NaN.

    NOTE: we check is_numeric_dtype rather than `dtype == object` because
    pandas may read text columns in as 'object' OR the newer 'str' /
    StringDtype depending on version/backend — checking for "not already
    numeric" is the robust way to catch every text-like case.
    """
    if pd.api.types.is_numeric_dtype(series):
        return series
    cleaned = (
        series.astype(str)
        .str.replace(r"[\$,]", "", regex=True)
        .str.strip()
        .replace({"nan": np.nan, "None": np.nan, "<NA>": np.nan, "": np.nan})
    )
    return pd.to_numeric(cleaned, errors="coerce")


def clean_percentage_column(series: pd.Series) -> pd.Series:
    """Converts strings like '95%' into a float 0-100. Leaves NaN as NaN."""
    if pd.api.types.is_numeric_dtype(series):
        return series
    cleaned = (
        series.astype(str)
        .str.replace("%", "", regex=False)
        .str.strip()
        .replace({"nan": np.nan, "None": np.nan, "<NA>": np.nan, "": np.nan})
    )
    return pd.to_numeric(cleaned, errors="coerce")


def cap_outliers_iqr(series: pd.Series, k: float = 1.5) -> pd.Series:
    """
    Caps outliers using the IQR rule instead of dropping rows — for a BI
    platform we want to keep every listing (investors care about extremes
    too), just prevent a $50,000/night typo from wrecking every KPI.
    """
    q1, q3 = series.quantile(0.25), series.quantile(0.75)
    iqr = q3 - q1
    lower, upper = q1 - k * iqr, q3 + k * iqr
    return series.clip(lower=max(lower, 0), upper=upper)


def print_section(title: str) -> None:
    print("\n" + "=" * 70)
    print(title)
    print("=" * 70)


# ----------------------------------------------------------------------
# 1. CLEAN LISTINGS
# ----------------------------------------------------------------------
def clean_listings() -> pd.DataFrame:
    print_section("Cleaning listings.csv")

    df = pd.read_csv(LISTINGS_PATH, low_memory=False)
    print(f"Raw shape: {df.shape}")

    # --- Keep only columns relevant to the analytics platform ---
    # Inside Airbnb exports 75+ columns; most cities export a superset of
    # these. We select defensively in case a given city's export is missing
    # a few optional columns.
    keep_cols = [
        "id", "host_id", "host_since", "host_is_superhost",
        "host_response_rate", "host_response_time", "host_total_listings_count",
        "host_identity_verified", "neighbourhood_cleansed",
        "neighbourhood_group_cleansed", "latitude", "longitude",
        "property_type", "room_type", "accommodates", "bathrooms",
        "bathrooms_text", "bedrooms", "beds", "amenities", "price",
        "minimum_nights", "maximum_nights", "availability_365",
        "number_of_reviews", "number_of_reviews_ltm", "first_review",
        "last_review", "review_scores_rating", "review_scores_cleanliness",
        "review_scores_checkin", "review_scores_communication",
        "review_scores_location", "review_scores_value",
        "instant_bookable", "calculated_host_listings_count",
        "reviews_per_month",
    ]
    available_cols = [c for c in keep_cols if c in df.columns]
    missing_cols = set(keep_cols) - set(available_cols)
    if missing_cols:
        print(f"Note: columns not found in this export (skipped): {sorted(missing_cols)}")
    df = df[available_cols].copy()

    # --- Data types ---
    df["price"] = clean_price_column(df["price"])
    if "host_response_rate" in df.columns:
        df["host_response_rate"] = clean_percentage_column(df["host_response_rate"])

    for col in ["host_since", "first_review", "last_review"]:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")

    for col in ["host_is_superhost", "host_identity_verified", "instant_bookable"]:
        if col in df.columns:
            df[col] = df[col].map({"t": True, "f": False}).astype("boolean")

    # bathrooms sometimes only exists as free text ("1.5 baths")
    if "bathrooms" not in df.columns and "bathrooms_text" in df.columns:
        df["bathrooms"] = (
            df["bathrooms_text"].astype(str).str.extract(r"(\d+\.?\d*)").astype(float)
        )

    # --- Missing values ---
    numeric_fill_median = [
        "bedrooms", "beds", "bathrooms", "review_scores_rating",
        "review_scores_cleanliness", "review_scores_checkin",
        "review_scores_communication", "review_scores_location",
        "review_scores_value", "reviews_per_month",
    ]
    for col in numeric_fill_median:
        if col in df.columns:
            df[col] = df[col].fillna(df[col].median())

    if "host_response_rate" in df.columns:
        # Missing response rate usually means the host has never been asked
        # (very few bookings) — flag it rather than guessing a value.
        df["host_response_rate_missing"] = df["host_response_rate"].isna()
        df["host_response_rate"] = df["host_response_rate"].fillna(0)

    if "host_is_superhost" in df.columns:
        df["host_is_superhost"] = df["host_is_superhost"].fillna(False)

    # Drop rows with no price at all — unusable for revenue analysis
    before = len(df)
    df = df.dropna(subset=["price"])
    print(f"Dropped {before - len(df)} rows with null price")

    # Drop exact duplicate listing ids
    before = len(df)
    df = df.drop_duplicates(subset=["id"])
    print(f"Dropped {before - len(df)} duplicate listing ids")

    # --- Outlier treatment ---
    df["price"] = cap_outliers_iqr(df["price"])
    if "minimum_nights" in df.columns:
        # Minimum nights of 1000+ are effectively "not bookable" listings
        df["minimum_nights"] = df["minimum_nights"].clip(upper=365)

    print(f"Clean shape: {df.shape}")
    return df


# ----------------------------------------------------------------------
# 2. CLEAN CALENDAR  (this is the table Revenue & Occupancy come from)
# ----------------------------------------------------------------------
def clean_calendar(listing_prices: pd.Series | None = None) -> pd.DataFrame:
    print_section("Cleaning calendar.csv")

    df = pd.read_csv(CALENDAR_PATH, low_memory=False)
    print(f"Raw shape: {df.shape}")

    if "listing_id" not in df.columns or "date" not in df.columns or "available" not in df.columns:
        required = {"listing_id", "date", "available"}
        missing = sorted(required - set(df.columns))
        raise ValueError(f"calendar.csv is missing required columns: {missing}")

    df["date"] = pd.to_datetime(df["date"], errors="coerce")
    if "price" in df.columns:
        df["price"] = clean_price_column(df["price"])
    elif "adjusted_price" in df.columns:
        # Some Inside Airbnb exports publish only adjusted_price.
        df["price"] = clean_price_column(df["adjusted_price"])
    elif listing_prices is not None:
        # Other exports omit all calendar prices. Use the listing snapshot's
        # nightly base price so availability can still support an estimate.
        df["price"] = df["listing_id"].map(listing_prices)
        print("Note: calendar has no price field; using listings.csv base price")
    else:
        raise ValueError(
            "calendar.csv has no price or adjusted_price column, and no listing price map was provided"
        )
    if "adjusted_price" in df.columns:
        df["adjusted_price"] = clean_price_column(df["adjusted_price"])

    # available: 't' = bookable/open, 'f' = blocked (our proxy for "booked")
    df["available"] = df["available"].map({"t": True, "f": False})

    # A blocked night with no price on file can't contribute to revenue —
    # fall back to the listing's own median calendar price. Exclude empty
    # groups before calculating medians to avoid noisy all-NaN warnings.
    valid_prices = df.dropna(subset=["price"])
    listing_medians = valid_prices.groupby("listing_id")["price"].median()
    df["price"] = df["price"].fillna(df["listing_id"].map(listing_medians))
    # If a listing has literally no price on any date, fall back to 0 and
    # flag it — better than silently dropping the listing from occupancy calcs.
    df["price"] = df["price"].fillna(0)

    before = len(df)
    df = df.dropna(subset=["date", "available"])
    print(f"Dropped {before - len(df)} rows with null date/availability")

    print(f"Clean shape: {df.shape}")
    return df


# ----------------------------------------------------------------------
# 3. CLEAN REVIEWS
# ----------------------------------------------------------------------
def clean_reviews() -> pd.DataFrame:
    print_section("Cleaning reviews.csv")

    df = pd.read_csv(REVIEWS_PATH, low_memory=False)
    print(f"Raw shape: {df.shape}")

    df["date"] = pd.to_datetime(df["date"], errors="coerce")
    df = df.dropna(subset=["date"])

    # Basic text cleanup — strip HTML remnants Inside Airbnb sometimes leaves in
    if "comments" in df.columns:
        df["comments"] = (
            df["comments"]
            .astype(str)
            .str.replace(r"<br\s*/?>", " ", regex=True)
            .str.strip()
        )

    before = len(df)
    df = df.drop_duplicates(subset=["id"]) if "id" in df.columns else df
    print(f"Dropped {before - len(df)} duplicate review ids")

    print(f"Clean shape: {df.shape}")
    return df


# ----------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------
if __name__ == "__main__":
    listings_clean = clean_listings()
    listing_prices = listings_clean.set_index("id")["price"]
    calendar_clean = clean_calendar(listing_prices)
    reviews_clean = clean_reviews()

    listings_clean.to_csv(os.path.join(PROCESSED_DIR, "listings_clean.csv"), index=False)
    calendar_clean.to_csv(os.path.join(PROCESSED_DIR, "calendar_clean.csv"), index=False)
    reviews_clean.to_csv(os.path.join(PROCESSED_DIR, "reviews_clean.csv"), index=False)

    print_section("DONE")
    print("Wrote: listings_clean.csv, calendar_clean.csv, reviews_clean.csv")
    print("Next: python scripts/02_feature_engineering.py")
