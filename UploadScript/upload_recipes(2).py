import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore
import uuid
import re
from tqdm import tqdm

# Initialize Firebase Admin SDK
cred = credentials.Certificate('smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Load the CSV
df = pd.read_csv('meals_trimmed_5.csv')

# Parse c("ingredient1", "ingredient2") format
def parse_r_style_list(s):
    if pd.isna(s):
        return []
    return re.findall(r'"(.*?)"', s)

# Helper to get or create an ingredient document
def get_or_create_ingredient(name):
    ingredients_ref = db.collection("ingredients_list")
    query = ingredients_ref.where("name", "==", name).limit(1).stream()
    for doc in query:
        return doc.to_dict()  # return existing
    # Not found, create
    new_id = str(uuid.uuid4())
    ingredient_data = {
        "id": new_id,
        "name": name,
        "nutrition": {
            "calories": 0.0,
            "carbohydrate": 0.0,
            "fat": 0.0,
            "fiber": 0.0,
            "protein": 0.0,
            "saturatedfat": 0.0,
            "sugar": 0.0,
            "weight": 0.0
        }
    }
    ingredients_ref.document(new_id).set(ingredient_data)
    return ingredient_data

# Process each recipe
for _, row in tqdm(df.iterrows(), total=len(df), desc="Uploading Recipes"):
    ingredient_names = parse_r_style_list(row.get('RecipeIngredientParts', ''))
    ingredient_quantities = parse_r_style_list(row.get('RecipeIngredientQuantities', ''))

    if len(ingredient_names) == 0 or len(ingredient_names) != len(ingredient_quantities):
        continue  # skip invalid rows

    ingredients = []
    for name, qty in zip(ingredient_names, ingredient_quantities):
        ingredient = get_or_create_ingredient(name)
        ingredients.append({
            "id": ingredient["id"],
            "name": ingredient["name"],
            "nutrition": ingredient["nutrition"],
            "quantity": qty
        })

    recipe_doc = {
        "Id": str(uuid.uuid4()),
        "Name": row.get("Name", ""),
        "CookTime": row.get("CookTime", ""),
        "PrepTime": row.get("PrepTime", ""),
        "TotalTime": row.get("TotalTime", ""),
        "Images": parse_r_style_list(row.get("Images", "")),
        "ExpiryDate": int(row.get("ExpiryDate", 0)),
        "RecipeCategory": row.get("RecipeCategory", ""),
        "Keywords": parse_r_style_list(row.get("Keywords", "")),
        "RecipeIngredientQuantities": ingredient_quantities,
        "RecipeIngredientParts": ingredient_names,
        "AggregatedRating": float(row.get("AggregatedRating", 0)),
        "ReviewCount": int(row.get("ReviewCount", 0)) if not pd.isna(row.get("ReviewCount")) else 0,
        "Calories": float(row.get("Calories", 0)),
        "ProteinContent": float(row.get("ProteinContent", 0)),
        "CarbohydrateContent": float(row.get("CarbohydrateContent", 0)),
        "FatContent": float(row.get("FatContent", 0)),
        "SaturatedFatContent": float(row.get("SaturatedFatContent", 0)),
        "CholesterolContent": float(row["CholesterolContent"]) if not pd.isna(row.get("CholesterolContent")) else None,
        "SodiumContent": float(row["SodiumContent"]) if not pd.isna(row.get("SodiumContent")) else None,
        "FiberContent": float(row.get("FiberContent", 0)),
        "SugarContent": float(row.get("SugarContent", 0)),
        "RecipeServings": str(row.get("RecipeServings", "")),
        "RecipeYield": str(row.get("RecipeYield", "")),
        "RecipeInstructions": row.get("RecipeInstructions", ""),
        "ingredients": ingredients
    }

    db.collection("recipes").document(recipe_doc["Id"]).set(recipe_doc)
