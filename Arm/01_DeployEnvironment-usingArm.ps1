#$environmentShortName = "gjtst3"
#$environmentName = "{0}-longnm" -f $environmentShortName
#$appServerExists = $false

param(
    [Parameter(Mandatory=$true)]
    [string] $environmentName,
    [switch] $appServerExists
)

Connect-AzureRmAccount

$subscriptionid = "3cce63cc-7694-47ff-aeac-6d62305d0f64" #azure
$subscriptionid = "b665d249-3f3a-420f-a2e8-d518bda53b87" #action pack
$deployAppServer = ($appServerExists -eq $true)
$template = Join-Path $PSScriptRoot -ChildPath "cm-web-app-db-server.json"

if ($deployAppServer){
  Write-Host("Deploying 1 appserver, 1 webserver and 1 db-server") -ForegroundColor Green
}
else{
  Write-Host("Deploying 1 web/appserver and 1 db-server") -ForegroundColor Green
}

Select-AzureRmSubscription -Subscriptionid $subscriptionid

Clear-Host
$rgName = "cm-{0}-rg" -f $environmentName
$rg = Get-AzureRmResourceGroup -Name $rgName -ErrorAction SilentlyContinue
if ($null -eq $rg){
    New-AzureRmResourceGroup -Name $rgName -Location "West Europe"
}
else {
    Write-Host("{0:dd-MM-yyyy HH:mm:ss} : ResourceGroup {1} already exists" -f (Get-Date), $rgName) -ForegroundColor Yellow
}

$depNm = "$rgName-deployment"
$args = @{
  Name = $depNm
  ResourceGroupName = $rgName
  TemplateFile = $template
  environmentName = $environmentShortName
  deployAppServer = $deployAppServer
  #adminPassword = "Mentos1!"
}
Write-Host("{0:dd-MM-yyyy HH:mm:ss} : Start deployment {1}. Arguments:" -f (Get-Date), $depNm) -ForegroundColor Yellow
$args
New-AzureRmResourceGroupDeployment @args

Write-Host("{0:dd-MM-yyyy HH:mm:ss} : Deployment ready" -f (Get-Date)) -ForegroundColor Yellow


