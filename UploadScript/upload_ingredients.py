import firebase_admin
from firebase_admin import credentials, firestore


# Initialize Firebase Admin with your service account key
cred = credentials.Certificate("smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json")
firebase_admin.initialize_app(cred)
from tqdm import tqdm

db = firestore.client()

def update_name_lower(batch_size=300):
    ingredients_ref = db.collection('ingredients_list')
    last_doc = None
    total_updated = 0

    while True:
        query = ingredients_ref.limit(batch_size)

        if last_doc:
            query = query.start_after(last_doc)

        docs = query.stream()
        docs_list = list(docs)

        if not docs_list:
            break

        for doc in tqdm(docs_list):
            data = doc.to_dict()
            if data and 'name' in data:
                lower_name = data['name'].lower()
                ingredients_ref.document(doc.id).update({'name_lower': lower_name})
                total_updated += 1

        last_doc = docs_list[-1]

    print(f"All done! Total updated: {total_updated}")

if __name__ == "__main__":
    update_name_lower()
