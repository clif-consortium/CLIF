#!/bin/bash

# Create a virtual environment named .mortality_model
python3 -m venv .mortality_model

# Activate the virtual environment
source .mortality_model/bin/activate

# Install required packages from requirements.txt
pip install -r requirements.txt

# Install Jupyter and IPykernel
pip install jupyter ipykernel

# Register the virtual environment as a kernel for Jupyter
python -m ipykernel install --user --name=.mortality_model --display-name="Python (mortality_model)"