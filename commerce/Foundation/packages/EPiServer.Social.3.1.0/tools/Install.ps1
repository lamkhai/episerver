param($installPath, $toolsPath, $package, $project)

Function RemoveFile($file)
{
    # If the file doesn't exist then don't need to delete anything and we exit silently
    if (!(Test-Path $file))
    {
        return
    }

    try
    {
        Write-Host "Removing file - $file"
        Remove-Item $file -Force -Recurse -ErrorAction Stop  
		Write-Host "File - $file removed success"
    }
    catch [Exception]
    {
        # Show a message box explaining that the file can not deleting
		$errorMsg = "The package installer was unable to delete the file ""$file"". Please delete this file as manually."
		Write-Host $errorMsg
        [System.Windows.Forms.MessageBox]::Show($errorMsg, "Error Deleting Folder") | Out-Null
    }
}

$fileName = "EPiServer.Social.WF"

# Remove reference from project
$project.Object.References | Where-Object { $_.Name -eq $fileName } | ForEach-Object { $_.Remove() }

# Get the path to the current project
$projectPath = Split-Path -Parent $project.FullName
$fileNameWithExtension = $fileName + ".dll"

# remove EPiServer.Social.WF in "bin" folder
$binPath = "bin\" + $fileNameWithExtension
$fullBinPath = Join-Path $projectPath $binPath
RemoveFile $fullBinPath

# remove EPiServer.Social.WF in "modulesbin" folder
$modulesbinPath = "modulesbin\" + $fileNameWithExtension
$fullModulesbinPath = Join-Path $projectPath $modulesbinPath
RemoveFile $fullModulesbinPath
