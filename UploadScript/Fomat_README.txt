## HOW TO RUN:

Run the controller.py python file, and input the file path of what you want to update (EG: item_update.txt). You will need to convery this controller.py to whatever the raspberrypi can run,
while generating the textfile and passing it to the update_firebase.py script.

Dont Arbitrarily change values right now, only change weight values or temperature and humidity values

FILE HAS BEEN TESTED AND IT WORKS (Do not worry about the functionality)
You can not check whether any values are updated without the app or access to the firebase account. So just work on making the raspberrypi to run the script.

## NOTE

- The motion detection has not been implemented yet (Its 3:45am and I want to sleep, so ill do it later lol)
- file does not exactly check for incorrect values to be updated, so we need to make sure the RPI generates the correct values.
- Each RPI (which represents a unique user) should store the user's ID, a list of the locations it has and its corresponding ids and name. This will help generate the update files later. 
- Need to work out how item Ids will work, currectly just arbitrary.
- Need to work on a initialization script (adding the locations which are on the RPI to the database if it doesnt exist etc.). Runs only during setup, or when new location is added.
- Kill me Please..

## IMPORTANT:
RUN THE BELOW COMMAND TO RUN THE IMPORT COMMANDS:

pip install firebase_admin

X----------------------------------------------------------------------X

## Format for location update textfile:


UserId: {userId}
location
LocationId: {locationId}
Name: {locationName}
MotionDetection: {true/false}
Temperature: {temperature_value}
Humidity: {humidity_value}
AlcoholLevel: {alcohol_level_value}
Category: {category}
Weight: {weight_value}


X----------------------------------------------------------------------X

## Format for item update textfile:


UserId: {userId}
item
ItemId: {itemId}
Name: {itemName}
LocationId: {locationId}
Weight: {weight_value}
Added: {true/false}  (Optional; if true, updates 'date_added')

X----------------------------------------------------------------------X