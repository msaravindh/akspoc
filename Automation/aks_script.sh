#!/bin/bash
read_properties()
{
#Static file to source Azure login credentials
. /home/azureuser/aksscript/static.config

if [ "$#" -ne 1 ]
then
  echo "Please provide the keyvalue file as input to the script"
  exit 
fi
  file="$1"
if [ ! -f $file ];then
        echo "keyvalue file does not exist"
        exit
fi

#Function to check if Azure CLI and Kubectl are installed
programexists()
{
  command -v "$1" >/dev/null 2>&1
}
echo "checking prerequisites"
if programexists az; then
  echo 'Azure CLI exists'
else
  echo 'Your system does not have Azure CLI installed.Please install to continue'
  exit
fi
if programexists kubectl; then
  echo 'kubectl exists'
else
  echo 'Your system does not have kubectl installed.Please install to continue'
  exit
fi

#Read values from the keyvalue file
  file="$1"
  while IFS="=" read -r key value; do
    case "$key" in
      "application") application="$value" ;;
      "environment") environment="$value" ;;
      "owner") owner="$value" ;;
      "Business") Business="$value" ;;
      "Region") Region="$value" ;;
      "Subscription") Subscription="$value" ;;
      "Resourcegroup") Resourcegroup="$value" ;;
      "Cluster") Cluster="$value" ;;
      "name2") name2="$value" ;;
    esac
  done < "$file"



#check for special characters or space in application name
echo $application| grep '[]:^/\_?#@!$&'"'"'() *+,;=%[]' >/dev/null 2>&1
if [ "$?" -eq "0" ]; then
  echo "Found special charecters in application name.Please remove the special character and execute the script again"
  exit
else
  echo "application value is $application"
fi

case $environment in
        devtest|uat|prod)
                echo "environment is $environment"
                ;;
        *)
                echo "environment value should be devtest,uat or prod. Please correct the value in keyvalue.txt and try again"
                exit
                ;;
  esac

case $Business in
        corp|corp-platforms|cx|rx|vx|rd)
                echo "Business is $Business"
                ;;
        *)
                echo "Business value should be one of: corp, corp-platforms, cx, rd, rx, vx. Please correct the value in keyvalue.txt and try again"
                exit
                ;;
  esac

case $Region in
        eastus2|northeurope)
                echo "Region is  $Region"
                ;;
        *)
                echo "Region value should be one of: eastus2,northeurope. Please correct the value in keyvalue.txt and try again"
                exit
                ;;
  esac

#Login to Azure
       az login --service-principal --username $username --password $password --tenant $tenant
       az account set -s $subscription



aadrolebindinggroup="AZC-AKS-$application-$environment-developers"
replicatedgroup=$(az ad group list --display-name $aadrolebindinggroup --out tsv)
if [ -z "$replicatedgroup" ]; then
        echo "Replicated group $aadrolebindinggroup does not exist . Please try again after the group is replicated or with the right inputs for "application" and "enviroment" variables in keyvalue.txt"
        exit
else
        echo "Group $aadrolebindinggroup found in ad"
fi

#Create AAD group for the rolebinding
adgroupname="AZC-AKS-$application-$environment-developer-rolebinding"
groupname=$(az ad group list --display-name $adgroupname --out tsv)
if [ -z "$groupname" ]; then
        echo "Rolebinding Group does not exist and will be created"
        az ad group create --display-name $adgroupname --mail-nickname $adgroupname
        rolebindinggroupobjectid=$(az ad group show -g $adgroupname --query objectId -o tsv) && echo $rolebindinggroupobjectid
 else
        echo "Group $adgroupname found in ad"
        rolebindinggroupobjectid=$(az ad group show -g $adgroupname --query objectId -o tsv) && echo $rolebindinggroupobjectid
fi

#Obtain Object ID of AAD rolebinding group 
adgroupobjectid=$(az ad group show -g $aadrolebindinggroup --query objectId -o tsv) && echo $adgroupobjectid

#Make the replicated AD group a member of AAD rolebinding group
az ad group member add --group $rolebindinggroupobjectid --member-id $adgroupobjectid

#Obtain Object ID of AKS cluster
aksobjectid=$(az resource show --name $Cluster --resource-group $Resourcegroup --resource-type managedClusters --namespace Microsoft.ContainerService --query id -o tsv) && echo $aksobjectid

#Grant "Azure Kubernetes Service Cluster User Role" role to AAD rolebinding group on the cluster
az role assignment create --role "Azure Kubernetes Service Cluster User Role" --assignee-object-id $rolebindinggroupobjectid --scope $aksobjectid

#Create service principal - make note of credentials!!!
spname=sp-aks-$application-$environment-deployment
az ad sp create-for-rbac --name $spname

#Get Object ID of the service principal
spobjectid=$(az ad sp show --id http://$spname --query objectId -o tsv) && echo $spobjectid

#Make the SP a member of AAD rolebinding group
az ad group member add --group $rolebindinggroupobjectid --member-id $spobjectid

#Function to create namespace
namespace_yaml()
{
if [ -f ./namespace.yaml ];then
	rm ./namespace.yaml
fi 
if [ ! -f ./namespace.yaml ]; then	
  echo -e "\nGenerating a namespace.yaml file"

  # Generate the file
  cat > ./namespace.yaml <<EOL
apiVersion: v1
kind: Namespace
metadata:
 name: $namespace
 labels:
  ApplicationName: $application
  Environment: $environment
  BusinessOwner: $owner
  BusinessUnitIT: $Business
EOL
fi
kubectl create -f ./namespace.yaml
}

#Function to create role
role_yaml()
{
if [ -f ./role.yaml ];then
        rm ./role.yaml
fi
if [ ! -f ./role.yaml ]; then
  echo -e "\nGenerating a role.yaml file"

  # Generate the file
  cat > ./role.yaml <<EOL
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
 name: $application-developer-role
 namespace: $namespace
rules:
- apiGroups: ["", "batch", "extensions", "apps"]
  resources: ["*"]
  verbs: ["*"]

EOL
fi
kubectl create -f ./role.yaml
}

#Function to create role binding
rolebinding_yaml()
{
if [ -f ./rolebinding.yaml ];then
        rm ./rolebinding.yaml
fi
if [ ! -f ./rolebinding.yaml ]; then
  echo -e "\nGenerating a rolebinding.yaml file"

  # Generate the file
  cat > ./rolebinding.yaml <<EOL

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $application-developer-rolebinding
  namespace: $namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: $application-developer-role
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: $adgroupobjectid

EOL
fi
kubectl create -f ./rolebinding.yaml
}



rm  ~/.kube/config
az aks get-credentials --resource-group $Resourcegroup --name $Cluster --admin
namespace="$application-$environment"
role="$application-developer-role"
rolebinding="$application-developer-rolebinding"
if kubectl get namespaces |grep -q "$namespace";then
	echo "namespace exists"
if kubectl get roles --namespace $namespace|grep -q "$role";then	
	echo "role exists"
else
	role_yaml
fi
if kubectl get rolebindings --namespace $namespace|grep -q "$rolebinding";then
	echo "rolebinding exists"
else
	rolebinding_yaml
fi
else
	echo "namespace does not exist and will be created"
	namespace_yaml
	role_yaml
	rolebinding_yaml
        echo "#################################################################################################"
        echo "Namespace $application-$environment created in AKS cluster $Cluster in resource group $Resourcegroup"
        
fi
}

read_properties $1


