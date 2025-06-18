import firebase_admin
from firebase_admin import credentials, firestore
import datetime

# Initialize Firebase
cred = credentials.Certificate("smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

def parse_file(file_path):
    """Reads and parses the text file into structured data for either locations or items."""
    with open(file_path, "r") as file:
        lines = [line.strip() for line in file.readlines() if line.strip()]

    if len(lines) < 2 or not lines[0].startswith("UserId:"):
        print("Error: File must start with 'UserId: {userId}' and specify the type on the second line.")
        return None, None, None

    user_id = lines[0].split(": ")[1]  # Extract userId
    file_type = lines[1].strip().lower()  # Determine whether the file is for locations or items

    if file_type == "location":
        return user_id, file_type, parse_location_data(lines[2:])  # Process location data
    elif file_type == "item":
        return user_id, file_type, parse_item_data(lines[2:])  # Process item data
    else:
        print("Error: Second line must be either 'location' or 'item'.")
        return None, None, None

def parse_location_data(lines):
    """Parses location details."""
    if len(lines) < 7:
        print("Invalid location data format.")
        return None

    return {
        "locationId": lines[0].split(": ")[1],
        "name": lines[1].split(": ")[1],
        "motionDetection": lines[2].split(": ")[1].lower() == "true",
        "temperature": float(lines[3].split(": ")[1]),
        "humidity": float(lines[4].split(": ")[1]),
        "alcohol_level": float(lines[5].split(": ")[1]),
        "category": lines[6].split(": ")[1].lower(),
        "weight": float(lines[7].split(": ")[1])  # Ensure weight is updated
    }

def parse_item_data(lines):
    """Parses item details."""
    if len(lines) < 5:
        print("Invalid item data format.")
        return None

    item_data = {
        "itemId": lines[0].split(": ")[1],
        "name": lines[1].split(": ")[1],
        "locationId": lines[2].split(": ")[1],
        "weight": float(lines[3].split(": ")[1])
    }

    # Check if date_added should be updated
    if len(lines) > 4 and lines[4].startswith("added:"):
        item_data["added"] = lines[4].split(": ")[1].lower() == "true"

    return item_data

def update_firebase(file_path):
    """Parses the file and updates Firebase based on the file type."""
    user_id, file_type, data = parse_file(file_path)

    if not user_id or not data:
        print("Error: No valid data found.")
        return

    if file_type == "location":
        # Update location data
        location_ref = db.collection("users").document(user_id).collection("locations").document(data["locationId"])
        location_ref.set(data, merge=True)
        print(f"Updated location: {data['name']} for User {user_id}")

    elif file_type == "item":
        # Update item data
        item_id_with_location = f"{data['itemId']}_{data['locationId']}"
        item_ref = db.collection("users").document(user_id).collection("inventory").document(item_id_with_location)

        item_update = {
            "name": data["name"],
            "weight": data["weight"]
        }

        # Update date_added if needed
        if "added" in data and data["added"]:
            item_update["date_added"] = datetime.datetime.utcnow()

        item_ref.set(item_update, merge=True)
        print(f"Updated item: {data['name']} in location {data['locationId']} for User {user_id}")

    print("Firebase update complete!")


if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python update_firebase.py <file_path>")
    else:
        update_firebase(sys.argv[1])
