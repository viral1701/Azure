$ResourceGroupName = "viral_test"
$StorageName =  "viralscriptstorage"

$DeployResourceGroup = "viral_test01"

$storageaccount =  Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageName

$storageaccountcontext = $storageaccount.Context

$ContainerName = "armtemplates"

$token = New-AzureStorageContainerSASToken -Name $ContainerName -Context $storageaccountcontext -Permission r -ExpiryTime (Get-Date).AddMinutes(60)

$MainURL = ($storageaccountcontext | Get-AzureStorageBlob -Container $ContainerName -Blob "github/Azure/VM_Public_IP_Address/VM_Public_IP_Address/vm_public_ip_address.json").ICloudBlob.Uri.AbsoluteUri
$ParameterURL = ($storageaccountcontext | Get-AzureStorageBlob -Container $ContainerName -Blob "github/Azure/VM_Public_IP_Address/VM_Public_IP_Address/vm_public_ip_address.parameters.json" ).ICloudBlob.Uri.AbsoluteUri

New-AzureRmResourceGroupDeployment -Name "template" -ResourceGroupName $DeployResourceGroup -TemplateUri ($MainURL + $token) -TemplateParameterUri ($ParameterURL + $token) -Verbose