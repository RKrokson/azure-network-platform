# You need to set subscription ID environment variable for terraform (or hard code in resource provider block). 
# This is required for terraform to access the Azure resources.

# List all Azure subscriptions:
az account list --output table
# Set a subscription as the default:
az account set --subscription <subscription_id>
# You can set the subscription ID using the following command:
setx ARM_SUBSCRIPTION_ID $(az account show --query id --output tsv)