#!/bin/bash

# need azure functions core tools: https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local
func init . --worker-runtime python
#func new --template "Http Trigger" --name MyHttpTrigger
python3 -m venv .venv
pip install -r requirements.txt

# statically grab extensions steps go here (dl using wget, extract, place into extensions dir)
curl -L http://extensions.duckdb.org/v1.4.4/linux_amd64/azure.duckdb_extension.gz | gunzip -c > extensions/v1.4.4/linux_amd64/azure.duckdb_extension
curl -L http://extensions.duckdb.org/v1.4.4/linux_amd64/spatial.duckdb_extension.gz | gunzip -c > extensions/v1.4.4/linux_amd64/spatial.duckdb_extension

# for azure cli tools: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

az login

az group delete --name azduckmvt

az group create --name azduckmvt --location eastus2

az storage account create \
  --name azduckmvtstorage \
  --resource-group azduckmvt \
  --location eastus2 \
  --sku Standard_LRS \
  --kind StorageV2

az storage container create \
  --name azduckmvtcontainer \
  --account-name azduckmvtstorage \
  --auth-mode login

export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name azduckmvtstorage \
  --resource-group azduckmvt \
  --query connectionString \
  --output tsv)

az storage azcopy blob upload \
  --account-name azduckmvtstorage \
  --container azduckmvtcontainer \
  --source "../data/*.parquet" \
  --connection-string "${AZURE_STORAGE_CONNECTION_STRING}"

az functionapp create \
    --name azduckmvtfunction \
    --storage-account azduckmvtstorage \
    --resource-group azduckmvt \
    --flexconsumption-location eastus2\
    --runtime python \
    --runtime-version 3.12 \
    --functions-version 4 \
    --os-type Linux

az functionapp config appsettings set \
  --name azduckmvtfunction \
  --resource-group azduckmvt \
  --settings "AZURE_STORAGE_CONNECTION_STRING=${AZURE_STORAGE_CONNECTION_STRING}"

func azure functionapp publish azduckmvtfunction