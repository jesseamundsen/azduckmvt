export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
  --name azduckmvtstorage \
  --resource-group azduckmvt \
  --query connectionString \
  --output tsv)

az storage azcopy blob upload \
  --account-name azduckmvtstorage \
  --container azduckmvtcontainer \
  --source "../web" \
  --connection-string "${AZURE_STORAGE_CONNECTION_STRING}"

az storage blob upload \
  --account-name azduckmvtstorage \
  --container-name '$web' \
  --file index.html \
  --connection-string "${AZURE_STORAGE_CONNECTION_STRING}"

az storage account show \
  --name azduckmvtstorage \
  --query "primaryEndpoints.web" \
  --output tsv

