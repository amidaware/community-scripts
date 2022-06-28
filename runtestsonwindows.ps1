# This is for running pytest locally on windows only. 
# Using VSCode select the line(s) you wish to execute and use "Run Selection (F8)"
# Read more here: https://docs.tacticalrmm.com/devnotes/running_tests_locally/

#Activate python
python -m venv env
.\env\Scripts\activate 

#Install requirements first time only
python -m pip install --upgrade pip #1st time and when you want to update python modules
pip install -r requirements.txt #only 1st time

#Run mkdocs and look at changes as you make them
pytest

#Stop python
deactivate