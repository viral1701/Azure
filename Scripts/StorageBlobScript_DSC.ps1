function Add-AsosDSCModuleBlobStorage {

    $StorageContainerName = $StorageContainerName
    $CompressFolder = "C:\Compress"
    if(-not(Test-Path -Path $CompressFolder)){md $CompressFolder}

    $CurrentPath = Get-ChildItem -Exclude "Octopus.Action.*"
    $NugetPackageName = $OctopusParameters['Octopus.Action.Package.PackageId']
    $NugetPackageVersion = $OctopusParameters['Octopus.Action.Package.PackageVersion']

    Compress-Archive -Path $CurrentPath -DestinationPath "$CompressFolder\$NugetPackageName.zip" -Force

    $DSCModulePath = $CompressFolder
    $files = Get-ChildItem -Path $DSCModulePath -Recurse

    $storage = Get-AzureRmStorageAccount -ResourceGroupName $StorageResourceGroup -Name $StorageName
    $keys = Get-AzureRmStorageAccountKey -ResourceGroupName $StorageResourceGroup -Name $storage.StorageAccountName

    #Authenticate

    $storagecontext = New-AzureStorageContext -StorageAccountName $storage.StorageAccountName -StorageAccountKey $keys[0].Value
    $container = Get-AzureStorageContainer -Name $StorageContainerName -Context $storage.Context

    foreach ($file in $files) {
    $NugetPackageName = $OctopusParameters['Octopus.Action.Package.PackageId']
        $blobname = ("{0}/{1}/{2}" -f $NugetPackageName, $NugetPackageVersion,($file.FullName.Replace($DSCModulePath, "")).TrimStart("\"))
        Write-Host $blobname -ForegroundColor Yellow
        $blob = Get-AzureStorageBlob -Container $StorageContainerName -Context $storage.Context | Where-Object {$_.Name -eq ($blobname).Replace("\", "/")}
        if ($null -eq $blob) {
            Write-Output "Blob {0} does not exist in storage account {1} in container {2}, uploading" -f $blobname, $storage, $StorageContainerName
            $blob = Set-AzureStorageBlobContent -File $file.FullName -Container $StorageContainerName -Blob $blobname -Context $storage.Context -Verbose
        }
        else {
            $Md5Provider = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
            $LocalFileMD5 = [System.Convert]::ToBase64String($Md5Provider.ComputeHash([System.IO.File]::ReadAllBytes($file.FullName)))

            Write-Output "Blob {0} all ready exists in storage account {1} in container {2}, comparing" -f $blobname, $StorageName, $StorageContainerName
            if ($blob.ICloudBlob.Properties.ContentMD5 -ne $LocalFileMD5) {
                Write-Output "Blob content is different, overwriting"
                $blob = Set-AzureStorageBlobContent -File $file.FullName -Container $StorageContainerName -Blob $blobname -Context $storage.Context -Force -Confirm $false
            }
        }

    }
}

function Add-AsosDSCMOdules {

    $NugetPackageName = $OctopusParameters['Octopus.Action.Package.PackageId']
    $NugetPackageVersion = $OctopusParameters['Octopus.Action.Package.PackageVersion']
    $storage = Get-AzureRmStorageAccount -ResourceGroupName $StorageResourceGroup -Name $StorageName
    $keys = Get-AzureRmStorageAccountKey -ResourceGroupName $StorageResourceGroup -Name $storage.StorageAccountName

    $storagecontext = New-AzureStorageContext -StorageAccountName $storage.StorageAccountName -StorageAccountKey $keys[0].Value
    $container = Get-AzureStorageContainer -Name $StorageContainerName -Context $storage.Context
    $token = New-AzureStorageContainerSASToken -Name $StorageContainerName -Context $storage.Context -Permission r -ExpiryTime (Get-Date).AddMinutes(10)

    $DSCModules = (Get-AzureStorageBlob -Container $StorageContainerName -Context $storage.Context) | Where-Object {$_.Name -like "*/$NugetPackageVersion/*"}

    foreach ($DSCModule in $DSCModules) {
        #$FullName = $DSCModule.Name
        #$pos = $FullName.Substring(0, $FullName.LastIndexOf(".zip"))
        #$ModuleName = $pos.Split('/')[-1]
        $ModuleURI = $DSCModule.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri
        Write-Output "Uploading DSC Modules To Automation Account"
        Write-Output "The URI of the Mdoule is $ModuleURI"
        $ModuleExist = Get-AzureRmAutomationModule -Name $NugetPackageName -ResourceGroupName $AutomationResourceGroup -AutomationAccountName $AutomationAccount -ErrorAction SilentlyContinue
        if($null -eq $ModuleExist){
            Write-Output "No DSC Module Exist Will Be Adding Module....."
            New-AzureRmAutomationModule -ResourceGroupName $AutomationResourceGroup -AutomationAccountName $AutomationAccount -Name $NugetPackageName -ContentLink ($ModuleURI + $token)
        }
        else {
            if($null -ne $ModuleExist)
            {
                if($ModuleExist.Version -ne $NugetPackageVersion){
                    Write-Output "Not Current Version DSC Module Updating......"
                    New-AzureRmAutomationModule -ResourceGroupName $AutomationResourceGroup -AutomationAccountName $AutomationAccount -Name $NugetPackageName -ContentLink ($ModuleURI + $token)
                }
            }
        }

    }
}

$securepassword = $AzureSubscriptionPassword | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object pscredential -ArgumentList ($AzureSubscriptionUsername, $securepassword)

Login-AzureRmAccount -SubscriptionName $AzureSubscriptionName -Credential $credential

Add-AsosDSCModuleBlobStorage
Add-AsosDSCMOdules