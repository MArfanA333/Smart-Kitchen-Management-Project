import firebase_admin
from firebase_admin import credentials, firestore
import time
from collections import defaultdict

# Set this to the target user's UID
USER_ID = 'C6tmjf2PVJSQFlyBKsat0SJqBUu1'

cred = credentials.Certificate('smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

# Stores last update timestamps to detect changes
last_seen = {}

def get_user_interactions():
    viewed_ref = db.collection(f'users/{USER_ID}/recipes/viewed/items')
    reviewed_ref = db.collection(f'users/{USER_ID}/recipes/reviewed/items')
    saved_collections_ref = db.collection(f'users/{USER_ID}/recipes/saved/collection')

    viewed = [doc.id for doc in viewed_ref.stream()]
    reviewed = [doc.id for doc in reviewed_ref.stream()]
    
    saved_recipe_ids = []
    for col_doc in saved_collections_ref.stream():
        saved_recipe_ids.extend(col_doc.to_dict().get("recipes", []))

    return set(viewed + reviewed + saved_recipe_ids)

def generate_recommendations(interacted_ids):
    all_recipes = db.collection('recipes').stream()

    interaction_keywords = defaultdict(int)
    interaction_ingredients = defaultdict(int)

    for recipe_id in interacted_ids:
        recipe = db.collection('recipes').document(recipe_id).get()
        if recipe.exists:
            data = recipe.to_dict()
            for kw in data.get("Keywords", []):
                interaction_keywords[kw.lower()] += 1
            for ing in data.get("RecipeIngredientParts", []):
                interaction_ingredients[ing.lower()] += 1

    scored = []
    for recipe_doc in all_recipes:
        recipe = recipe_doc.to_dict()
        rid = recipe.get("Id")
        if rid in interacted_ids:
            continue

        score = 0
        for kw in recipe.get("Keywords", []):
            score += interaction_keywords.get(kw.lower(), 0)
        for ing in recipe.get("RecipeIngredientParts", []):
            score += interaction_ingredients.get(ing.lower(), 0)

        if score > 0:
            scored.append((score, rid))

    scored.sort(reverse=True)
    return [rid for _, rid in scored[:20]]  # Top 20 recipes

def update_recommendations():
    print(f"Updating recommendations for {USER_ID}...")
    interacted_ids = get_user_interactions()
    recommendations = generate_recommendations(interacted_ids)

    db.collection('users').document(USER_ID).collection('recommendations').document('list').set({
        'recipeIds': recommendations,
        'updatedAt': firestore.SERVER_TIMESTAMP
    })
    print(f"Updated {len(recommendations)} recommendations.")

def has_new_interactions():
    updated = False
    collections = [
        ('viewed', f'users/{USER_ID}/recipes/viewed/items'),
        ('reviewed', f'users/{USER_ID}/recipes/reviewed/items'),
        ('saved', f'users/{USER_ID}/recipes/saved/collection'),
    ]

    for name, path in collections:
        ref = db.collection(path)
        max_time = last_seen.get(name, 0)

        docs = ref.stream()
        max_doc_time = max_time
        for doc in docs:
            update_time = doc.update_time.timestamp()
            if update_time > max_time:
                updated = True
            if update_time > max_doc_time:
                max_doc_time = update_time

        last_seen[name] = max_doc_time

    return updated

def main():
    while True:
        try:
            if has_new_interactions():
                update_recommendations()
        except Exception as e:
            print(f"Error: {e}")
        time.sleep(15)  # Poll every 15 seconds

if __name__ == '__main__':
    main()
