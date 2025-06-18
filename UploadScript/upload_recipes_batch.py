import firebase_admin
from firebase_admin import credentials, firestore
import json
import uuid
import re
import time
from tqdm import tqdm

# Initialize Firebase
cred = credentials.Certificate('smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

def preload_existing_ingredients(retries=5):
    for attempt in range(retries):
        try:
            ingredient_docs = db.collection('ingredients_list').stream()
            ingredients = {}
            for doc in ingredient_docs:
                data = doc.to_dict()
                if 'name_lower' not in data:
                    if 'name' in data:
                        name_lower = data['name'].lower()
                        doc.reference.update({'name_lower': name_lower})
                        data['name_lower'] = name_lower
                        print(f"Fixed missing name_lower for: {data['name']}")
                    else:
                        print(f"Skipping doc {doc.id} — no name field.")
                        continue
                ingredients[data['name_lower']] = {'id': doc.id, 'data': data}
            return ingredients
        except Exception as e:
            print(f"Error loading ingredients (Attempt {attempt + 1}/{retries}): {e}")
            time.sleep(5)
    raise Exception("Failed to preload ingredients after multiple attempts.")

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
    print(f"Added new ingredient: {name}")
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

    # Optional: Treat cholesterol and sodium as None if 0
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
    existing_ingredients = preload_existing_ingredients()

    with open(filepath, 'r') as f:
        recipes = json.load(f)

    # Filter out duplicates first
    unique_recipes = []
    for recipe in recipes:
        existing = db.collection('recipes').where('Name', '==', recipe['name']).limit(1).get()
        if not existing:
            unique_recipes.append(recipe)
        else:
            print(f"Skipped duplicate recipe: {recipe['name']}")

    print(f"\nTotal new recipes to upload: {len(unique_recipes)}")

    batch_size = 500
    total_batches = (len(unique_recipes) + batch_size - 1) // batch_size

    for batch_num in tqdm(range(total_batches), desc="Uploading batches"):
        batch = db.batch()
        batch_recipes = unique_recipes[batch_num * batch_size:(batch_num + 1) * batch_size]

        for recipe in tqdm(batch_recipes, desc=f"Batch {batch_num + 1}/{total_batches}", leave=False):
            ingredients = []
            ingredient_quantities = []
            ingredient_parts = []

            for ing in recipe['ingredients']:
                name = ing['name'].strip()
                weight = ing['weight']
                name_lower = name.lower()

                if name_lower in existing_ingredients:
                    ing_id = existing_ingredients[name_lower]['id']
                    ing_data = existing_ingredients[name_lower]['data']
                else:
                    ing_id, ing_data = add_ingredient(name)
                    existing_ingredients[name_lower] = {'id': ing_id, 'data': ing_data}

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

            doc_ref = db.collection('recipes').document(recipe_id)
            batch.set(doc_ref, recipe_doc)

        batch.commit()
        print(f"✅ Batch {batch_num + 1}/{total_batches} uploaded ({len(batch_recipes)} recipes).")

    print("\n🎉 All recipes uploaded successfully!")


if __name__ == "__main__":
    upload_recipes("cleaned_recipes.json")
