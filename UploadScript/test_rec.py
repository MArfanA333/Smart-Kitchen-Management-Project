import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
from datetime import datetime

# 🔒 Replace this with your actual UID
USER_ID = 'C6tmjf2PVJSQFlyBKsat0SJqBUu1'

# 🔑 Firebase service account path
cred = credentials.Certificate('smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

def get_interaction_keywords():
    interaction_keywords = defaultdict(int)

    viewed_ref = db.collection(f'users/{USER_ID}/recipes/viewed/items')
    reviewed_ref = db.collection(f'users/{USER_ID}/recipes/reviewed/items')

    viewed_ids = [doc.id for doc in viewed_ref.stream()]
    reviewed_ids = [doc.id for doc in reviewed_ref.stream()]

    all_ids = set(viewed_ids + reviewed_ids)
    print(f"Total unique interacted recipes: {len(all_ids)}")

    for recipe_id in all_ids:
        doc = db.collection('recipes').document(recipe_id).get()
        if not doc.exists:
            continue
        data = doc.to_dict()

        for kw in data.get("Keywords", []):
            interaction_keywords[kw] += 1

    return interaction_keywords

def get_recommendations_by_keywords(keywords_dict):
    recommended_ids = set()

    for keyword in keywords_dict.keys():
        recipes_query = db.collection('recipes').where(
            filter=firestore.FieldFilter("Keywords", "array_contains", keyword)
        ).limit(20)

        for recipe_doc in recipes_query.stream():
            recipe_data = recipe_doc.to_dict()
            rid = recipe_data.get('Id')
            if rid:
                recommended_ids.add(rid)

    return list(recommended_ids)

def store_recommendations(recommended_ids):
    print("\n💾 Storing recommendations to Firestore...")
    batch = db.batch()

    for rid in recommended_ids:
        rec_doc_ref = db.document(f'users/{USER_ID}/recipes/recommended/items/{rid}')
        batch.set(rec_doc_ref, {
            'recipeId': rid,
            'timestamp': firestore.SERVER_TIMESTAMP
        })

    batch.commit()
    print(f"✅ Stored {len(recommended_ids)} recommendations.")

if __name__ == '__main__':
    print("📥 Fetching user interaction keywords...")
    keywords_dict = get_interaction_keywords()

    print("\n📊 Keyword frequencies from user interactions:")
    for kw, count in keywords_dict.items():
        print(f"{kw}: {count}")

    print("\n🔍 Querying recipes based on keywords...")
    recommended = get_recommendations_by_keywords(keywords_dict)

    print(f"\n✅ Found {len(recommended)} recommended recipes:")
    for rid in recommended:
        print(rid)

    store_recommendations(recommended)
