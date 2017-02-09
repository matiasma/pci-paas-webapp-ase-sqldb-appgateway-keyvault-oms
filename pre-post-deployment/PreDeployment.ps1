Param(
    [string] [Parameter(Mandatory=$true)] $azureADDomainName,# Provide your azuure Domain Name
	[string] [Parameter(Mandatory=$true)] $subscriptionName, # Provide your Azure subscription
	[string] [Parameter(Mandatory=$true)] $suffix #This is used to create a unique website name in your organization. This could be your company name or business unit name
)

###
#Imp: This script need to run by Global Administrator 
###

$azureADAdministratorID = "adadmin@$azureADDomainName"
$sqlAdminID = "sqladmin@$azureADDomainName"
$testUserID = "user1@$azureADDomainName"

Connect-MsolService
$cloudwiseAppServiceURL = "http://localcloudneeti6i.$azureADDomainName"
$AdUserExists = Get-MsolUser -UserPrincipalName $azureADAdministratorID -ErrorAction SilentlyContinue -ErrorVariable errorVariable
if ($AdUserExists -eq $null)  
{    
    $AdUserdetails=New-MsolUser -UserPrincipalName $azureADAdministratorID -DisplayName "AD Administrator PCI Samples" -FirstName "AD Administrator" -LastName "PCI Samples"
	$AdUserdetails
}
$SQLUserExists = Get-MsolUser -UserPrincipalName $sqlAdminID -ErrorAction SilentlyContinue -ErrorVariable errorVariable
if ($SQLUserExists -eq $null)  
{    
    New-MsolUser -UserPrincipalName $sqlAdminID -DisplayName "SQLAdministrator PCI Samples" -FirstName "SQL Administrator" -LastName "PCI Samples"
}
$AdminUserExists = Get-MsolUser -UserPrincipalName $testUserID -ErrorAction SilentlyContinue -ErrorVariable errorVariable
if ($AdminUserExists -eq $null)  
{    
    New-MsolUser -UserPrincipalName $testUserID -DisplayName "Test User PCI Samples" -FirstName "Test User" -LastName "PCI Samples"
}

#------------------------------
Set-Location ".\"
$passwordADApp =        "Password@123" 
$Web1SiteName =         ("cloudwise" + $suffix)
$displayName1 =         ($suffix + "Azure PCI PAAS Sample")
# To login to Azure Resource Manager
	Try  
	{  
		Get-AzureRmContext -ErrorAction Continue  
	}  
	Catch [System.Management.Automation.PSInvalidOperationException]  
	{  
		 #Add-AzureRmAccount 
		Login-AzureRmAccount -SubscriptionName $subscriptionName
	} 

# To select a default subscription for your current session

$sub = Get-AzureRmSubscription �SubscriptionName $subscriptionName | Select-AzureRmSubscription 

### 2. Create Azure Active Directory apps in default directory
Write-Host ("Step 2: Create Azure Active Directory apps in default directory") -ForegroundColor Gray
    $u = (Get-AzureRmContext).Account
    $u1 = ($u -split '@')[0]
    $u2 = ($u -split '@')[1]
    $u3 = ($u2 -split '\.')[0]
    $defaultPrincipal = ($u1 + $u3 + ".onmicrosoft.com")
    # Get tenant ID
    $tenantID = (Get-AzureRmContext).Tenant.TenantId
    $homePageURL = ("http://" + $defaultPrincipal + "azurewebsites.net" + "/" + $Web1SiteName)
    $replyURLs = @( $cloudwiseAppServiceURL, "http://*.azurewebsites.net","http://localhost:62080", "http://localhost:3026/")
    # Create Active Directory Application
    $azureAdApplication1 = New-AzureRmADApplication -DisplayName $displayName1 -HomePage $cloudwiseAppServiceURL -IdentifierUris $cloudwiseAppServiceURL -Password $passwordADApp -ReplyUrls $replyURLs
    Write-Host ("Step 2.1: Azure Active Directory apps creation successful. AppID is " + $azureAdApplication1.ApplicationId) -ForegroundColor Gray

### 3. Create a service principal for the AD Application and add a Reader role to the principal

    Write-Host ("Step 3: Attempting to create Service Principal") -ForegroundColor Gray
    $principal = New-AzureRmADServicePrincipal -ApplicationId $azureAdApplication1.ApplicationId
    Start-Sleep -s 30 # Wait till the ServicePrincipal is completely created. Usually takes 20+secs. Needed as Role assignment needs a fully deployed servicePrincipal
    Write-Host ("Step 3.1: Service Principal creation successful - " + $principal.DisplayName) -ForegroundColor Gray
    $scopedSubs = ("/subscriptions/" + $sub.Subscription)
    Write-Host ("Step 3.2: Attempting Reader Role assignment" ) -ForegroundColor Gray
    New-AzureRmRoleAssignment -RoleDefinitionName Reader -ServicePrincipalName $azureAdApplication1.ApplicationId.Guid -Scope $scopedSubs
    Write-Host ("Step 3.2: Reader Role assignment successful" ) -ForegroundColor Gray


### 4. Print out the required project settings parameters
#############################################################################################
$ADAdminObjectId = (Get-AzureRmADUser -UserPrincipalName $azureADAdministratorID).id
$SQLAdminObjectId = (Get-AzureRmADUser -UserPrincipalName $sqlAdminID).id
$AdminUserObjectId = (Get-AzureRmADUser -UserPrincipalName $testUserID).id
$ApplicationObjectId = (Get-AzureRmADServicePrincipal -ServicePrincipalName $azureAdApplication1.ApplicationId) 

Write-Host ("AD Application Details:") -foreground Green
$azureAdApplication1
Write-Host ("Parameters to be used in the registration / configuration.") -foreground Green

Write-Host "Azure AD Application Client ID: " -foreground Green �NoNewLine
Write-Host $azureAdApplication1.ApplicationId -foreground Red 
Write-Host "Azure AD Application Client Secret: " -foreground Green �NoNewLine
Write-Host $passwordADApp -foreground Red 
Write-Host "Azure AD Application Object ID: " -foreground Green �NoNewLine
Write-Host $ApplicationObjectId.Id -foreground Red 
Write-Host "Created or Updated Users in Active Directory " -foreground Green �NoNewLine
Write-Host ("`t" + $azureADAdministratorID) -foreground Red 
Write-Host ("`t" + $sqlAdminID) -foreground Red 
Write-Host ("`t" + $testUserID) -foreground Red 
Write-Host "Azure AD Admin User Name: " -foreground Green �NoNewLine
Write-Host $azureADAdministratorID -foreground Red 
Write-Host "Azure AD Admin User Password: " -foreground Green �NoNewLine
Write-Host $AdUserdetails.password -foreground Red 
Write-Host "Azure AD User Object Id: " -foreground Green �NoNewLine
Write-Host $AdminUserObjectId -foreground Red 
Write-Host "Azure AD Admin Object Id: " -foreground Green �NoNewLine
Write-Host $ADAdminObjectId -foreground Red 
Write-Host "Azure AD SQL Object Id: " -foreground Green �NoNewLine
Write-Host $SQLAdminObjectId -foreground Red 



Write-Host "PostLogoutRedirectUri: " -foreground Green �NoNewLine
Write-Host $cloudwiseAppServiceURL -foreground Red 
Write-Host "TenantId: " -foreground Green �NoNewLine
Write-Host $tenantID -foreground Red 
Write-Host "SubscriptionID: " -foreground Green �NoNewLine
Write-Host $sub.Subscription -foreground Red 


Write-Host ("TODO - Update permissions for the AD Application  '") -foreground Yellow �NoNewLine
Write-Host $displayName1 -foreground Red �NoNewLine
Write-Host ("'. Cloudwise would atleast need 2 apps") -foreground Yellow
Write-Host ("`t 1) Windows Azure Active Directory ") -foreground Yellow
Write-Host ("`t 2) Windows Azure Service Management API ") -foreground Yellow
Write-Host ("`t 3) Key Vault ") -foreground Yellow
Write-Host ("`t 4) Microsoft Graph API ") -foreground Yellow
Write-Host ("see README.md for details") -foreground Yellow

Read-Host -Prompt "The script executed. Copy all the values above."