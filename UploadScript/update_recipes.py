import firebase_admin
from firebase_admin import credentials, firestore
import time
from tqdm import tqdm

# Initialize Firebase
cred = credentials.Certificate('smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

def fetch_ingredient_data(ingredient_id):
    doc = db.collection('ingredients_list').document(ingredient_id).get()
    return doc.to_dict() if doc.exists else None

def calculate_totals(ingredients):
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

    for ing in ingredients:
        weight = ing['weight']
        factor = weight / 100.0
        data = ing['data']

        totals["Calories"] += (data.get("calories") or 0) * factor
        totals["ProteinContent"] += (data.get("protein") or 0) * factor
        totals["CarbohydrateContent"] += (data.get("carbohydrate") or 0) * factor
        totals["FatContent"] += (data.get("fat") or 0) * factor
        totals["SaturatedFatContent"] += (data.get("saturatedfat") or 0) * factor
        totals["SodiumContent"] += (data.get("sodium") or 0) * factor
        totals["FiberContent"] += (data.get("fiber") or 0) * factor
        totals["SugarContent"] += (data.get("sugar") or 0) * factor

    if totals["CholesterolContent"] == 0:
        totals["CholesterolContent"] = None
    if totals["SodiumContent"] == 0:
        totals["SodiumContent"] = None

    return totals

def fetch_zero_calorie_recipes():
    query = db.collection('recipes').where('Calories', '==', 0.0).limit(500)
    recipes = []
    docs = query.stream()
    last_doc = None

    while True:
        batch = list(docs)
        if not batch:
            break
        recipes.extend(batch)
        last_doc = batch[-1]
        docs = db.collection('recipes').where('Calories', '==', 0.0).start_after(last_doc).limit(500).stream()

    return recipes

def update_recipe_nutrition_batch():
    recipe_docs = fetch_zero_calorie_recipes()
    print(f"Total recipes to update: {len(recipe_docs)}")

    batch_size = 25
    total_batches = (len(recipe_docs) + batch_size - 1) // batch_size

    for batch_num in range(total_batches):
        batch_writer = db.batch()
        start_idx = batch_num * batch_size
        end_idx = min(start_idx + batch_size, len(recipe_docs))
        batch = recipe_docs[start_idx:end_idx]

        for doc in tqdm(batch, desc=f"Batch {batch_num + 1}/{total_batches}"):
            recipe = doc.to_dict()
            ingredient_names = recipe.get('RecipeIngredientParts', [])
            ingredient_weights = recipe.get('RecipeIngredientQuantities', [])

            if len(ingredient_names) != len(ingredient_weights):
                print(f"⚠️ Skipping {recipe.get('Name')} — mismatched ingredients & weights.")
                continue

            ingredients = []
            for i in range(len(ingredient_names)):
                name = ingredient_names[i]
                weight = ingredient_weights[i]

                # Reverse lookup: name match
                query = db.collection('ingredients_list').where('name', '==', name).limit(1).get()
                if query:
                    ingredient_data = query[0].to_dict()
                    ingredients.append({
                        'weight': weight,
                        'data': ingredient_data
                    })
                else:
                    print(f"❗ Ingredient '{name}' not found for recipe '{recipe.get('Name')}'. Skipping.")
                    break  # skip incomplete recipes

            if len(ingredients) != len(ingredient_names):
                continue  # skip update for incomplete recipes

            totals = calculate_totals(ingredients)

            update_data = {
                "Calories": totals["Calories"],
                "ProteinContent": totals["ProteinContent"],
                "CarbohydrateContent": totals["CarbohydrateContent"],
                "FatContent": totals["FatContent"],
                "SaturatedFatContent": totals["SaturatedFatContent"],
                "CholesterolContent": totals["CholesterolContent"],
                "SodiumContent": totals["SodiumContent"],
                "FiberContent": totals["FiberContent"],
                "SugarContent": totals["SugarContent"]
            }

            batch_writer.update(doc.reference, update_data)

        batch_writer.commit()
        print(f"✅ Batch {batch_num + 1}/{total_batches} committed.")
        time.sleep(2)  # Small pause for Firestore breathing room

    print("\n🎯 All recipe updates complete!")

if __name__ == "__main__":
    update_recipe_nutrition_batch()
