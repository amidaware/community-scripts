#!/usr/bin/python3
#public

"""
.TITLE
    Tactical RMM Script Sync with GIT Integration


.DESCRIPTION
    This script was made to add some form of support to Tactical RMM for GIT sync of scripts and other code-based tools. 
    It is recommended to run this script regularly to keep everything updated, ideally at least once every hour.
    Each part can be toggled with its own flag to help troubleshoot any issue.
    The flags only prevent anything from being written to files or API; any possible outcome will still be displayed on the terminal.

    No script created on git side will be created in TRMM as they will be missing an id in the database and the json that goes with it
    While possible no support to auto-create scripts in TRMM is planned as of now

.WORKFLOW
    0. The mapped folder should already be configured with git

    1. Pull all the modifications from the git repo configured for the folder via git commands
        Any modification that would have been done on TRMM and git that would conflit will be overwriten by the GIT in priority.

    2. Check for diff between the json and scripts; if there is a diff, write back to the API the changes.

    3. Exports scripts out to 4 folders:
        scripts: extracted script code from the API converted from json
        scriptsraw: All json data from the API for later processing, currently used for hash comparison
        snippets: extracted snippet code from the API converted from json
        snippetsraw: All json data for later import/migration

    4. Push all the modifications to the git repo configured for the folder via git commands
        If there are no changes, no commit will be made.

.EXEMPLE
DOMAIN=https://api-rmm
API_TOKEN={{global.rmm_key_for_git_script}}
SCRIPTPATH=/var/RMM-script-repo

.CHANGELOG
    v5.0 Y Exports functional, adds script ID to from as "id - " 
    v5.a Y "id - " for only raw folder. Fixed to use X-API-KEY
    v5.1 Y Sanitizing script names when has / in it
    v5.2 Y moving url and api token to .env file
    v5.3 Y Making script folders be subfolders of where export.py file is
    v5.4 Y making filenames utf-8 compliant
    v5.5 7/11/2024 X Save PowerShell scripts with .ps1 and Python scripts with .py extensions
    v5.6 7/11/2024 X Count the total number of scripts and print at the end
    v5.7 7/11/2024 X Print a summary of all the different types of shells exported
    v5.8 7/11/2024 X Add support for additional shell extension types
    v5.9 7/11/2024 X Detect deleted scripts and delete them from both folders
    v6 7/31/2024 SAN Add support for specifying the save folder via the SCRIPTPATH environment variable
    v6.0.1 7/31/2024 SAN Add Git integration to push changes to the configured Git repository
    v6.1 06/08/24 SAN add support for snippets
    v6.1.1 06/08/24 SAN renamed scriptraw folder
    v6.2 14/08/24 SAN Converted categories to folders
    v6.2.1 14/08/24 SAN added a cleanup of old scripts
    v6.2.2 14/08/24 SAN code cleanup and bug fixes
    v9.0.0.1 16/08/24 SAN Added support for git pull for scripts
    v9.0.0.2 16/08/24 SAN bug fixes and corrected some logic errors 
    v9.0.0.3 16/08/24 SAN bug fixe on huge payloads
    v9.0.0.4 16/08/24 SAN bug fixe on huge payloads


.TODO
    Add reporting support
    add writeback for snippets
    simplify the functions that does the writeback
    Move raws from "scriptsraw" to scripts/subfolder/raws/ to group them with their scripts 
    add debug statements and debug flags
    find edge-cases and add exit code for them
    add logging
    add counters and separators at the end of each function
    investigate if the lines returns in the code causes issues in some case (theoretical issue)
    send workflow flags to ENV default to true
    make the commit message to be dynamic ex. "modified xxx.ps1, xxx.py"
    
"""

import subprocess
import sys
import os
import hashlib
import json
from collections import defaultdict
from pathlib import Path
import requests
from pathvalidate import sanitize_filename
import re

# Toggle flags
ENABLE_GIT_PULL = True
ENABLE_GIT_PUSH = True
ENABLE_WRITEBACK = True
ENABLE_WRITETOFILE = True

def delete_obsolete_files(folder, current_scripts):
    print(f"Deleting obsolete files and directories in {folder}...")
    all_files = set()
    relevant_dirs = set()

    for item in folder.rglob('*'):
        if item.is_file():
            all_files.add(item.relative_to(folder))
        elif item.is_dir() and any(item.glob('*')):
            relevant_dirs.add(item.relative_to(folder))

    obsolete_files = all_files - current_scripts
    for item in folder.rglob('*'):
        if item.is_file() and item.relative_to(folder) in obsolete_files:
            try:
                print(f"Deleting obsolete file: {item}")
                item.unlink()
            except Exception as e:
                print(f"Error deleting file {item}: {e}")

    for dirpath in sorted(folder.rglob('*'), key=lambda p: len(p.parts), reverse=True):
        if dirpath.is_dir() and not any(dirpath.glob('*')) and dirpath.relative_to(folder) not in relevant_dirs:
            try:
                dirpath.rmdir()
                print(f"Deleting empty obsolete directory: {dirpath}")
            except OSError as e:
                print(f"Could not delete directory {dirpath}: {e}")

def process_scripts(scripts, script_folder, script_raw_folder, shell_summary, is_snippet=False):
    print(f"Processing {'snippets' if is_snippet else 'user-defined scripts'}...")
    current_scripts = set()

    for script in scripts:
        script_id = script.get('id')
        script_name = sanitize_filename(script.get('name', 'Unnamed Script'))
        category = script.get('category', '').strip() if script.get('category') else ''
        category = sanitize_filename(category)
        category_folder = script_folder / category if category else script_folder
        category_raw_folder = script_raw_folder / category if category else script_raw_folder

        category_folder.mkdir(parents=True, exist_ok=True)
        category_raw_folder.mkdir(parents=True, exist_ok=True)

        if not is_snippet:
            download_url = f"{domain}/scripts/{script_id}/download/?with_snippets=false"
            script_data = fetch_data(download_url, headers)
        else:
            script_data = script

        if script_data:
            code = script_data.get('code')
            shell = script.get('shell')
            extension = {
                'powershell': '.ps1',
                'python': '.py',
                'cmd': '.bat',
                'shell': '.sh',
                'nushell': '.nu'
            }.get(shell, '.txt')

            if not is_snippet:
                shell_summary[shell] += 1

            script_filename = f"{script_name}{extension}"
            script_file_path = category_folder / script_filename
            save_file(script_file_path, code)
            
            raw_filename = f"{script_id} - {script_name}.json"
            raw_file_path = category_raw_folder / raw_filename
            save_file(raw_file_path, {**script_data, **script}, is_json=True)

            current_scripts.add(script_file_path.relative_to(script_folder))
            current_scripts.add(raw_file_path.relative_to(script_raw_folder))

    print(f"Processed {len(current_scripts)} {'snippets' if is_snippet else 'scripts'}.")
    return current_scripts


def compute_hash(file_path):
    """Compute SHA-256 hash of a file."""
    hash_sha256 = hashlib.sha256()
    try:
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_sha256.update(chunk)
    except FileNotFoundError:
        return None
    return hash_sha256.hexdigest()

def save_file(path, content, is_json=False):
    """Save the file unconditionally."""
    new_content = json.dumps(content, indent=4, ensure_ascii=False) if is_json else content

    if ENABLE_WRITETOFILE:
        with open(path, 'w', encoding="utf-8") as file:
            file.write(new_content)
        print(f"File saved: {path}")
    else:
        print(f"File would be saved (simulation): {path}")


def fetch_data(url, headers):
    print(f"Fetching data from {url}...")
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        print(f"Data fetched successfully from {url}.")
        return response.json()
    else:
        print(f"Error fetching data from {url}: {response.status_code}")
        return []


def compare_script_and_json(folders):
    """Compare script files with their corresponding JSON files and return mismatches."""
    print("Comparing script files with JSON files...")

    mismatches = []
    existing_files = defaultdict(dict)

    for raw_file_path in folders['scriptsraw'].rglob('*.json'):
        raw_filename = raw_file_path.stem  # Get the filename without extension
        raw_name_cleaned = re.sub(r'^\d+ - ', '', raw_filename).lower()  # Clean filename

        matched_script_path = None
        for script_file_path in folders['scripts'].rglob('*'):
            if script_file_path.is_file():
                script_filename = script_file_path.stem.lower()
                if script_filename == raw_name_cleaned:
                    matched_script_path = script_file_path
                    break

        if matched_script_path:
            print(f"Matched script file: {matched_script_path} with raw file: {raw_file_path}")

            script_hash = compute_hash(matched_script_path)

            with open(raw_file_path, 'r', encoding='utf-8') as json_file:
                raw_data = json.load(json_file)
                json_script_content = raw_data.get('code', '')

            # Compare the hashes of the actual script content
            json_script_hash = hashlib.sha256(json_script_content.encode('utf-8')).hexdigest()

            print(f"Script file hash: {script_hash}")
            print(f"JSON 'code' field hash: {json_script_hash}")

            if script_hash != json_script_hash:
                print("\n--- Script File Content (first 10 lines) ---")
                with open(matched_script_path, 'r', encoding='utf-8') as script_file:
                    for i, line in enumerate(script_file):
                        if i < 10:
                            print(line.strip())
                        else:
                            break

                print("\n--- JSON 'Code' Field Content (first 10 lines) ---")
                json_lines = json_script_content.splitlines()
                for i, line in enumerate(json_lines):
                    if i < 10:
                        print(line.strip())
                    else:
                        break

                mismatches.append({
                    'script_path': matched_script_path,
                    'raw_path': raw_file_path,
                    'script_hash': script_hash,
                    'json_script_hash': json_script_hash
                })

            existing_files[matched_script_path.relative_to(folders['scripts'])] = {
                'script_path': matched_script_path,
                'raw_path': raw_file_path,
                'script_hash': script_hash,
                'json_script_hash': json_script_hash
            }
        else:
            print(f"No matching script file found for JSON: {raw_file_path}")

    return mismatches

def write_modifications_to_api(base_dir, folders, api_token):
    """Main function to compare files and send data to the API."""
    mismatches = compare_script_and_json(folders)
    send_mismatched_data_to_api(mismatches, api_token)


def update_api(script_id, payload, api_token):
    # Convert 'code' to 'script_body'
    if 'code' in payload:
        payload['script_body'] = payload.pop('code')

    url = f"{domain}/scripts/{script_id}/"
    headers = {
        'X-API-KEY': api_token,
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*'
    }

    # Log the script body length and truncated content
    script_body_length = len(payload.get('script_body', ''))
    truncated_body = (payload['script_body'][:1000] + '...') if script_body_length > 1000 else payload['script_body']
    print(f"Updating script {script_id}, length: {script_body_length}, payload: {json.dumps({**payload, 'script_body': truncated_body}, indent=2)}")

    # Make the request with a longer timeout
    try:
        response = requests.put(url, headers=headers, json=payload, timeout=120)
    except requests.exceptions.RequestException as e:
        print(f"Request failed: {e}")
        return

    # Print response for debugging
    print(f"Response status code: {response.status_code}, Response content: {response.text}")

    # Check response status
    if response.status_code == 200:
        print(f"Script {script_id} updated successfully.")
    elif response.status_code == 401:
        print(f"Failed to update script {script_id}: 401 Unauthorized. Check API token.")
    elif response.status_code == 404:
        print(f"Failed to update script {script_id}: 404 Not Found. The resource may not exist.")
    else:
        print(f"Failed to update script {script_id}: {response.status_code} {response.text}")




def send_mismatched_data_to_api(mismatches, api_token):
    """Send mismatched script data to the API."""
    for mismatch in mismatches:
        script_path = mismatch.get('script_path')
        raw_path = mismatch.get('raw_path')

        with open(raw_path, 'r', encoding='utf-8') as f:
            raw_data = json.load(f)

        updated_payload = {**raw_data, 'code': open(script_path, 'r').read()}

        # Convert 'code' to 'script_body' before updating the API
        try:
            if ENABLE_WRITEBACK:
                print(f"Updating API with payload for {script_path}:")
                # Call the update function with api_token
                update_api(raw_data.get('id'), updated_payload, api_token)
            else:
                print(f"Payload that would be pushed for {script_path}:")
                # Preview the payload with 'script_body' instead of 'code'
                updated_payload['script_body'] = updated_payload.pop('code')
                print(json.dumps(updated_payload, indent=4))
                sys.stdout.flush()  # Explicitly flush stdout
        except BrokenPipeError:
            sys.stderr.close()
            sys.stdout.close()


def git_pull(base_dir):
    """Force pull the latest changes from the git repository, discarding local changes."""
    if ENABLE_GIT_PULL:
        print("Starting force pull...")
        try:
            subprocess.check_call(['git', '-C', base_dir, 'fetch', 'origin'])
            subprocess.check_call(['git', '-C', base_dir, 'reset', '--hard', 'origin/master'])
            print("Successfully force-pulled the latest changes from the repository.")
        except subprocess.CalledProcessError as e:
            print(f"Failed to force-pull changes from Git: {e}")
            sys.exit(1)
    else:
        print("Git pull is disabled.")


def git_push(base_dir):
    """Push local changes to the git repository."""
    if ENABLE_GIT_PUSH:
        print("Starting git push...")
        try:
            rebase_in_progress = subprocess.run(['git', '-C', base_dir, 'rebase', '--show-current-patch'],
                                                capture_output=True, text=True).returncode == 0
            if rebase_in_progress:
                print("Rebase in progress. Please complete or abort the rebase manually.")
                sys.exit(1)

            branch_result = subprocess.run(['git', '-C', base_dir, 'rev-parse', '--abbrev-ref', 'HEAD'],
                                           capture_output=True, text=True)
            branch_name = branch_result.stdout.strip()

            if branch_name == 'HEAD':
                branch_name = "update-scripts"
                subprocess.check_call(['git', '-C', base_dir, 'checkout', '-b', branch_name])
                print(f"Switched to new branch '{branch_name}'")

            status_result = subprocess.run(['git', '-C', base_dir, 'status', '--porcelain'],
                                           capture_output=True, text=True)
            if status_result.stdout:
                subprocess.check_call(['git', '-C', base_dir, 'add', '.'])
                subprocess.check_call(['git', '-C', base_dir, 'commit', '-m', 'Update scripts and raw data'])
                print(f"Committed changes to branch '{branch_name}'")
            else:
                print("No changes to commit.")

            subprocess.check_call(['git', '-C', base_dir, 'push', 'origin', branch_name])
            print(f"Changes pushed to branch '{branch_name}'")
        except subprocess.CalledProcessError as e:
            print(f"Git operation failed: {e}")
    else:
        print("Git push is disabled.")

def download_scripts():
    global domain, headers

    domain = os.getenv('DOMAIN')
    api_token = os.getenv('API_TOKEN')
    scriptpath = os.getenv('SCRIPTPATH')

    if not domain or not api_token or not scriptpath:
        print("Error: DOMAIN, API_TOKEN, and SCRIPTPATH must be set in the environment.")
        sys.exit(1)

    headers = {"X-API-KEY": api_token}
    base_dir = Path(scriptpath).resolve()
    folders = {
        "scripts": base_dir / "scripts",
        "scriptsraw": base_dir / "scriptsraw",
        "snippets": base_dir / "snippets",
        "snippetsraw": base_dir / "snippetsraw"
    }
    for folder in folders.values():
        folder.mkdir(parents=True, exist_ok=True)

    shell_summary = defaultdict(int)
    current_scripts = set()

    if ENABLE_GIT_PULL:
        git_pull(base_dir)

    write_modifications_to_api(base_dir, folders, api_token)

    print("Fetching user-defined scripts...")
    user_defined_scripts = fetch_data(f"{domain}/scripts/?showHiddenScripts=true", headers)
    user_defined_scripts = [item for item in user_defined_scripts if item.get('script_type') == 'userdefined']
    current_scripts.update(process_scripts(user_defined_scripts, folders['scripts'], folders['scriptsraw'], shell_summary))

    print("Fetching snippets...")
    snippets = fetch_data(f"{domain}/scripts/snippets/", headers)
    current_scripts.update(process_scripts(snippets, folders['snippets'], folders['snippetsraw'], shell_summary, is_snippet=True))

    for folder in folders.values():
        delete_obsolete_files(folder, current_scripts)

    if ENABLE_GIT_PUSH:
        git_push(base_dir)

    print(f"Total number of scripts exported: {len(current_scripts)}")
    print("Shell summary:")
    for shell, count in shell_summary.items():
        print(f"{shell}: {count}")



if __name__ == "__main__":
    download_scripts()