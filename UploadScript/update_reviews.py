import json
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase Admin
cred = credentials.Certificate('smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Load reviews from JSON file
INPUT_FILE = 'filtered_reviews.json'
FAILED_FILE = 'failed_reviews.json'

with open(INPUT_FILE, 'r') as f:
    reviews = json.load(f)

total = len(reviews)
failed_reviews = []

for index, review in enumerate(reviews, 1):
    try:
        recipe_name = review['Name']

        # Look up the recipe by name
        recipe_docs = db.collection('recipes').where('Name', '==', recipe_name).limit(1).stream()
        recipe_doc_list = list(recipe_docs)

        if not recipe_doc_list:
            print(f"[{index}/{total}] ❌ Recipe not found: '{recipe_name}'")
            failed_reviews.append(review)
            continue

        recipe_doc = recipe_doc_list[0]
        recipe_id = recipe_doc.id
        recipe_ref = db.collection('recipes').document(recipe_id)

        # Parse dates
        submitted = datetime.fromisoformat(review['DateSubmitted'].replace('Z', '+00:00'))
        modified = datetime.fromisoformat(review['DateModified'].replace('Z', '+00:00'))

        # Build review data without ID fields
        review_data = {
            'AuthorName': review['AuthorName'],
            'Rating': float(review['Rating']),
            'Review': review['Review'],
            'DateSubmitted': submitted,
            'DateModified': modified
        }

        # Use AuthorId as document ID
        review_doc_id = str(review['AuthorId'])

        # Upload to Firestore
        recipe_ref.collection('reviews').document(review_doc_id).set(review_data)
        print(f"[{index}/{total}] ✅ Uploaded review by Author {review_doc_id} for '{recipe_name}'")

    except Exception as e:
        print(f"[{index}/{total}] 🔥 Error for review '{review.get('Name')}' by {review.get('AuthorId')}: {e}")
        failed_reviews.append(review)

# Save failed reviews to retry later
if failed_reviews:
    with open(FAILED_FILE, 'w') as f:
        json.dump(failed_reviews, f, indent=2)
    print(f"\n⚠️ {len(failed_reviews)} reviews failed. Saved to {FAILED_FILE}")

print(f"\n🎉 Upload complete. {total - len(failed_reviews)} reviews uploaded successfully.")
