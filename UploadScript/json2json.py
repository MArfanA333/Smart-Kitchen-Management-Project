import json
import random
import re

def parse_r_list(r_string):
    """Parses R-style c(...) strings into a Python list."""
    if isinstance(r_string, str) and r_string.startswith("c("):
        items = re.findall(r'"(.*?)"', r_string)
        return items
    return []

def clean_image_string(image_str):
    """Cleans the Images field from escaped quotes."""
    if image_str and isinstance(image_str, str):
        image_str = image_str.strip().strip('"')
        return [image_str] if image_str else []
    return []

def convert_recipe_data(raw_data):
    transformed = []

    for recipe in raw_data:
        ingredients = []
        quantities = parse_r_list(recipe.get("RecipeIngredientQuantities", ""))
        parts = parse_r_list(recipe.get("RecipeIngredientParts", ""))

        for qty, part in zip(quantities, parts):
            try:
                quantity = float(eval(qty))
            except:
                quantity = 1  # fallback if invalid
            weight = round(quantity * random.uniform(10, 20), 2)
            ingredients.append({
                "name": part.strip(),
                "weight": weight
            })

        raw_instructions = recipe.get("RecipeInstructions", "")
        instructions = " ".join(parse_r_list(raw_instructions))

        transformed.append({
            "name": recipe.get("Name", "Unknown Recipe"),
            "prepTime": recipe.get("PrepTime", ""),
            "cookTime": recipe.get("CookTime", ""),
            "expiryDate": recipe.get("ExpiryDate", 4),
            "category": recipe.get("RecipeCategory", "Other"),
            "keywords": parse_r_list(recipe.get("Keywords", "")),
            "servings": str(recipe.get("RecipeServings", "") or "1"),
            "yield": recipe.get("RecipeYield", "") or "",
            "instructions": instructions,
            "ingredients": ingredients,
            "images": clean_image_string(recipe.get("Images", "")),
            "aggregatedRating": recipe.get("AggregatedRating", 0),
            "reviewCount": recipe.get("ReviewCount", 0),
            "calories": recipe.get("Calories", 0),
            "proteinContent": recipe.get("ProteinContent", 0),
            "carbohydrateContent": recipe.get("CarbohydrateContent", 0),
            "fatContent": recipe.get("FatContent", 0),
            "saturatedFatContent": recipe.get("SaturatedFatContent", 0),
            "cholesterolContent": recipe.get("CholesterolContent", 0),
            "sodiumContent": recipe.get("SodiumContent", 0),
            "fiberContent": recipe.get("FiberContent", 0),
            "sugarContent": recipe.get("SugarContent", 0)
        })

    return transformed

# Usage
with open('meals_trimmed.json', 'r') as f:
    raw_data = json.load(f)

cleaned_data = convert_recipe_data(raw_data)

with open('cleaned_recipes.json', 'w') as f:
    json.dump(cleaned_data, f, indent=2)

print("✅ Data cleaning complete — full fields included!")
