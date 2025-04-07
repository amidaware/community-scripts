#!/usr/bin/python3
"""
.TITLE
    Tactical RMM Script Sync with GIT Integration


.DESCRIPTION
    This script was made to add some form of support to Tactical RMM for GIT sync of scripts and other code-based tools. 
    It is recommended to run this script regularly to keep everything updated, ideally at least once every hour.
    The flags only prevent anything from being written to files or API; any possible outcome will still be displayed on the terminal.

    No script created on git side will be created in TRMM as they will be missing an id in the database and the json that goes with it
    While possible no support to auto-create scripts in TRMM is planned as of now as this would also require to plan for multi-instance cases.

    This script can be executed on any device including the TRMM server itself as the only requirements are git + access to the API.

.WORKFLOW
    0. The mapped folder should already be configured with git

    1. Pull all the modifications from the git repo pre-configured for the folder via git commands
        Any modification that would have been done on TRMM and git that would conflit will be overwriten by the GIT in priority.

    2. Check for diff between the json and scripts; if there is a diff, write back to the API the changes.

    3. Exports scripts out to 4 folders:
        scripts: extracted script code from the API converted from json
        scriptsraw: All json data from the API for later processing, currently used for hash comparison
        snippets: extracted snippet code from the API converted from json
        snippetsraw: All json data for later import/migration

    4. Push all the modifications to the git repo pre-configured for the folder via git commands
        If there are no changes, no commit will be made.

.EXEMPLE
    DOMAIN=https://api-rmm
    DOMAIN=https://{{global.RMM_API_URL}}
    API_TOKEN={{global.rmm_key_for_git_script}}
    API_TOKEN=asdf1234
    SCRIPTPATH=/var/RMM-script-repo

.NOTES
    #public
    Original source not disclosed
    
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
    v9.0.1.0 02/04/25 SAN Added dynamic commit messages
    v9.0.1.0 02/04/25 SAN bug fix on commit messages
    v9.0.1.1 07/04/25 SAN lots of code optimisation
    v9.0.2.0 07/04/25 SAN Added support for snippets writeback, added counters and separators
    v9.0.2.1 07/04/25 SAN small optimisations & added a var for changing the branch
    v9.0.2.2 07/04/25 SAN better handeling of custom git setup


.TODO
    Add reporting support
    Move raws from "scriptsraw" to scripts/subfolder/raws/ to group them with their scripts
    add logging
    send workflow flags to ENV default to true
    Delete script support from git (dedicated function required as the current delete_obsolete_files only work based on api)
    Review flow of step 3 for optimisations
    move all big var to global and ensure they are used from global only.

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

# Can be changed to "main" or other if needed.
git_pull_branch = 'master'

def delete_obsolete_files(folder, current_scripts):
    print(f"Cleaning {folder}...")
    obsolete = {f for f in folder.rglob('*') if f.is_file() and f.relative_to(folder) not in current_scripts}
    for f in obsolete:
        try: f.unlink(); print(f"Deleted: {f}")
        except Exception as e: print(f"Error deleting {f}: {e}")

    for d in sorted(folder.rglob('*'), key=lambda p: -len(p.parts)):
        if d.is_dir() and not any(d.iterdir()):
            try: d.rmdir(); print(f"Removed empty dir: {d}")
            except Exception as e: print(f"Could not delete dir {d}: {e}")


def process_scripts(scripts, script_folder, script_raw_folder, shell_summary, is_snippet=False):
    print(f"Processing {'snippets' if is_snippet else 'scripts'}...")
    current = set()

    for s in scripts:
        sid = s.get('id')
        name = sanitize_filename(s.get('name', 'Unnamed Script'))
        cat = sanitize_filename(s.get('category', '').strip()) if s.get('category') else ''
        folder = script_folder / cat if cat else script_folder
        raw_folder = script_raw_folder / cat if cat else script_raw_folder
        folder.mkdir(parents=True, exist_ok=True)
        raw_folder.mkdir(parents=True, exist_ok=True)

        data = s if is_snippet else fetch_data(f"{domain}/scripts/{sid}/download/?with_snippets=false", headers)
        if not data: continue

        code = data.get('code')
        shell = s.get('shell')
        ext = {'powershell': '.ps1', 'python': '.py', 'cmd': '.bat', 'shell': '.sh', 'nushell': '.nu'}.get(shell, '.txt')
        if not is_snippet: shell_summary[shell] += 1

        fname = f"{name}{ext}"
        save_file(folder / fname, code)
        raw_name = f"{sid} - {name}.json"
        save_file(raw_folder / raw_name, {**data, **s}, is_json=True)

        current.add((folder / fname).relative_to(script_folder))
        current.add((raw_folder / raw_name).relative_to(script_raw_folder))

    print(f"Processed {len(current)} {'snippets' if is_snippet else 'scripts'}.")
    return current

def compute_hash(file_path):
    try:
        with open(file_path, 'rb') as f:
            return hashlib.sha256(f.read()).hexdigest()
    except FileNotFoundError:
        return None

def save_file(path, content, is_json=False):
    data = json.dumps(content, indent=4, ensure_ascii=False) if is_json else content
    if ENABLE_WRITETOFILE:
        path.write_text(data, encoding="utf-8")
        print(f"File saved: {path}")
    else:
        print(f"File would be saved (simulation): {path}")

def fetch_data(url, headers):
    print(f"Fetching: {url}")
    r = requests.get(url, headers=headers)
    if r.ok:
        print("Success.")
        return r.json()
    print(f"Error {r.status_code}")
    return []

def write_modifications_to_api(base_dir, folders, api_token):
    """Compare local script files and JSON definitions, then push mismatches to the API."""
    print("Comparing script files with JSON files...")
    mismatches = []
    
    total_files_checked = 0
    total_matches = 0
    total_mismatches = 0
    total_updated = 0
    total_skipped = 0

    for folder_key, folder in folders.items():
        is_snippet = folder_key == 'snippetsraw'
        folder_name = 'snippets' if is_snippet else 'scripts'
        
        for raw_path in folder.rglob('*.json'):
            total_files_checked += 1
            raw_name = re.sub(r'^\d+ - ', '', raw_path.stem).lower()
            match = next((p for p in folders[folder_name].rglob('*') 
                          if p.is_file() and p.stem.lower() == raw_name), None)

            if not match:
                print(f"No match for {'snippet' if is_snippet else 'script'}: {raw_path}")
                total_skipped += 1
                continue

            print(f"Matched {'snippet' if is_snippet else 'script'}: {match} <-> {raw_path}")
            total_matches += 1
            file_hash = compute_hash(match)

            with raw_path.open(encoding='utf-8') as f:
                raw_data = json.load(f)
            code = raw_data.get('code', '')
            code_hash = hashlib.sha256(code.encode('utf-8')).hexdigest()

            print(f"{'Snippet' if is_snippet else 'Script'} hash: {file_hash}\nJSON hash:   {code_hash}")

            if file_hash != code_hash:
                total_mismatches += 1
                print(f"\n--- {'Snippet' if is_snippet else 'Script'} (first 10 lines) ---")
                with match.open(encoding='utf-8') as f:
                    for i, line in enumerate(f):
                        if i >= 10: break
                        print(line.strip())

                print(f"\n--- JSON Code (first 10 lines) ---")
                for line in code.splitlines()[:10]:
                    print(line.strip())

                with match.open(encoding='utf-8') as f:
                    updated_payload = {**raw_data, 'code': f.read()}

                try:
                    if ENABLE_WRITEBACK:
                        print(f"Updating API for {'snippet' if is_snippet else 'script'} {match}...")
                        update_api(raw_data.get('id'), updated_payload, api_token, is_snippet)
                        total_updated += 1
                    else:
                        print(f"Simulated push for {'snippet' if is_snippet else 'script'} {match}:")
                        updated_payload['script_body'] = updated_payload.pop('code')
                        print(json.dumps(updated_payload, indent=4))
                        sys.stdout.flush()
                except BrokenPipeError:
                    sys.stderr.close()
                    sys.stdout.close()

    print("\nComparison Complete:")
    print(f"Total files checked: {total_files_checked}")
    print(f"Total matches: {total_matches}")
    print(f"Total mismatches: {total_mismatches}")
    print(f"Total updates: {total_updated}")
    print(f"Total skipped: {total_skipped}")

def update_api(item_id, payload, api_token, is_snippet=False):
    """Update the API with the provided item ID and payload."""
    
    # Correctly handle 'code' or 'script_body' based on whether it's a snippet or a script
    if is_snippet:
        payload['code'] = payload.pop('code', '')
        endpoint = f"{domain}/scripts/snippets/{item_id}/"
    else:
        payload['script_body'] = payload.pop('code', '')
        endpoint = f"{domain}/scripts/{item_id}/"

    body = payload['code'] if is_snippet else payload['script_body']

    print(f"Updating {'snippet' if is_snippet else 'script'} {item_id}, length: {len(body)}, preview: {body[:1000]}{'...' if len(body) > 1000 else ''}")

    try:
        res = requests.put(endpoint, headers={"X-API-KEY": api_token}, json=payload, timeout=120)
        print(f"{item_id} update: {res.status_code} {res.reason}")
        if res.status_code != 200:
            print(res.text)
    except requests.exceptions.RequestException as e:
        print(f"Request error for {'snippet' if is_snippet else 'script'} {item_id}: {e}")



def git_pull(base_dir):
    """Force pull the latest changes from the git repository, discarding local changes."""
    if not os.path.isdir(base_dir):
        print(f"Invalid directory: {base_dir}")
        sys.exit(1)
    
    print("Starting force pull...")
    try:
        subprocess.check_call(['git', '-C', base_dir, 'fetch', 'origin'])
        subprocess.check_call(['git', '-C', base_dir, 'reset', '--hard', f'origin/{git_pull_branch}'])
        print(f"Successfully force-pulled the latest changes from the '{git_pull_branch}' branch.")
    except subprocess.CalledProcessError as e:
        print(f"Failed to force-pull changes from Git: {e}")
        sys.exit(1)


def git_push(base_dir):
    """Push local changes to the git repository."""
    try:
        # Check if a rebase is in progress
        rebase_in_progress = subprocess.run(
            ['git', '-C', base_dir, 'rebase', '--show-current-patch'],
            capture_output=True, text=True
        ).returncode == 0
        if rebase_in_progress:
            sys.exit("Rebase in progress. Complete or abort it.")

        # Get current branch
        branch_name = subprocess.run(
            ['git', '-C', base_dir, 'rev-parse', '--abbrev-ref', 'HEAD'],
            capture_output=True, text=True
        ).stdout.strip() or "update-scripts"
        if branch_name == 'HEAD':
            subprocess.check_call(['git', '-C', base_dir, 'checkout', '-b', branch_name])

        # Get staged changes
        status_result = subprocess.run(
            ['git', '-C', base_dir, 'status', '--porcelain'],
            capture_output=True, text=True
        )
        if status_result.stdout:
            subprocess.check_call(['git', '-C', base_dir, 'add', '.'])

            # Get the list of staged changes
            result = subprocess.run(
                ['git', '-C', base_dir, 'diff', '--cached', '--name-status'],
                capture_output=True, text=True, check=True
            )
            changes = {"created": [], "modified": [], "deleted": [], "renamed": []}
            for line in result.stdout.strip().split("\n"):
                if not line: continue
                status, file = line.split("\t")
                if file.startswith("scriptsraw/") or file.startswith("snippetsraw/"): continue
                if status.startswith("A"): changes["created"].append(file)
                elif status.startswith("M"): changes["modified"].append(file)
                elif status.startswith("D"): changes["deleted"].append(file)
                elif status.startswith("R"): changes["renamed"].append(f"{line.split()[1]} -> {line.split()[2]}")

            # Generate commit message
            def generate_commit_message(changes, max_files=5):
                if not any(changes.values()): return "Minor update"
                parts = [f"{change_type} {len(files)}: {', '.join(files[:max_files])}{'...' if len(files) > max_files else ''}"
                         for change_type, files in changes.items() if files]
                return "; ".join(parts)

            commit_message = generate_commit_message(changes)

            # Commit changes
            subprocess.check_call(['git', '-C', base_dir, 'commit', '-m', commit_message])
            print(f"Committed changes to branch '{branch_name}': {commit_message}")

            # Push changes
            subprocess.check_call(['git', '-C', base_dir, 'push', 'origin', branch_name])
            print(f"Changes pushed to branch '{branch_name}'")
        else:
            print("No changes to commit.")
    except subprocess.CalledProcessError as e:
        print(f"Git operation failed: {e}")


def check_git_health(base_dir):
    """Check if the Git folder is healthy by ensuring it's initialized, clean, and the git command is available."""
    try:
        # Check if the 'git' command is available by calling 'git --version'
        subprocess.check_call(['git', '--version'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Check if the directory is a Git repo by running 'git rev-parse'
        subprocess.check_call(['git', '-C', base_dir, 'rev-parse', '--is-inside-work-tree'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        # Check if the repo has any uncommitted changes by running 'git status --porcelain'
        status = subprocess.check_output(['git', '-C', base_dir, 'status', '--porcelain']).decode().strip()
        if status:
            print("Error: There are uncommitted changes in the Git repository.")
            return False

        # Check if the repo is on the expected branch by running 'git symbolic-ref --short HEAD'
        current_branch = subprocess.check_output(['git', '-C', base_dir, 'symbolic-ref', '--short', 'HEAD']).decode().strip()
        if current_branch != git_pull_branch:
            print(f"Warning: You're not on the expected branch '{git_pull_branch}'. Current branch is '{current_branch}'.")
            return False

        return True
    except subprocess.CalledProcessError:
        print("Error: The 'git' command is not available or the folder is not a valid Git repository.")
        return False

def main():
    global domain, headers

    # 0. General Prep: Setup Environment and Git Folder Health Check
    print("\n===== Step 0: General Prep =====")
    
    # Fetch environment variables needed
    domain, api_token, scriptpath = os.getenv('DOMAIN'), os.getenv('API_TOKEN'), os.getenv('SCRIPTPATH')
    if not all([domain, api_token, scriptpath]):
        print("Error: DOMAIN, API_TOKEN, and SCRIPTPATH must be set in the environment.")
        sys.exit(1)

    # Set headers for API requests
    headers = {"X-API-KEY": api_token}

    # Resolve the base directory where scripts will be saved and prepared
    base_dir = Path(scriptpath).resolve()

    # Define folders for storing scripts, raw scripts, snippets, and raw snippets
    folders = {name: base_dir / name for name in ["scripts", "scriptsraw", "snippets", "snippetsraw"]}
    for folder in folders.values():
        folder.mkdir(parents=True, exist_ok=True)

    # Check the health of the Git folder
    if check_git_health(base_dir):
        print("Git folder is healthy.")
    else:
        print("Error: Git folder is not healthy.")
        sys.exit(1)
    print("===== End of Step 0: General Prep =====\n")

    # 1. Git Pull
    print("\n===== Step 1: Git Pull =====")
    print(f"Branch to pull: '{git_pull_branch}'")
    if ENABLE_GIT_PULL:
        git_pull(base_dir)
    else:
        print("Git pull is disabled.")
    print("===== End of Step 1 =====\n")

    # 2. Write modifications to the API
    print("\n===== Step 2: Write Modifications to API =====")
    write_modifications_to_api(base_dir, folders, api_token)
    print("===== End of Step 2 =====\n")

    # 3. Fetch and process scripts
    print("\n===== Step 3: Fetch and Process Scripts and Snippets =====")
    # Initialize counters and sets
    shell_summary, current_scripts = defaultdict(int), set()
    print("Fetching scripts...")
    user_defined_scripts = fetch_data(f"{domain}/scripts/?showHiddenScripts=true", headers)
    user_defined_scripts = [item for item in user_defined_scripts if item.get('script_type') == 'userdefined']
    current_scripts.update(process_scripts(user_defined_scripts, folders["scripts"], folders["scriptsraw"], shell_summary))

    # Fetch and process snippets
    print("Fetching snippets...")
    snippets = fetch_data(f"{domain}/scripts/snippets/", headers)
    current_scripts.update(process_scripts(snippets, folders["snippets"], folders["snippetsraw"], shell_summary, is_snippet=True))

    # Output the total number of scripts exported and provide a summary of the shell counts
    print(f"Total number of scripts exported: {len(current_scripts)}")
    print("Shell summary:", "\n".join(f"{shell}: {count}" for shell, count in shell_summary.items()))

    # Remove any obsolete files that are no longer existing in the api
    for folder in folders.values():
        delete_obsolete_files(folder, current_scripts)

    print("===== End of Step 3 =====\n")

    # 4. Git Push
    print("\n===== Step 4: Git Push =====")
    if ENABLE_GIT_PUSH:
        git_push(base_dir)
    else:
        print("Git push is disabled.")
    print("===== End of Step 4 =====\n")



if __name__ == "__main__":
    main()
