# community-scripts
This is a list of powershell, python, and batch scripts for use in [TacticalRMM](https://github.com/wh1te909/tacticalrmm)

See <https://docs.tacticalrmm.com/contributing_community_scripts/> for best practices on committing.

## `scripts_wip` folder

The [`/scripts_wip/`](https://github.com/amidaware/community-scripts/tree/main/scripts_wip) is a collection box for anything you want WIP=(Work In Progress). Jot ideas, not completed scripts, all commits welcome. Have some time and want to help with Tactical RMM? Discuss in the #script Discord channel and toss around ideas with other people and improve scripts from wip to official script quality.

## `scripts_staging` folder

The [`/scripts_staging/`](https://github.com/amidaware/community-scripts/tree/main/scripts_staging) is a collection box for WIP scripts that are believed to be ready for official "Community Scripts" integration. Please test these scripts, and provide feedback on the quality of the script in the Discord #scripts channel.

## `scripts` folder

The [`/scripts/`](https://github.com/amidaware/community-scripts/tree/main/scripts) folder is the Official Community Script folder. Everything in here will be distributed with Tactical RMM during the install process. 

Everything in this folder **_MUST_** have a corresponding and valid entry in the [community_scripts.json](https://github.com/amidaware/community-scripts/blob/main/community_scripts.json) which is used in TRMMs install and upgrade process to integrate these scripts into the Tactical RMM `Script Manager` > `Community Scripts` in all Tactical Installations.

Until v1 of Tactical RMM is released function changes on existing scripts is allowed, but not encouraged. Be aware there may be Tactical RMM installs in the field where you might be breaking someones scripts/tasks applied to their workstations. Work hard and try to add additional functionality/consolidate multiple scripts while preserving backwards functionality (or make a new version of the script).

## Running tests locally

### Setup the env and install pytest
```
python3 -m venv env
source env/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### Run tests
```
pytest
```