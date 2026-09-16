"""
04_ml_price_prediction.py
---------------------------
Airbnb Market Analytics & Investment Platform — Phase 6 (Bonus)

Predicts a listing's price from its own characteristics (size, location,
host quality, review history) — the "what should I list this at" question
a new host actually has.

CRITICAL — LEAKAGE AVOIDANCE:
Several columns in master_analytics_table.csv are mathematically DERIVED
FROM price itself (price_category is a quartile bin of price;
estimated_property_value and estimated_annual_roi_pct are built from it;
adr/revpar/pricing_gap/avg_open_listing_price all come from the same
calendar price signal). Including any of these as model features would let
the model "predict" price by reversing arithmetic it was given, producing
a misleadingly perfect-looking model that's useless in production, since a
new host doesn't have an ADR or RevPAR yet — that's exactly what we're
trying to help them set. This script explicitly excludes all of them; see
EXCLUDED_LEAKAGE_COLUMNS below.

Run AFTER 02_feature_engineering.py:
    python scripts/04_ml_price_prediction.py
"""

import os
import numpy as np
import pandas as pd

from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestRegressor
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

PROCESSED_DIR = os.path.join("data", "processed")
RANDOM_STATE = 42

TARGET = "price"

NUMERIC_FEATURES = [
    "accommodates", "bedrooms", "beds", "bathrooms", "amenity_count",
    "minimum_nights", "maximum_nights", "host_experience_years",
    "host_response_rate", "number_of_reviews", "reviews_per_month",
    "review_score_composite",
]
CATEGORICAL_FEATURES = [
    "room_type", "property_type", "neighbourhood_cleansed",
    "host_is_superhost", "instant_bookable",
]

# Every one of these is mathematically derived from `price` (directly or via
# the calendar price signal) and MUST NOT be used as a model input.
EXCLUDED_LEAKAGE_COLUMNS = [
    "price_category", "price_category_sort", "neighbourhood_median_price_per_bedroom",
    "estimated_property_value", "estimated_annual_roi_pct", "is_synthetic_valuation",
    "adr", "revpar", "avg_open_listing_price", "pricing_gap", "pricing_signal",
    "revenue_estimate", "occupancy_rate", "booked_nights", "total_nights_tracked",
]


def print_section(title: str) -> None:
    print("\n" + "=" * 70)
    print(title)
    print("=" * 70)


def load_data() -> pd.DataFrame:
    df = pd.read_csv(os.path.join(PROCESSED_DIR, "master_analytics_table.csv"))
    print(f"Loaded master_analytics_table.csv: {df.shape}")

    missing_leak_check = [c for c in EXCLUDED_LEAKAGE_COLUMNS if c in df.columns]
    print(f"Confirmed excluded (present in source but NOT used as features): {missing_leak_check}")

    available_numeric = [
        c for c in NUMERIC_FEATURES if c in df.columns and df[c].notna().any()
    ]
    available_categorical = [
        c for c in CATEGORICAL_FEATURES if c in df.columns and df[c].notna().any()
    ]
    missing = set(NUMERIC_FEATURES + CATEGORICAL_FEATURES) - set(available_numeric + available_categorical)
    if missing:
        print(f"Note: expected features not found in this export (skipped): {sorted(missing)}")

    keep_cols = available_numeric + available_categorical + [TARGET]
    df = df[keep_cols].dropna(subset=[TARGET])

    # pandas 3.0 defaults text columns to its new native 'str' dtype, which
    # scikit-learn's SimpleImputer/OneHotEncoder (as of sklearn 1.8) don't
    # yet recognize as categorical — they attempt a numeric conversion and
    # fail. Casting explicitly to 'object' restores the dtype sklearn expects.
    for col in available_categorical:
        df[col] = df[col].astype(object)

    print(f"After dropping rows with no {TARGET}: {df.shape}")
    return df, available_numeric, available_categorical


def build_pipeline(numeric_features, categorical_features, model) -> Pipeline:
    numeric_transformer = Pipeline(steps=[
        ("imputer", SimpleImputer(strategy="median")),
        ("scaler", StandardScaler()),
    ])
    categorical_transformer = Pipeline(steps=[
        ("imputer", SimpleImputer(strategy="most_frequent")),
        ("onehot", OneHotEncoder(handle_unknown="ignore")),
    ])
    preprocessor = ColumnTransformer(transformers=[
        ("num", numeric_transformer, numeric_features),
        ("cat", categorical_transformer, categorical_features),
    ])
    return Pipeline(steps=[("preprocessor", preprocessor), ("model", model)])


def evaluate(name: str, pipeline: Pipeline, X_test, y_test) -> dict:
    preds = pipeline.predict(X_test)
    rmse = np.sqrt(mean_squared_error(y_test, preds))
    mae = mean_absolute_error(y_test, preds)
    r2 = r2_score(y_test, preds)
    print(f"\n{name}")
    print(f"  RMSE: ${rmse:,.2f}")
    print(f"  MAE:  ${mae:,.2f}")
    print(f"  R^2:  {r2:.4f}")
    return {"name": name, "rmse": rmse, "mae": mae, "r2": r2}


def print_feature_importance(pipeline: Pipeline, numeric_features, categorical_features, top_n=15):
    print_section("Feature Importance (Random Forest)")
    model = pipeline.named_steps["model"]
    preprocessor = pipeline.named_steps["preprocessor"]

    cat_encoder = preprocessor.named_transformers_["cat"].named_steps["onehot"]
    fitted_categorical_features = next(
        columns for name, _, columns in preprocessor.transformers_ if name == "cat"
    )
    cat_feature_names = list(
        cat_encoder.get_feature_names_out(fitted_categorical_features)
    )
    all_feature_names = numeric_features + cat_feature_names

    importances = model.feature_importances_
    order = np.argsort(importances)[::-1][:top_n]

    print(f"{'Feature':<40} {'Importance':>12}")
    print("-" * 53)
    for i in order:
        print(f"{all_feature_names[i]:<40} {importances[i]:>12.4f}")


if __name__ == "__main__":
    print_section("Loading data")
    df, numeric_features, categorical_features = load_data()

    X = df[numeric_features + categorical_features]
    y = df[TARGET]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=RANDOM_STATE
    )
    print(f"Train: {X_train.shape}, Test: {X_test.shape}")

    print_section("Training models")

    # Baseline: Linear Regression — interpretable, fast, sets a floor to beat
    linreg_pipeline = build_pipeline(
        numeric_features, categorical_features, LinearRegression()
    )
    linreg_pipeline.fit(X_train, y_train)

    # Main model: Random Forest — handles non-linearity and feature
    # interactions (e.g. "extra bedroom" matters more in some neighborhoods
    # than others) that a linear model can't capture.
    rf_pipeline = build_pipeline(
        numeric_features, categorical_features,
        RandomForestRegressor(
            n_estimators=200, max_depth=12, min_samples_leaf=3,
            random_state=RANDOM_STATE, n_jobs=-1,
        ),
    )
    rf_pipeline.fit(X_train, y_train)

    print_section("Evaluation on held-out test set")
    results = [
        evaluate("Linear Regression (baseline)", linreg_pipeline, X_test, y_test),
        evaluate("Random Forest", rf_pipeline, X_test, y_test),
    ]

    best = min(results, key=lambda r: r["rmse"])
    print(f"\nBest model by RMSE: {best['name']}")

    print_feature_importance(rf_pipeline, numeric_features, categorical_features)

    print_section("Sanity check — predictions on 5 test listings")
    sample = X_test.head(5).copy()
    sample["actual_price"] = y_test.head(5).values
    sample["predicted_price"] = rf_pipeline.predict(X_test.head(5)).round(2)
    sample["abs_error"] = (sample["actual_price"] - sample["predicted_price"]).abs().round(2)
    print(sample[["actual_price", "predicted_price", "abs_error"]].to_string(index=False))

    print_section("DONE")
    print("Model trained. In production, persist with joblib.dump(rf_pipeline, 'price_model.pkl')")
    print("and serve behind the 'suggested price' feature referenced in docs/BUSINESS_INSIGHTS.md (Page 4).")
