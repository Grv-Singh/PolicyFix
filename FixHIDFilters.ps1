# Define the HIDClass GUID
$HIDClassGUID = "{745a17a0-74d3-11d0-b6fe-00a0c90f57da}"

# Define the registry path for HIDClass devices
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$HIDClassGUID"

# Define the filter to remove
$filterToRemove = "mshidkmdf"

# Function to take ownership of a registry key
function Take-Ownership {
    param (
        [string]$keyPath
    )

    # Take ownership of the key
    $acl = Get-Acl -Path $keyPath
    $owner = [System.Security.Principal.NTAccount]"Administrators"
    $acl.SetOwner($owner)
    Set-Acl -Path $keyPath -AclObject $acl

    # Grant full control to Administrators
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
        "Administrators",
        "FullControl",
        "ContainerInherit,ObjectInherit",
        "None",
        "Allow"
    )
    $acl.SetAccessRule($rule)
    Set-Acl -Path $keyPath -AclObject $acl
}

# Function to remove filters from a registry key
function Remove-Filters {
    param (
        [string]$keyPath
    )

    # Check if the key exists
    if (Test-Path $keyPath) {
        # Take ownership of the key
        Take-Ownership -keyPath $keyPath

        # Get the current UpperFilters and LowerFilters values
        $upperFilters = (Get-ItemProperty -Path $keyPath -Name "UpperFilters" -ErrorAction SilentlyContinue).UpperFilters
        $lowerFilters = (Get-ItemProperty -Path $keyPath -Name "LowerFilters" -ErrorAction SilentlyContinue).LowerFilters

        # Remove specified filter from UpperFilters
        if ($upperFilters) {
            $newUpperFilters = $upperFilters | Where-Object { $_ -ne $filterToRemove }
            if ($newUpperFilters.Count -eq 0) {
                Remove-ItemProperty -Path $keyPath -Name "UpperFilters" -ErrorAction SilentlyContinue
                Write-Host "Removed UpperFilters from $keyPath"
            } elseif ($newUpperFilters -ne $upperFilters) {
                Set-ItemProperty -Path $keyPath -Name "UpperFilters" -Value $newUpperFilters
                Write-Host "Updated UpperFilters in $keyPath"
            }
        }

        # Remove specified filter from LowerFilters
        if ($lowerFilters) {
            $newLowerFilters = $lowerFilters | Where-Object { $_ -ne $filterToRemove }
            if ($newLowerFilters.Count -eq 0) {
                Remove-ItemProperty -Path $keyPath -Name "LowerFilters" -ErrorAction SilentlyContinue
                Write-Host "Removed LowerFilters from $keyPath"
            } elseif ($newLowerFilters -ne $lowerFilters) {
                Set-ItemProperty -Path $keyPath -Name "LowerFilters" -Value $newLowerFilters
                Write-Host "Updated LowerFilters in $keyPath"
            }
        }
    }
}

# Function to reinstall the HID driver
function Reinstall-HIDDriver {
    Write-Host "Reinstalling HID driver..."
    $device = Get-PnpDevice | Where-Object { $_.InstanceId -like "*ITE8353*" }
    if ($device) {
        $deviceId = $device.InstanceId
        Write-Host "Found device with InstanceId: $deviceId"
        pnputil /remove-device $deviceId
        pnputil /scan-devices
        Write-Host "HID driver reinstalled."
    } else {
        Write-Host "Device with ITE8353 hardware ID not found."
    }
}

# Main script logic
Write-Host "Starting script to fix HID device issues..."

# Step 1: Take ownership of the registry key
Write-Host "Taking ownership of registry keys..."
Take-Ownership -keyPath $registryPath

# Step 2: Remove mshidkmdf from UpperFilters or LowerFilters
Write-Host "Removing $filterToRemove from registry..."
Get-ChildItem -Path $registryPath -Recurse | ForEach-Object {
    Remove-Filters -keyPath $_.PSPath
}

# Step 3: Reinstall the HID driver
Reinstall-HIDDriver

# Step 4: Disable automatic driver updates
Write-Host "Disabling automatic driver updates..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" -Name "SearchOrderConfig" -Value 0

# Step 5: Restart the computer
Write-Host "Script completed. Restart your computer to apply changes."
$restart = Read-Host "Do you want to restart now? (Y/N)"
if ($restart -eq "Y" -or $restart -eq "y") {
    Restart-Computer -Force
}