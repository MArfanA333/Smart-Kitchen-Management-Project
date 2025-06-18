import firebase_admin
from firebase_admin import credentials, firestore
import random
import json
import re
from unidecode import unidecode
import pandas as pd

# Initialize Firebase
cred = credentials.Certificate("smartkitchen-sk-firebase-adminsdk-fbsvc-863c6d1b25.json")  # Replace with your path
firebase_admin.initialize_app(cred)
db = firestore.client()

# Default nutrition values for new ingredients
DEFAULT_NUTRITION = {
    "calories": 100,
    "carbohydrate": 10,
    "fat": 5,
    "fiber": 1,
    "protein": 5,
    "saturatedfat": 2,
    "sugar": 2,
    "cholesterol": 0,
    "sodium": 0
}

def singularize(word):
    """Convert plural words to singular (basic implementation)"""
    if not word:
        return word
        
    word = word.lower().strip()
    irregular_plurals = {
        'children': 'child',
        'people': 'person',
        'teeth': 'tooth',
        'geese': 'goose',
        'mice': 'mouse',
        'feet': 'foot'
    }
    
    if word in irregular_plurals:
        return irregular_plurals[word]
    
    if word.endswith('ies'):
        return word[:-3] + 'y'
    elif word.endswith('es'):
        return word[:-2]
    elif word.endswith('s'):
        return word[:-1]
    return word

def clean_ingredient_name(name):
    """Clean ingredient names for searching"""
    if pd.isna(name) or name == "NA":
        return ""
        
    # Remove anything in parentheses
    name = re.sub(r'\([^)]*\)', '', name)
    # Remove any measurements or special characters
    name = re.sub(r'[\d\/\-]+', '', name)
    # Remove common descriptors
    for prefix in ['fresh', 'dried', 'chopped', 'minced', 'grated', 'sliced', 'canned', 'whole', 'boneless', 'skinless']:
        if name.lower().startswith(prefix):
            name = name[len(prefix):].strip()
    # Convert to lowercase and remove plurals
    name = singularize(name.strip())
    return name

def find_or_create_ingredient(name):
    """Find ingredient in database or create a new one"""
    if pd.isna(name) or name == "NA":
        return None, None
        
    cleaned_name = clean_ingredient_name(name)
    if not cleaned_name:
        return None, None
    
    print(f"Searching for ingredient: {cleaned_name}")
    
    try:
        # Search for exact match first
        docs = db.collection('ingredients_list')\
                 .where('name_lower', '==', cleaned_name)\
                 .limit(1)\
                 .get()
        
        if docs:
            print(f"Found exact match: {cleaned_name}")
            return docs[0].to_dict(), docs[0].id
        
        # Search for partial match
        docs = db.collection('ingredients_list')\
                 .where('name_lower', '>=', cleaned_name)\
                 .where('name_lower', '<=', cleaned_name + '\uf8ff')\
                 .limit(1)\
                 .get()
        
        if docs:
            print(f"Found partial match: {cleaned_name} -> {docs[0].get('name')}")
            return docs[0].to_dict(), docs[0].id
        
        # If no match found, create new ingredient
        print(f"Creating new ingredient: {cleaned_name}")
        ingredient_data = {
            "name": name,
            "name_lower": cleaned_name,
            **DEFAULT_NUTRITION
        }
        
        # Add to Firebase
        doc_ref = db.collection('ingredients_list').document()
        doc_ref.set(ingredient_data)
        
        return ingredient_data, doc_ref.id
        
    except Exception as e:
        print(f"Error searching for ingredient {name}: {str(e)}")
        return None, None

def parse_r_list(r_string):
    """Parse R-style lists (c("item1", "item2")) into Python lists"""
    if pd.isna(r_string) or r_string == "character(0)":
        return []
    
    if not isinstance(r_string, str):
        return r_string if isinstance(r_string, list) else []
    
    if r_string.startswith('c('):
        # Remove c(" and trailing ")
        content = r_string[3:-2]
        # Split on ", " but handle escaped quotes
        items = [item.replace('\\"', '"') for item in content.split('", "')]
        return items
    else:
        return [r_string]

def parse_quantity(qty_str):
    """Parse quantity strings into numbers with detailed logging"""
    print(f"\nAttempting to parse quantity: {qty_str} (type: {type(qty_str)})")
    
    if pd.isna(qty_str) or qty_str in ["NA", "na", "None", None, ""]:
        print("Returning 0 (NA/None case)")
        return 0
    
    # Convert to string if it isn't already
    if not isinstance(qty_str, str):
        try:
            result = float(qty_str)
            print(f"Returning {result} (non-string numeric case)")
            return result
        except:
            print("Returning 0 (non-string numeric parse failed)")
            return 0
    
    qty_str = qty_str.strip()
    print(f"After strip: '{qty_str}'")
    
    # Handle mixed numbers like "1 1/2"
    if ' ' in qty_str and '/' in qty_str:
        print("Mixed number case")
        parts = qty_str.split(' ')
        whole_num = float(parts[0]) if parts[0] else 0
        fraction_part = parts[1]
        try:
            numerator, denominator = map(float, fraction_part.split('/'))
            result = whole_num + (numerator / denominator)
            print(f"Returning {result} (mixed number case)")
            return result
        except Exception as e:
            print(f"Mixed number parse failed: {str(e)}")
            return whole_num
    
    # Handle simple fractions
    if '/' in qty_str:
        print("Fraction case")
        try:
            numerator, denominator = map(float, qty_str.split('/'))
            result = numerator / denominator
            print(f"Returning {result} (fraction case)")
            return result
        except Exception as e:
            print(f"Fraction parse failed: {str(e)}")
            return 0
    
    # Handle ranges like "1-2"
    if '-' in qty_str and qty_str.count('-') == 1 and not qty_str.startswith('-'):
        print("Range case")
        try:
            low, high = map(float, qty_str.split('-'))
            result = (low + high) / 2  # Return average
            print(f"Returning {result} (range case)")
            return result
        except Exception as e:
            print(f"Range parse failed: {str(e)}")
    
    # Handle decimal numbers
    try:
        result = float(qty_str)
        print(f"Returning {result} (simple float case)")
        return result
    except ValueError as e:
        print(f"Float parse failed: {str(e)}")
        return 0

def process_ingredients(parts, quantities):
    """Process ingredients and quantities with detailed logging"""
    print("\nProcessing ingredients:")
    print(f"Parts: {parts}")
    print(f"Quantities: {quantities}")
    
    ingredient_data = []
    
    # Parse R-style lists
    parts_list = parse_r_list(parts)
    quantities_list = parse_r_list(quantities)
    
    print(f"\nParsed parts list: {parts_list}")
    print(f"Parsed quantities list: {quantities_list}")
    
    # Ensure we have lists of the same length
    min_length = min(len(parts_list), len(quantities_list))
    parts_list = parts_list[:min_length]
    quantities_list = quantities_list[:min_length]
    
    print(f"\nProcessing {min_length} ingredients:")
    for i, (part, qty_str) in enumerate(zip(parts_list, quantities_list)):
        print(f"\nIngredient {i+1}:")
        print(f"Part: {part}")
        print(f"Quantity string: {qty_str}")
        
        if pd.isna(part) or part == "NA":
            print("Skipping - part is NA")
            continue
            
        # Get quantity (multiply by random factor 10-20)
        qty = parse_quantity(qty_str)
        weight = qty * random.uniform(10, 20)
        print(f"Parsed quantity: {qty}")
        print(f"Calculated weight: {weight}")
        
        # Find or create ingredient
        ingredient, ingredient_id = find_or_create_ingredient(part)
        if not ingredient or not ingredient_id:
            print("Skipping - no ingredient found/created")
            continue
            
        ingredient_data.append({
            'id': ingredient_id,
            'name': ingredient['name'],
            'weight': weight,
            'nutrition': {
                'calories': ingredient.get('calories', 0),
                'carbohydrate': ingredient.get('carbohydrate', 0),
                'fat': ingredient.get('fat', 0),
                'fiber': ingredient.get('fiber', 0),
                'protein': ingredient.get('protein', 0),
                'saturatedfat': ingredient.get('saturatedfat', 0),
                'sugar': ingredient.get('sugar', 0),
                'cholesterol': ingredient.get('cholesterol', 0),
                'sodium': ingredient.get('sodium', 0),
            }
        })
        print(f"Added ingredient: {ingredient['name']} ({weight}g)")
    
    print(f"\nTotal ingredients processed: {len(ingredient_data)}")
    return ingredient_data

def clean_instructions(instructions):
    """Clean recipe instructions"""
    if pd.isna(instructions) or instructions == "character(0)":
        return ""
    
    instructions_list = parse_r_list(instructions)
    if isinstance(instructions_list, list):
        return '\n'.join(instructions_list)
    else:
        return str(instructions)

def clean_keywords(keywords):
    """Clean recipe keywords"""
    if pd.isna(keywords):
        return []
    
    keywords_list = parse_r_list(keywords)
    return [str(k).strip('"') for k in keywords_list if str(k).strip()]

def clean_image_url(image_str):
    """Clean image URL"""
    if pd.isna(image_str) or image_str == "character(0)":
        return None
    
    # Remove escaped quotes if present
    url = image_str.strip('"')
    # Remove any backslashes
    url = url.replace('\\', '')
    return url if url.startswith('http') else None

def calculate_nutrition(ingredient_data):
    """Calculate total nutrition from ingredients"""
    nutrition = {
        'Calories': 0,
        'ProteinContent': 0,
        'CarbohydrateContent': 0,
        'FatContent': 0,
        'SaturatedFatContent': 0,
        'CholesterolContent': 0,
        'SodiumContent': 0,
        'FiberContent': 0,
        'SugarContent': 0,
    }
    
    for ing in ingredient_data:
        factor = ing['weight'] / 100.0
        nut = ing['nutrition']
        
        nutrition['Calories'] += nut['calories'] * factor
        nutrition['ProteinContent'] += nut['protein'] * factor
        nutrition['CarbohydrateContent'] += nut['carbohydrate'] * factor
        nutrition['FatContent'] += nut['fat'] * factor
        nutrition['SaturatedFatContent'] += nut['saturatedfat'] * factor
        nutrition['CholesterolContent'] += nut['cholesterol'] * factor
        nutrition['SodiumContent'] += nut['sodium'] * factor
        nutrition['FiberContent'] += nut['fiber'] * factor
        nutrition['SugarContent'] += nut['sugar'] * factor
    
    return nutrition

def process_recipe(recipe):
    """Process a single recipe from the dataset with detailed logging"""
    try:
        print("\nStarting recipe processing...")
        
        # Clean up ingredient parts and quantities
        print("\nProcessing ingredients...")
        parts = recipe['RecipeIngredientParts']
        quantities = recipe['RecipeIngredientQuantities']
        
        ingredient_data = process_ingredients(parts, quantities)
        nutrition = calculate_nutrition(ingredient_data)
        
        # Clean other fields
        print("\nCleaning other fields...")
        instructions = clean_instructions(recipe['RecipeInstructions'])
        keywords = clean_keywords(recipe['Keywords'])
        image_url = clean_image_url(recipe['Images'])
        
        # Prepare the recipe document
        print("\nPreparing recipe document...")
        recipe_doc = {
            "Id": str(recipe['Id']),
            "Name": recipe['Name'],
            "CookTime": recipe['CookTime'] if not pd.isna(recipe['CookTime']) else "PT0M",
            "PrepTime": recipe['PrepTime'] if not pd.isna(recipe['PrepTime']) else "PT0M",
            "TotalTime": recipe['TotalTime'] if not pd.isna(recipe['TotalTime']) else "PT0M",
            "Images": [image_url] if image_url else [],
            "ExpiryDate": int(recipe['ExpiryDate']) if not pd.isna(recipe['ExpiryDate']) else 4,
            "RecipeCategory": recipe['RecipeCategory'] if not pd.isna(recipe['RecipeCategory']) else "Uncategorized",
            "Keywords": keywords,
            "RecipeIngredientQuantities": [ing['weight'] for ing in ingredient_data],
            "RecipeIngredientParts": [ing['name'] for ing in ingredient_data],
            "AggregatedRating": float(recipe['AggregatedRating']) if not pd.isna(recipe['AggregatedRating']) else 0,
            "ReviewCount": int(recipe['ReviewCount']) if not pd.isna(recipe['ReviewCount']) else 0,
            **nutrition,
            "RecipeServings": float(recipe['RecipeServings']) if not pd.isna(recipe['RecipeServings']) else 1,
            "RecipeYield": str(recipe['RecipeYield']) if not pd.isna(recipe['RecipeYield']) else "",
            "RecipeInstructions": instructions,
        }
        
        # Remove null values for certain fields
        for field in ['CholesterolContent', 'SodiumContent']:
            if recipe_doc[field] == 0:
                recipe_doc[field] = None
        
        print("\nRecipe processing complete!")
        return recipe_doc
        
    except Exception as e:
        print(f"\nError processing recipe: {str(e)}")
        import traceback
        traceback.print_exc()
        return None

def upload_recipes(dataset_path):
    """Process and upload recipes from dataset"""
    # Load dataset
    with open(dataset_path, 'r', encoding='utf-8') as f:
        recipes = json.load(f)
    
    # Process and upload each recipe
    for i, recipe in enumerate(recipes):
        try:
            print(f"\n{'='*50}")
            print(f"Processing recipe {i+1}/{len(recipes)}: {recipe['Name']}")
            print(f"{'='*50}")
            
            processed_recipe = process_recipe(recipe)
            
            if processed_recipe:
                # Upload to Firebase
                print("\nUploading to Firebase...")
                db.collection('recipes').document(str(recipe['Id'])).set(processed_recipe)
                print(f"\nSuccessfully uploaded: {recipe['Name']}")
            else:
                print(f"\nSkipped recipe due to processing errors: {recipe['Name']}")
                
        except Exception as e:
            print(f"\nError uploading recipe {recipe['Name']}: {str(e)}")
            import traceback
            traceback.print_exc()
            continue

if __name__ == "__main__":
    # Path to your recipe dataset JSON file
    dataset_path = "meals_trimmed_5.json"
    upload_recipes(dataset_path)