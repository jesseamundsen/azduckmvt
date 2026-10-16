export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name azduckmvtstorage \
  --resource-group azduckmvt \
  --query connectionString \
  --output tsv)

az storage blob upload \
  --account-name azduckmvtstorage \
  --container-name '$web' \
  --file index.html \
  --overwrite \
  --connection-string "${AZURE_STORAGE_CONNECTION_STRING}"

# this is the static web endpoint you can view the demo at
az storage account show \
  --name azduckmvtstorage \
  --query "primaryEndpoints.web" \
  --output tsv