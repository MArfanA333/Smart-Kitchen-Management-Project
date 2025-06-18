import firebase_admin
from firebase_admin import credentials, firestore
import json

# Initialize Firebase Admin
cred = credentials.Certificate('smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json')  # Replace with your actual path
firebase_admin.initialize_app(cred)

# Connect to Firestore
db = firestore.client()

def fetch_ingredient(ingredient_id):
    # Reference to the ingredients_list collection
    doc_ref = db.collection('ingredients_list').document(ingredient_id)
    doc = doc_ref.get()

    if doc.exists:
        return doc.to_dict()
    else:
        print(f"Ingredient with ID '{ingredient_id}' not found.")
        return None

def save_to_json(data, filename='ingredient.json'):
    with open(filename, 'w') as json_file:
        json.dump(data, json_file, indent=4)
        print(f"Data saved to {filename}")

# Example Usage
ingredient_id = '541384'  # Replace with the document ID of the ingredient you want
ingredient_data = fetch_ingredient(ingredient_id)

if ingredient_data:
    save_to_json(ingredient_data)
