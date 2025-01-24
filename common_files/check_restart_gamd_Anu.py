import os

def search_in_file(file_path, search_term):
    """
    Searches for a term in a file and returns True if found, otherwise False.
    """
    try:
        with open(file_path, 'r') as file:
            for line in file:
                if search_term in line:
                    return True
    except (UnicodeDecodeError, FileNotFoundError):
        pass  # Handle files that cannot be read
    return False

def find_files_using_term(directory, search_term):
    """
    Recursively searches for Python files that contain a specific term.
    """
    matching_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.py'):
                file_path = os.path.join(root, file)
                if search_in_file(file_path, search_term):
                    matching_files.append(file_path)
    return matching_files

if __name__ == "__main__":
    # Directory to start the search
    directory_to_search = "/home/anugraha/gamd_OpenMM_test5/gamd-openmm/gamd/"
    term_to_search = "DEB"

    print(f"Searching for files containing '{term_to_search}' in '{directory_to_search}'...")
    result_files = find_files_using_term(directory_to_search, term_to_search)

    if result_files:
        print("\nFound the term in the following files:")
        for result_file in result_files:
            print(result_file)
    else:
        print("\nNo files found containing the specified term.")
