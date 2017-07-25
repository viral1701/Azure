$Resource_Group = "viral_test"
$StorageName = "viralscriptstorage"
$ContainerName = "armtemplates"
$fileDirectory = "C:\github\Azure\ARM_VM_Creation"

#Grabbing Storage Account
$storage = Get-AzureRmStorageAccount -StorageAccountName $StorageName -ResourceGroupName $Resource_Group

#Grabbing Storage Account Key
$keys = Get-AzureRmStorageAccountKey -ResourceGroupName $Resource_Group -Name $storage.StorageAccountName

#Authenticate
$storagecontext = New-AzureStorageContext -StorageAccountName $storage.StorageAccountName -StorageAccountKey $keys[0].Value

#Creating Blob Container

New-AzureStorageContainer -Context $storagecontext -Name $ContainerName -Permission Off -Verbose

$container = Get-AzureStorageContainer -Name $ContainerName -Context $storage.Context

if($container)
{
    $filestoupload = Get-ChildItem $fileDirectory -Recurse -Force
    foreach($x in $filestoupload)
    {
        $targetpath = (Split-Path -Path $x.FullName -NoQualifier).TrimStart("\")
        #$targetpath = ($x.FullName.Substring($fileDirectory.Length + 1)).Replace("\","/")
        Set-AzureStorageBlobContent -File $x.FullName -Container $container.Name -Blob $targetpath -Context $storage.Context -Force -Verbose
        

    }


}