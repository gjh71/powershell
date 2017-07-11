$ServerFeatures = Import-Clixml ServerFeatures.xml
foreach ($feature in $ServerFeatures) 
{
    Install-WindowsFeature -Name $feature.name
}