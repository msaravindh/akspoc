#Connect-AD
function connect-AD{
param([string] $tenantId)
#### The account needs tenant Id Permissions

###prompt
$mycreds = Get-credentials 
$res = Login-AzureRmAccount -Credential $mycreds
# If you have multiple subscriptions, uncomment and set to the subscription you want to work with:
#$subscriptionId = "5a850d8e-****-****-****-**********"
#Set-AzureRmContext -SubscriptionId $subscriptionId

Install-Module AzureAD -Force
Connect-AzureAD -TenantId $tenantId -Credential $mycreds

### az login if you wish to use Az for AKS installation
az login -u aksadmin1@****.onmicrosoft.com -p 'MyPassword'
}


function create-serverapp
{
param( [string]$serverAppName)
# Provide these values for your new Azure AD app:
# $appName is the display name for your app, must be unique in your directory
# $secret is a password you create
$appURI = "http://" + $serverappName
$keyStartDate = Get-Date
$keyEndDate = $keyStartDate.AddYears(1)

#$secret = "Microsoft_1"
#$secret = ConvertTo-SecureString $secret -AsPlainText -Force
if(!($ServerApp = Get-AzureADApplication -Filter "DisplayName eq '$($serverAppName)'"  -ErrorAction SilentlyContinue))
{
	$Guid = New-Guid
	$startDate = Get-Date
	
	$PasswordCredential 				= New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordCredential
	$PasswordCredential.StartDate 		= $startDate
	$PasswordCredential.EndDate 		= $startDate.AddYears(1)
	$PasswordCredential.KeyId 			= $Guid
	$PasswordCredential.Value 			= ([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($Guid))))+"="

	$graphSvcprincipal = Get-AzureADServicePrincipal -All $true | ? { $_.DisplayName -match "Microsoft Graph" }
    $aadSvcprincipal = Get-AzureADServicePrincipal -All $true | ? { $_.DisplayName -match "Windows Azure Active Directory" }

	### Required Resource Access
	$reqGraph = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
	$reqGraph.ResourceAppId = $svcprincipal.AppId

	$reqAAD = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
	$reqAAD.ResourceAppId = $AADsvcprincipal.AppId


    ##Win Active Directory Delegated Permissions
    $DelAADPerm = (Get-AzureADServicePrincipal -filter "DisplayName eq 'Windows Azure Active Directory'").Oauth2Permissions | Where-Object {$_.AdminConsentDisplayName -like 'Sign in and read user profile'}
    $DelAADPermObj = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $DelAADPerm.Id,"Scope"
    

	##Graph Delegated Permissions
    $DelPermNames = @("Read directory data", "Sign in and read user profile")
    $DelPermIDs = @()
    foreach($prmsnName in $DelPermNames)
    {
        $DelPermObj = (Get-AzureADServicePrincipal -filter "DisplayName eq 'Microsoft Graph'").Oauth2Permissions | Where-Object {$_.AdminConsentDisplayName -like $prmsnName}
        $DelPermIDs += $DelPermObj.Id
    }

	$delPermission1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList   $DelPermIDs[0], "Scope"
    $delPermission2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $DelPermIDs[0], "Scope" 


	##Graph Application Permissions
    $RoleNames = @("Read directory data")
    $RoleIDs = @()
    
    foreach($role in $RoleNames)
    {
        $RoleObj = (Get-AzureADServicePrincipal -filter "DisplayName eq 'Microsoft Graph'").AppRoles | Where-Object {$_.DisplayName -like $role}
        $RoleIDs += $RoleObj.Id
    }

	$appPermission1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $RoleIDs[0],"Role" 


	$reqGraph.ResourceAccess =  $appPermission1, $delPermission1, $delPermission2
    $reqAAD.ResourceAccess = $DelAADPermObj

    $reqResourcesAccess = @($reqGraph, $reqAAD)
    
Try
{
	$ServerApp = New-AzureADApplication -DisplayName $serverappName -IdentifierUris $appURI -PasswordCredentials $PasswordCredential -RequiredResourceAccess $reqResourcesAccess -GroupMembershipClaims 'All'
} 
catch
{
    write-host $_.Exception.Message
}
            ##Grant permissions
            $azureAppId = $ServerApp.AppId
            $context = Get-AzureRmContext
            $tenantId = $context.Tenant.Id
            $refreshToken = @($context.TokenCache.ReadItems() | where {$_.tenantId -eq $tenantId -and $_.ExpiresOn -gt (Get-Date)})[0].RefreshToken
            $body = "grant_type=refresh_token&refresh_token=$($refreshToken)&resource=74658136-14ec-4630-ad9b-26e160ff0fc6"
            $apiToken = Invoke-RestMethod "https://login.windows.net/$tenantId/oauth2/token" -Method POST -Body $body -ContentType 'application/x-www-form-urlencoded'
            $header = @{
            'Authorization' = 'Bearer ' + $apiToken.access_token
            'X-Requested-With'= 'XMLHttpRequest'
            'x-ms-client-request-id'= [guid]::NewGuid()
            'x-ms-correlation-id' = [guid]::NewGuid()}
            $url = "https://main.iam.ad.ext.azure.com/api/RegisteredApplications/$azureAppId/Consent?onBehalfOfAll=true"
            Invoke-RestMethod -Uri $url -Headers $header -Method POST -ErrorAction Stop
}
else
{
	Write-Host
	Write-Host -f Yellow Azure AD Application $serverAppName already exists.
}
        return $ServerApp.AppId
}

function create-clientApp
{
    param([string]$ClientAppName,
    [string]$ServerAppName)
    # $secret is a password you create
    $appURI = "http://" + $ClientAppName
    $keyStartDate = Get-Date
    $keyEndDate = $keyStartDate.AddYears(1)

        if(!($ClientApp = Get-AzureADApplication -Filter "DisplayName eq '$($ClientAppName)'"  -ErrorAction SilentlyContinue))
        {
	        $Guid = New-Guid
	        $startDate = Get-Date
	
	        $PasswordCredential 				= New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordCredential
	        $PasswordCredential.StartDate 		= $startDate
	        $PasswordCredential.EndDate 		= $startDate.AddYears(1)
	        $PasswordCredential.KeyId 			= $Guid
	        $PasswordCredential.Value 			= ([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($Guid))))+"="

	        $svcprincipal = Get-AzureADServicePrincipal -All $true | ? { $_.DisplayName -match $ServerAppName } #CHANGE
            $AADsvcprincipal = Get-AzureADServicePrincipal -All $true | ? { $_.DisplayName -match "Windows Azure Active Directory" }

	        ### Required Resource Access
	        $reqGraph = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
	        $reqGraph.ResourceAppId = $svcprincipal.AppId

	        $reqAAD = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
	        $reqAAD.ResourceAppId = $AADsvcprincipal.AppId


            ##Win Active Directory Delegated Permissions
            $DelAADPerm = (Get-AzureADServicePrincipal -filter "DisplayName eq 'Windows Azure Active Directory'").Oauth2Permissions | Where-Object {$_.AdminConsentDisplayName -like 'Sign in and read user profile'}
            $DelAADPermObj = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $DelAADPerm.Id,"Scope"
    
            $reqAAD.ResourceAccess = $DelAADPermObj

            $reqResourcesAccess = @($reqAAD)
            Try
            {	
	            $ClientApp = New-AzureADApplication -DisplayName $ClientAppName -PasswordCredentials $PasswordCredential -RequiredResourceAccess $reqResourcesAccess -PublicClient $true
            }
            catch
            {
                write-host $_.Exception.Message
            }
        }
        else
        {
            Write-Host
            Write-Host -f Yellow Azure AD Application $ClientAppName already exists.
        }
        
        return $ClientApp.AppId
}

#####Remove
function Remove-App 
{
    param([string]$AppName)
    if($app = Get-AzureADApplication -Filter "DisplayName eq '$($AppName)'"  -ErrorAction SilentlyContinue)
    {
        Remove-AzureADApplication -ObjectId $app.ObjectId
    }
    else
    {
        Write-Host -f 'Yellow Azure AD Application $AppName does not exist.'
    }
}

function Deploy-Cluster
{
(param $serverAppId,
 $serverSecret, 
 $ClientAppId, 
 $tenantId, 
 $RG, 
 $clusterName, 
 $location)
$RG = 'myResourceGroup'
$loc = 'eastus'
$clusterName = 'myAKSCluster'

    az group create --name $RG --location $location

    az aks create --resource-group $RG --name  $clusterName --generate-ssh-keys --aad-server-app-id $serverappID  --aad-server-app-secret $serverSecret --aad-client-app-id $ClientAppId --aad-tenant-id $tenantId

    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster --admin

    kubectl apply -f rbac-aad-user.yaml

    kubectl apply -f rbac-aad-group.yaml

    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
}


connect-AD

#create Server
#$serverAppId = create-serverapp
#$serverAppId = '<id>'
#$serverSecret = "Microsoft_1"


#create Client
#$clientAppId = create-clientApp
$ClientAppId = '<id>'
$tenantId = '<tenant id>'

# Deploy-Cluster
Deploy-Cluster($serverAppId, $serverSecret, $ClientAppId, $tenantId)
#Remove Client
#remove-app($false)
