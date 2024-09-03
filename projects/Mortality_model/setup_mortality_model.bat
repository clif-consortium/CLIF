@echo off
REM Create a virtual environment named .mortality_model
python -m venv .mortality_model

REM Activate the virtual environment
call .mortality_model\Scripts\activate.bat

REM Install required packages from requirements.txt
pip install -r requirements.txt

REM Install Jupyter and IPykernel
pip install jupyter ipykernel

REM Register the virtual environment as a kernel for Jupyter
python -m ipykernel install --user --name=.mortality_model --display-name="Python (mortality_model)"

REM Pause the batch file so the window doesn't close immediately
pause
