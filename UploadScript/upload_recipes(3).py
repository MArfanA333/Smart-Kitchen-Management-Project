import firebase_admin
from firebase_admin import credentials, firestore
import json
import uuid
import re
from tqdm import tqdm

# Initialize Firebase
cred = credentials.Certificate('smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

def get_existing_ingredient_by_name(name):
    name_lower = name.lower()
    results = db.collection('ingredients_list') \
        .where('name_lower', '==', name_lower) \
        .get()
    return results[0] if results else None

def add_ingredient(name):
    name_lower = name.lower()
    ingredient_data = {
        "name": name,
        "name_lower": name_lower,
        "calories": 0.0,
        "carbohydrate": 0.0,
        "fat": 0.0,
        "fiber": 0.0,
        "protein": 0.0,
        "saturatedfat": 0.0,
        "sugar": 0.0,
        "cholesterol": None,
        "sodium": None,
    }
    doc_ref = db.collection('ingredients_list').document()
    doc_ref.set(ingredient_data)
    return doc_ref.id, ingredient_data

def calculate_nutrition(ingredients):
    totals = {
        "Calories": 0.0,
        "ProteinContent": 0.0,
        "CarbohydrateContent": 0.0,
        "FatContent": 0.0,
        "SaturatedFatContent": 0.0,
        "CholesterolContent": 0.0,
        "SodiumContent": 0.0,
        "FiberContent": 0.0,
        "SugarContent": 0.0
    }

    for ingredient in ingredients:
        weight = ingredient["weight"]
        factor = weight / 100.0
        nutrition = ingredient["nutrition"]

        totals["Calories"] += (nutrition.get("calories") or 0) * factor
        totals["ProteinContent"] += (nutrition.get("protein") or 0) * factor
        totals["CarbohydrateContent"] += (nutrition.get("carbohydrate") or 0) * factor
        totals["FatContent"] += (nutrition.get("fat") or 0) * factor
        totals["SaturatedFatContent"] += (nutrition.get("saturatedfat") or 0) * factor
        totals["SodiumContent"] += (nutrition.get("sodium") or 0) * factor
        totals["FiberContent"] += (nutrition.get("fiber") or 0) * factor
        totals["SugarContent"] += (nutrition.get("sugar") or 0) * factor

    if totals["CholesterolContent"] == 0:
        totals["CholesterolContent"] = None
    if totals["SodiumContent"] == 0:
        totals["SodiumContent"] = None

    return totals

def parse_total_time(prep, cook):
    def get_minutes(t):
        if not t:
            return 0
        match = re.match(r"PT(?:(\d+)H)?(?:(\d+)M)?", t)
        if not match:
            return 0
        hours = int(match.group(1)) if match.group(1) else 0
        minutes = int(match.group(2)) if match.group(2) else 0
        return hours * 60 + minutes

    total_minutes = get_minutes(prep) + get_minutes(cook)
    return f"PT{total_minutes}M" if total_minutes > 0 else None

def upload_recipes(filepath):
    with open(filepath, 'r') as f:
        recipes = json.load(f)

    for recipe in tqdm(recipes):
        # Check for duplicates by Name
        existing = db.collection('recipes').where('Name', '==', recipe['name']).limit(1).get()
        if existing:
            print(f"Skipped duplicate recipe: {recipe['name']}")
            continue

        ingredients = []
        ingredient_quantities = []
        ingredient_parts = []

        for ing in recipe['ingredients']:
            name = ing['name'].strip()
            weight = ing['weight']
            existing = get_existing_ingredient_by_name(name)

            if existing:
                ing_id = existing.id
                ing_data = existing.to_dict()
            else:
                ing_id, ing_data = add_ingredient(name)

            ingredients.append({
                'id': ing_id,
                'name': name,
                'weight': weight,
                'nutrition': {
                    'calories': ing_data.get('calories', 0.0),
                    'carbohydrate': ing_data.get('carbohydrate', 0.0),
                    'fat': ing_data.get('fat', 0.0),
                    'fiber': ing_data.get('fiber', 0.0),
                    'protein': ing_data.get('protein', 0.0),
                    'saturatedfat': ing_data.get('saturatedfat', 0.0),
                    'sugar': ing_data.get('sugar', 0.0),
                    'cholesterol': ing_data.get('cholesterol', 0.0),
                    'sodium': ing_data.get('sodium', 0.0),
                }
            })
            ingredient_quantities.append(weight)
            ingredient_parts.append(name)

        nutrition_totals = calculate_nutrition(ingredients)

        recipe_id = str(uuid.uuid4())
        recipe_doc = {
            "Id": recipe_id,
            "Name": recipe['name'],
            "CookTime": recipe['cookTime'],
            "PrepTime": recipe['prepTime'],
            "TotalTime": parse_total_time(recipe['prepTime'], recipe['cookTime']),
            "Images": [],
            "ExpiryDate": recipe['expiryDate'],
            "RecipeCategory": recipe['category'],
            "Keywords": recipe['keywords'],
            "RecipeIngredientQuantities": ingredient_quantities,
            "RecipeIngredientParts": ingredient_parts,
            "AggregatedRating": 0,
            "ReviewCount": 0,
            "Calories": nutrition_totals["Calories"],
            "ProteinContent": nutrition_totals["ProteinContent"],
            "CarbohydrateContent": nutrition_totals["CarbohydrateContent"],
            "FatContent": nutrition_totals["FatContent"],
            "SaturatedFatContent": nutrition_totals["SaturatedFatContent"],
            "CholesterolContent": nutrition_totals["CholesterolContent"],
            "SodiumContent": nutrition_totals["SodiumContent"],
            "FiberContent": nutrition_totals["FiberContent"],
            "SugarContent": nutrition_totals["SugarContent"],
            "RecipeServings": recipe['servings'],
            "RecipeYield": recipe['yield'],
            "RecipeInstructions": recipe['instructions']
        }

        db.collection('recipes').document(recipe_id).set(recipe_doc)
        print(f"Uploaded recipe: {recipe['name']}")

if __name__ == "__main__":
    upload_recipes("cleaned_recipes.json")
