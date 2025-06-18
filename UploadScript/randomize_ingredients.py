import firebase_admin
from firebase_admin import credentials, firestore
import random
import time
from tqdm import tqdm

# Initialize Firebase
cred = credentials.Certificate('smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

def randomize_zeros_in_ingredients():
    ingredient_docs = list(db.collection('ingredients_list').stream())
    print(f"Total ingredients found: {len(ingredient_docs)}")

    for doc in tqdm(ingredient_docs, desc="Processing ingredients"):
        data = doc.to_dict()
        updated = False

        # Fields you want to check
        nutrition_fields = [
            'calories', 'carbohydrate', 'fat', 
            'fiber', 'protein', 'saturatedfat', 'sugar'
        ]

        for field in nutrition_fields:
            if field in data and (data[field] == 0 or data[field] is None):
                new_value = round(random.uniform(10, 50), 2)
                data[field] = new_value
                updated = True

        if updated:
            doc.reference.update(data)
            print(f"Updated: {data.get('name', 'Unnamed Ingredient')}")

    print("\n🎯 All ingredients processed!")

if __name__ == "__main__":
    randomize_zeros_in_ingredients()
