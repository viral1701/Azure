class CreateStorageBlob
{
	[Parameter(Mandatory=$true)]
	[string]$ResourceGroup
	[Parameter(Mandatory=$true)]
	[string]$StorageName
	[Parameter(Mandatory=$true)]
	[string]$ContainerName
	[Parameter(Mandatory=$true)]
	[string]$fileDirectory
	[ValidateSet('Blob','Container','Off','Unknown')]
	[Parameter(Mandatory=$true)]
	[string]$Permission

	CreateStorageBlob([string]$SubscriptionId)
	{
		Login-AzureRmAccount
		Set-AzureRmContext -SubscriptionId $SubscriptionId
	}


	[void]UploadToStorage()
	{
		#Grabbing Storage Account
		$storage = Get-AzureRmStorageAccount -StorageAccountName $this.StorageName -ResourceGroupName $this.ResourceGroup

		#Grabbing Storage Account Keys
		$keys = Get-AzureRmStorageAccountKey -ResourceGroupName $this.ResourceGroup -Name $storage.StorageAccountName

		#Authenticate
		$storagecontext = New-AzureStorageContext -StorageAccountName $storage.StorageAccountName -StorageAccountKey $keys[0].Value

		#Creating Blob Container
		
		$container = Get-AzureStorageContainer -Name $this.ContainerName -Context $storage.Context -ErrorAction SilentlyContinue

		if($null -eq $container)
		{
			$container = New-AzureStorageContainer -Context $storagecontext -Name $this.ContainerName -Permission $this.Permission -Verbose
		}

			$filestoupload = Get-ChildItem $this.fileDirectory -Recurse -Force
			foreach($file in $filestoupload)
			{
				$targetpath = (Split-Path -Path $file.FullName -NoQualifier).TrimStart("\")
				Set-AzureStorageBlobContent -File $file.FullName -Container $container.Name -Blob $targetpath -Context $storage.Context -Force -Verbose
			}
	}

}