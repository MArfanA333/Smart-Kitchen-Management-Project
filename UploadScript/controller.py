import subprocess

def run_script(file_path):
    """Runs the update_firebase script with the given file."""
    try:
        subprocess.run(["python", "update_firebase.py", file_path], check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error running script: {e}")

if __name__ == "__main__":
    file_path = input("Enter the path to the data file: ")
    run_script(file_path)
