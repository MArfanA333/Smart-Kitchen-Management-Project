import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore
from tqdm import tqdm
import uuid
import ast

# Initialize Firebase
cred = credentials.Certificate('smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Load the dataset
df = pd.read_csv('meals_trimmed_5.csv')

# Handle nested stringified lists
def parse_column(value):
    try:
        if isinstance(value, str) and value.startswith('c('):
            return ast.literal_eval(value[1:].replace('c', '').strip())
        elif isinstance(value, str):
            return ast.literal_eval(value)
        else:
            return value
    except:
        return []

# Preprocess certain columns
df['Keywords'] = df['Keywords'].apply(parse_column)
df['RecipeIngredientQuantities'] = df['RecipeIngredientQuantities'].apply(parse_column)
df['RecipeIngredientParts'] = df['RecipeIngredientParts'].apply(parse_column)
df['Images'] = df['Images'].apply(lambda x: [] if pd.isna(x) or 'character' in str(x) else [x])

# Load ingredient collection
ingredient_collection = db.collection('ingredient_list')
existing_ingredients = {doc.id.lower() for doc in ingredient_collection.stream()}

# Default nutrition values
default_nutrition = {
    "Calories": 0.0,
    "ProteinContent": 0.0,
    "CarbohydrateContent": 0.0,
    "FatContent": 0.0,
    "SaturatedFatContent": 0.0,
    "CholesterolContent": None,
    "SodiumContent": None,
    "FiberContent": 0.0,
    "SugarContent": 0.0,
}

# Upload recipes
for _, row in tqdm(df.iterrows(), total=len(df)):
    recipe_id = str(uuid.uuid4())
    ingredient_names = row['RecipeIngredientParts']
    ingredient_quantities = row['RecipeIngredientQuantities']

    # Ensure all ingredients are added
    for ingredient in ingredient_names:
        if ingredient and ingredient.lower() not in existing_ingredients:
            ingredient_doc = {
                "Name": ingredient,
                **default_nutrition
            }
            ingredient_collection.document(ingredient).set(ingredient_doc)
            existing_ingredients.add(ingredient.lower())

    # Build recipe doc
    recipe_doc = {
        "Id": recipe_id,
        "Name": row["Name"] if "Name" in row else "Unnamed",
        "CookTime": row.get("CookTime", ""),
        "PrepTime": row.get("PrepTime", ""),
        "TotalTime": row.get("TotalTime", ""),
        "Images": row["Images"],
        "ExpiryDate": int(row.get("ExpiryDate", 3)),  # keep as-is
        "RecipeCategory": row.get("RecipeCategory", ""),
        "Keywords": row.get("Keywords", []),
        "RecipeIngredientQuantities": ingredient_quantities,
        "RecipeIngredientParts": ingredient_names,
        "AggregatedRating": 0,
        "ReviewCount": 0,
        "Calories": float(row.get("Calories", 0)),
        "ProteinContent": float(row.get("ProteinContent", 0)),
        "CarbohydrateContent": float(row.get("CarbohydrateContent", 0)),
        "FatContent": float(row.get("FatContent", 0)),
        "SaturatedFatContent": float(row.get("SaturatedFatContent", 0)),
        "CholesterolContent": float(row["CholesterolContent"]) if pd.notna(row.get("CholesterolContent")) else None,
        "SodiumContent": float(row["SodiumContent"]) if pd.notna(row.get("SodiumContent")) else None,
        "FiberContent": float(row.get("FiberContent", 0)),
        "SugarContent": float(row.get("SugarContent", 0)),
        "RecipeServings": str(row.get("RecipeServings", "")),
        "RecipeYield": str(row.get("RecipeYield", "")),
        "RecipeInstructions": str(row.get("RecipeInstructions", ""))
    }

    db.collection("recipes").document(recipe_id).set(recipe_doc)

print("✅ Upload complete.")
