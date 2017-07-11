#NOTE: has not been tested (yet)

#Login to azure:
# login-azurermaccount

$rgName = "cowmanager-dwh-prod"
$vm = Get-AzureRmVM -ResourceGroupName $rgName -Name "cm-dwh-2"
$disks = $vm.StorageProfile.DataDisks | Where-Object {$_.Name -like "cm-dwh-2-data*"}

#4 disks --> 4*150 = 600 gb
$size = 150
$size = 175 #700gb

$vm | Stop-AzureRmVM -Force

foreach ($disk in $disks)
{
     Set-AzureRmVMDataDisk -VM $vm -Name $disk.Name -DiskSizeInGB $size
}

Update-AzureRmVM -VM $vm -ResourceGroupName $rgName
Start-AzureRmVM -ResourceGroupName $rgName -VMName $vm.name

