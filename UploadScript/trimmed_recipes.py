import pandas as pd

# File paths
TRIMMED_RECIPES_FILE = 'meals_trimmed.csv'
REVIEWS_FILE = 'reviews_names.csv'
OUTPUT_FILE = 'filtered_reviews.json'

# Load data
trimmed_df = pd.read_csv(TRIMMED_RECIPES_FILE)
reviews_df = pd.read_csv(REVIEWS_FILE)

# Ensure 'Name' column exists
if 'Name' not in trimmed_df.columns or 'Name' not in reviews_df.columns:
    raise ValueError("Missing 'Name' column in one of the input CSVs.")

# Filter reviews
valid_names = set(trimmed_df['Name'].str.strip())
filtered_reviews_df = reviews_df[reviews_df['Name'].str.strip().isin(valid_names)]

filtered_reviews_df.to_json(OUTPUT_FILE, orient='records', indent=2)
print(f"✅ Filtered reviews saved to {OUTPUT_FILE} ({len(filtered_reviews_df)} records)")
