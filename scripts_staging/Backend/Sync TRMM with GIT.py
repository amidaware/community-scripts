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
        ------------------------------------------
    0. /!\TO BE READY BEFORE RUNNING THE SCRIPT/!\:
        ------------------------------------------
        The mapped folder should already be configured with git in the way you want to use it.
        An api key for a dedicated user with the role including the permissions "List Scripts"+"Manage Scripts"
        should be created in TRMM and added in the environements vars as per the exemples below.

    1. Pull all the modifications from the git repo pre-configured for the folder via git commands
        Any modification that would have been done on TRMM and git that would conflit will be overwriten by the GIT in priority.

    2. Check for diff between the json and scripts; if there is a diff, write back to the API the changes.

    3. Exports and overwrite all current scripts and scripts data to the 4 folders:
        scripts: extracted script code from the API converted from json
        scriptsraw: All json data from the API used for hash comparison and ID matches
        snippets: extracted snippet code from the API converted from json
        snippetsraw: All json data from the API used for hash comparison and ID matches

    4. Push all the modifications to the git repo pre-configured for the folder via git commands
        If there are no changes, no commit will be made.

.EXEMPLE
    MANDATORY:
    DOMAIN=api-rmm.exemple.com
    DOMAIN={{global.RMM_API_URL}}
    API_TOKEN={{global.rmm_key_for_git_script}}
    API_TOKEN=asdf1234
    SCRIPTPATH=/var/RMM-script-repo

    OPTIONAL:
    ENABLE_GIT_PULL=False
    ENABLE_GIT_PUSH=False
    ENABLE_WRITEBACK=False
    ENABLE_WRITETOFILE=False
    GIT_PULL_BRANCH=BranchName

.NOTES
    #public
    Original source not disclosed
    
.CHANGELOG
    v5.0 YYY Exports functional, adds script ID to from as "id - " 
    v5.a YYY "id - " for only raw folder. Fixed to use X-API-KEY
    v5.1 YYY Sanitizing script names when has / in it
    v5.2 YYY moving url and api token to .env file
    v5.3 YYY Making script folders be subfolders of where export.py file is
    v5.4 YYY making filenames utf-8 compliant
    v5.5 11/7/2024 XXX Save PowerShell scripts with .ps1 and Python scripts with .py extensions
    v5.6 11/7/2024 XXX Count the total number of scripts and print at the end
    v5.7 11/7/2024 XXX Print a summary of all the different types of shells exported
    v5.8 11/7/2024 XXX Add support for additional shell extension types
    v5.9 11/7/2024 XXX Detect deleted scripts and delete them from both folders
    v6 31/7/2024 SAN Add support for specifying the save folder via the SCRIPTPATH environment variable
    v6.0.1 31/7/2024 SAN Add Git integration to push changes to the configured Git repository
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
    v9.0.2.3 10/04/25 SAN removed pathvalidate dependency
    v9.0.2.4 10/04/25 SAN improvements in the git healthchecks and documentation
    v9.0.2.5 11/04/25 SAN added more detailed checks before running and dummy proofing
    v9.0.2.6 11/04/25 SAN improvements to sanitize, moved vars to global and fixed an issue that could delete all scripts from git randomly
    v9.0.3.0 11/04/25 SAN improvements to the git healthchecks and git push, disabled deletetions if writetofile is false and moved alls toggle flags and branch to env
    v9.0.3.1 14/04/25 SAN split step 2 into functions for easier upgrade 

.TODO
    Handle rights issues when executing git commands
    Review flow of step 3 for optimisations

    Revamp folder structure:
        Move raws from "scriptsraw" to Category/folder/raws/
        add "uncategorised" folder
        remove "scripts" top level folder while keeping snippets

    Move ID from json to an array like this and make sure that this array is never overwriten to keep tracks of IDs across instances only add current instance in step 2 if missing:
        "ids": [
        {
        "server": "rmm.example.com", (this needs to be a hash of the domain not clear text)
        "id": 123
        }
        before writing to api the modifications in step 2 new function to check all .json for id missing to this instance if missing create script then step 2 will add it to the array
    
    Delete script support from git ? (dedicated function required at the end of step 2, if json exist but no script matches mark for delete json and use the id of the json to tell the api to delete in trmm)
    Add reporting support

"""

import subprocess
import sys
import os
import hashlib
import json
from collections import defaultdict
from pathlib import Path
import requests
import re
import socket
from requests.exceptions import RequestException, HTTPError



# Retrieve the git pull branch or default to 'master'
git_pull_branch = os.getenv('GIT_PULL_BRANCH', 'master')
if git_pull_branch != 'master': print(f"Git Pull Branch: {git_pull_branch}")

# Retrieve flags from environment variables (default to True unless set to 'false')
ENABLE_GIT_PULL = os.getenv('ENABLE_GIT_PULL', 'True').lower() != 'false'
ENABLE_GIT_PUSH = os.getenv('ENABLE_GIT_PUSH', 'True').lower() != 'false'
ENABLE_WRITEBACK = os.getenv('ENABLE_WRITEBACK', 'True').lower() != 'false'
ENABLE_WRITETOFILE = os.getenv('ENABLE_WRITETOFILE', 'True').lower() != 'false'
if not ENABLE_GIT_PULL: print("Git Pull is disabled.")
if not ENABLE_GIT_PUSH: print("Git Push is disabled.")
if not ENABLE_WRITEBACK: print("Writeback is disabled.")
if not ENABLE_WRITETOFILE: print("Write to file is disabled.")



def delete_obsolete_files(folder, current_scripts):
    print(f"Cleaning {folder}...")
    obsolete = {f for f in folder.rglob('*') if f.is_file() and f.relative_to(folder) not in current_scripts}
    
    if not obsolete:
        print("No files missing from the API but still present in the repo.")

    for f in obsolete:
        if ENABLE_WRITETOFILE:
            try:
                f.unlink()
                print(f"Deleted file no longer in the API: {f}")
            except Exception as e:
                print(f"Error deleting file {f}: {e}")
        else:
            print(f"Simulated deletion of file no longer in the API: {f}")

    empty_dirs = [d for d in sorted(folder.rglob('*'), key=lambda p: -len(p.parts)) if d.is_dir() and not any(d.iterdir())]
    if not empty_dirs:
        print("No empty directories to remove.")

    for d in empty_dirs:
        if ENABLE_WRITETOFILE:
            try:
                d.rmdir()
                print(f"Removed empty directory: {d}")
            except Exception as e:
                print(f"Could not delete dir {d}: {e}")
        else:
            print(f"Simulated removal of empty directory: {d}")

def sanitize_filename(name: str) -> str:
    removed_chars = []
    
    if '\0' in name:
        removed_chars.append("\\0")
        name = name.replace('\0', '')
    
    invalid_chars = re.findall(r'[<>:"/\\|?*]', name)
    if invalid_chars:
        removed_chars.extend(invalid_chars)
        name = re.sub(r'[<>:"/\\|?*]', '', name)
    
    if removed_chars:
        print(f"Removed from file name: {', '.join(removed_chars)}")
    
    return name.strip()

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

        data = s if is_snippet else pull_from_api(f"{domain}/scripts/{sid}/download/?with_snippets=false")
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


def pull_from_api(url):
    try:
        print(f"Fetching: {url}")
        r = requests.get(url, headers=headers)
        r.raise_for_status()
        return r.json() if r.ok else []
    except RequestException as e:
        print(f"Request failed: {e}")
        sys.exit(1)
    except ValueError as e:
        print(f"Error decoding JSON: {e}")
        sys.exit(1)

def compare_files_and_hashes(match, raw_path):
    try:
        file_hash = compute_hash(match)
    except Exception as e:
        print(f"Error computing hash for file {match}: {e}")
        return None, None, None
    
    try:
        with raw_path.open(encoding='utf-8') as f:
            raw_data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error reading JSON file {raw_path}: {e}")
        return None, None, None
    except Exception as e:
        print(f"Unexpected error reading file {raw_path}: {e}")
        return None, None, None

    code = raw_data.get('code', '')
    try:
        code_hash = hashlib.sha256(code.encode('utf-8')).hexdigest()
    except Exception as e:
        print(f"Error generating hash for code in {raw_path}: {e}")
        return None, None, None

    return file_hash, code_hash, raw_data

def update_api_if_needed(match, raw_data, is_snippet):
    try:
        with match.open(encoding='utf-8') as f:
            updated_payload = {**raw_data, 'code': f.read()}
    except (FileNotFoundError, IOError) as e:
        print(f"Error reading script file {match}: {e}")
        return False
    except Exception as e:
        print(f"Unexpected error reading file {match}: {e}")
        return False

    try:
        if ENABLE_WRITEBACK:
            print(f"Updating API for {'snippet' if is_snippet else 'script'} {match}...")
            update_to_api(raw_data.get('id'), updated_payload, is_snippet)
            return True
        else:
            print(f"Simulated push for {'snippet' if is_snippet else 'script'} {match}:")
            updated_payload['script_body'] = updated_payload.pop('code')
            print(json.dumps(updated_payload, indent=4))
            sys.stdout.flush()
            return False
    except (ConnectionError, TimeoutError) as e:
        print(f"Network error while updating API for {'snippet' if is_snippet else 'script'} {match}: {e}")
    except Exception as e:
        print(f"Unexpected error while updating API for {'snippet' if is_snippet else 'script'} {match}: {e}")
    
    return False

def write_modifications_to_api(base_dir, folders):
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
            try:
                match = next((p for p in folders[folder_name].rglob('*') 
                              if p.is_file() and p.stem.lower() == raw_name), None)
            except Exception as e:
                print(f"Error matching file for {raw_path}: {e}")
                total_skipped += 1
                continue

            if not match:
                print(f"No match for {'snippet' if is_snippet else 'script'}: {raw_path}")
                total_skipped += 1
                continue

            print(f"Matched {'snippet' if is_snippet else 'script'}: {match} <-> {raw_path}")
            total_matches += 1

            file_hash, code_hash, raw_data = compare_files_and_hashes(match, raw_path)

            if file_hash and code_hash and file_hash != code_hash:
                total_mismatches += 1
                print(f"\n--- {'Snippet' if is_snippet else 'Script'} (first 10 lines) ---")
                try:
                    with match.open(encoding='utf-8') as f:
                        for i, line in enumerate(f):
                            if i >= 10: break
                            print(line.strip())
                except Exception as e:
                    print(f"Error reading file {match}: {e}")

                print(f"\n--- JSON Code (first 10 lines) ---")
                for line in raw_data.get('code', '').splitlines()[:10]:
                    print(line.strip())

                updated = update_api_if_needed(match, raw_data, is_snippet)

                if updated:
                    total_updated += 1

    print("\nComparison Complete:")
    print(f"Total files checked: {total_files_checked}")
    print(f"Total matches: {total_matches}")
    print(f"Total mismatches: {total_mismatches}")
    print(f"Total updates: {total_updated}")
    print(f"Total skipped: {total_skipped}")

def update_to_api(item_id, payload, is_snippet=False):
    """Update the API with the provided item ID and payload."""
    
    if is_snippet:
        payload['code'] = payload.pop('code', '')
        endpoint = f"{domain}/scripts/snippets/{item_id}/"
    else:
        payload['script_body'] = payload.pop('code', '')
        endpoint = f"{domain}/scripts/{item_id}/"

    body = payload['code'] if is_snippet else payload['script_body']

    print(f"Updating {'snippet' if is_snippet else 'script'} {item_id}, length: {len(body)}, preview: {body[:1000]}{'...' if len(body) > 1000 else ''}")

    try:
        res = requests.put(endpoint, headers=headers, json=payload, timeout=120)
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

def generate_commit_message(base_dir, max_files=5):
    """Generate a commit message based on staged changes."""
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

    if not any(changes.values()):
        return "Minor update"

    parts = [f"{change_type} {len(files)}: {', '.join(files[:max_files])}{'...' if len(files) > max_files else ''}"
             for change_type, files in changes.items() if files]
    return "; ".join(parts)

def git_push(base_dir):
    """Push local changes to the git repository."""
    try:
        # Get staged changes if none do nothing
        status_result = subprocess.run(
            ['git', '-C', base_dir, 'status', '--porcelain'],
            capture_output=True, text=True
        )
        if status_result.stdout:
            subprocess.check_call(['git', '-C', base_dir, 'add', '.'])

            commit_message = generate_commit_message(base_dir)

            # Commit & Push changes
            subprocess.check_call(['git', '-C', base_dir, 'commit', '-m', commit_message])
            print(f"Committed changes: {commit_message}")
            subprocess.check_call(['git', '-C', base_dir, 'push', 'origin', git_pull_branch])
            print(f"Changes pushed to branch '{git_pull_branch}'")

        else:
            print("No changes to commit.")
    except subprocess.CalledProcessError as e:
        print(f"Git operation failed: {e}")

def check_git_health(base_dir):
    """Check the health of the Git repository."""
    
    # Check if 'git' command is available
    try:
        subprocess.check_call(['git', '--version'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        print("Error: The 'git' command is not available.")
        return False
    
    # Check if the directory is a valid Git repository
    try:
        subprocess.check_call(['git', '-C', base_dir, 'rev-parse', '--is-inside-work-tree'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        print(f"Error: '{base_dir}' is not a valid Git repository.")
        return False
    
    # Check if the Git index is locked
    try:
        index_lock = Path(base_dir) / '.git' / 'index.lock'
        if index_lock.exists():
            print("Error: Git index is locked. Possibly due to a failed operation.")
            return False
    except Exception as e:
        print(f"Error: Failed to check index lock - {e}")
        return False

    # Check if a rebase is in progress
    try:
        rebase_in_progress = subprocess.run(
            ['git', '-C', base_dir, 'rebase', '--show-current-patch'],
            capture_output=True, text=True
        ).returncode == 0
        if rebase_in_progress:
            print("Error: Rebase in progress. Complete or abort it.")
            return False
    except subprocess.CalledProcessError:
        print("Error: Failed to check rebase status.")
        return False
    
    # Check for unresolved merge conflicts
    try:
        merge_conflicts = subprocess.check_output(['git', '-C', base_dir, 'ls-files', '--unmerged']).decode().strip()
        if merge_conflicts:
            print("Error: There are unresolved merge conflicts.")
            return False
    except subprocess.CalledProcessError:
        print("Error: Failed to check for merge conflicts.")
        return False
    
    # Check for uncommitted changes
    try:
        status = subprocess.check_output(['git', '-C', base_dir, 'status', '--porcelain']).decode().strip()
        if status:
            print("Error: There are uncommitted changes in the Git repository.")
            return False
    except subprocess.CalledProcessError:
        print("Error: Failed to check Git status.")
        return False
    
    # Check for untracked files
    try:
        untracked_files = subprocess.check_output(['git', '-C', base_dir, 'ls-files', '--others', '--exclude-standard']).decode().strip()
        if untracked_files:
            print("Error: There are untracked files in the Git repository.")
            return False
    except subprocess.CalledProcessError:
        print("Error: Failed to check for untracked files.")
        return False
    
    # Check the current Git branch
    try:
        current_branch = subprocess.check_output(['git', '-C', base_dir, 'symbolic-ref', '--short', 'HEAD']).decode().strip()
        if current_branch != git_pull_branch:
            print(f"Warning: You're not on the expected branch '{git_pull_branch}'. Current branch is '{current_branch}'.")
            return False
    except subprocess.CalledProcessError:
        print("Error: Unable to determine the current Git branch.")
        return False
    
    # Check for remote repository configuration
    try:
        remote_info = subprocess.check_output(['git', '-C', base_dir, 'remote', 'show', 'origin']).decode().strip()
        if not remote_info:
            print("Error: No remote repository is configured.")
            return False
    except subprocess.CalledProcessError:
        print("Error: Failed to retrieve remote repository information.")
        return False
    
    # Check if there are commits behind the remote
    try:
        commits_behind = subprocess.check_output(['git', '-C', base_dir, 'rev-list', '--count', 'HEAD..origin/{}'.format(git_pull_branch)]).decode().strip()
        if int(commits_behind) > 0:
            print(f"Warning: You are {commits_behind} commits behind the remote branch.")
            return False
    except subprocess.CalledProcessError:
        print("Error: Failed to check commit history.")
        return False
    
    return True

def pre_flight():
    global domain, scriptpath, headers
    domain = os.getenv('DOMAIN')
    api_token = os.getenv('API_TOKEN')
    scriptpath = os.getenv('SCRIPTPATH')

    missing = [name for name, val in [('DOMAIN', domain), ('API_TOKEN', api_token), ('SCRIPTPATH', scriptpath)] if not val]
    if missing:
        print(f"✗ Error: Missing environment variable(s): {', '.join(missing)}")
        for var in missing:
            if var == 'DOMAIN': print("  - DOMAIN: The URL of your RMM API. (e.g. api-rmm.example.com)")
            if var == 'API_TOKEN': print("  - API_TOKEN: An API token for a user with permission to access and write scripts.")
            if var == 'SCRIPTPATH': print("  - SCRIPTPATH: The local folder path for Git commands.")
        sys.exit(1)

    headers = {"X-API-KEY": api_token}
    domain_for_connection = domain.replace("https://", "").replace("http://", "")

    try:
        socket.create_connection((domain_for_connection, 443), timeout=5)
        print(f"✓ Connectivity to {domain} on port 443 OK.")
    except Exception as e:
        print(f"✗ Error: Unable to connect to {domain} on port 443 - {e}")
        sys.exit(1)

    if not domain.startswith("http://") and not domain.startswith("https://"):
        domain = "https://" + domain

    obfuscated = api_token[:3] + '*' * (len(api_token) - 6) + api_token[-3:]

    try:
        response = requests.get(f"{domain}/scripts/", headers=headers, timeout=5)
        if response.status_code == 200:
            print(f"✓ Token valid for read access: {obfuscated}")
        else:
            print(f"✗ Token read access denied (status {response.status_code})")
            sys.exit(1)
    except Exception as e:
        print(f"✗ Token read access check failed: {e}")
        sys.exit(1)

    return

def check_and_create_folders(base_path, subfolders):
    try:
        if not base_path.exists():
            base_path.mkdir(parents=True, exist_ok=True)
            print(f"✓ Root folder created at {base_path.resolve()}.")
        else:
            print(f"✓ Root folder exists at {base_path.resolve()}.")
        
        for folder_path in subfolders.values():
            if folder_path.exists():
                print(f"✓ Folder '{folder_path.name}' exists.")
            else:
                folder_path.mkdir(parents=True, exist_ok=True)
                print(f"✓ Folder '{folder_path.name}' created at {folder_path.resolve()}.")
    except Exception as e:
        print(f"✗ Error: Failed to create folder(s).")
        print(f"Error: {e}")
        sys.exit(1)

def main():
    
    # 0. Prep: Verify Dependencies, Set Up Environment, and Git Health Check
    print("\n===== Step 0: General Prep =====")
    
    # ENV vars & network checks
    pre_flight()

    # Folder structure check
    base_dir = Path(scriptpath).resolve()
    folders = {
        "scripts": base_dir / "scripts",
        "scriptsraw": base_dir / "scriptsraw",
        "snippets": base_dir / "snippets",
        "snippetsraw": base_dir / "snippetsraw"
    }
    check_and_create_folders(base_dir, folders)
    print("✓ All folders created and verified.")
    
    # Check the health of the Git repo
    if ENABLE_GIT_PULL or ENABLE_GIT_PUSH:
        if check_git_health(base_dir):
            print("✓ Git repo is healthy.")
        else:
            print("✗ Error: Git folder is not healthy.")
            sys.exit(1)
    else:
        print("Skipping Git health check because both pull and push are disabled.")
    
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
    write_modifications_to_api(base_dir, folders)
    print("===== End of Step 2 =====\n")

    # 3. Fetch and process scripts
    print("\n===== Step 3: Fetch and Process Scripts and Snippets =====")
    # Initialize counters and sets
    shell_summary, current_scripts = defaultdict(int), set()
    print("Fetching scripts...")
    user_defined_scripts = pull_from_api(f"{domain}/scripts/?showHiddenScripts=true")
    user_defined_scripts = [item for item in user_defined_scripts if item.get('script_type') == 'userdefined']
    current_scripts.update(process_scripts(user_defined_scripts, folders["scripts"], folders["scriptsraw"], shell_summary))

    # Fetch and process snippets
    print("Fetching snippets...")
    snippets = pull_from_api(f"{domain}/scripts/snippets/")
    current_scripts.update(process_scripts(snippets, folders["snippets"], folders["snippetsraw"], shell_summary, is_snippet=True))

    # Output the total number of scripts exported and provide a summary of the shell counts
    print(f"Total number of scripts exported: {len(current_scripts)}")
    print("Shell summary:", "\n".join(f"{shell}: {count}" for shell, count in shell_summary.items()))

    # Remove any obsolete files that are no longer existing in the api
    print("\nRemove any obsolete files")
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