import json
import firebase_admin
from firebase_admin import credentials, firestore
import time

# Initialize Firebase Admin
cred = credentials.Certificate('smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# File path
JSON_FILE = 'cleaned_recipes.json'

# Load recipes
with open(JSON_FILE, 'r') as f:
    recipes = json.load(f)

# Firestore collection
collection_ref = db.collection('recipes')

# Fields to update in Firestore
ALLOWED_FIELDS = {
    'instructions', 'ingredients', 'images', 'AggregatedRating', 'ReviewCount',
    'calories', 'proteinContent', 'carbohydrateContent', 'fatContent',
    'saturatedFatContent', 'cholesterolContent', 'sodiumContent', 'fiberContent', 'sugarContent'
}

updated_count = 0

for recipe in recipes:
    try:
        docs = collection_ref.where('Name', '==', recipe['name']).limit(1).stream()
        doc_list = list(docs)

        if not doc_list:
            print(f"❌ Not found: {recipe['name']}")
            continue

        doc_ref = doc_list[0].reference

        # Prepare update dictionary using correct Firestore field names
        update_data = {}
        for key in ALLOWED_FIELDS:
            # Handle case sensitivity between input JSON and Firestore fields
            json_key = key[0].lower() + key[1:] if key in ['AggregatedRating', 'ReviewCount'] else key
            if json_key in recipe:
                update_data[key] = recipe[json_key]

        if update_data:
            doc_ref.update(update_data)
            updated_count += 1
            print(f"✅ Updated ({updated_count}): {recipe['name']} -> {list(update_data.keys())}")
        else:
            print(f"⚠️ Skipped (no matching fields): {recipe['name']}")

        time.sleep(0.05)

    except Exception as e:
        print(f"🔥 Error updating '{recipe['name']}': {e}")

print(f"🎉 Done! Total recipes updated: {updated_count}")
