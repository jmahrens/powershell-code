#Target Hyper-V host
$Hostname = 'server01.contoso.com'
<#
Name, Memory, MaxMemory, Threads
vm01,   4,      8,          4
sql01,  8,      16,         4
#>
$NewVMs = Import-Csv -Path 'C:\Path\to\data.csv'

Enter-PSSession -ComputerName $Hostname -Credential

foreach ($singleVm in $NewVMs){
    $VMPath = 'D:\Hyper-V'
    $VMName = $singleVm.Name
    $ISO = '\\fileserver\path\server.iso'

    $NewVMParam = @{
        Name = $VMname
        MemoryStartUpBytes = $singleVm.Memory
        Path = $VMPath
        NewVHDPath = "$VMPath\$VMName\$VMName.vhdx"
        NewVHDSizeBytes = 100GB
        Generation = 2
        ErrorAction = 'Stop'
        Verbose = $True
    }
    $SetVMParam = @{
        Name = $VMName
        ProcessorCount =  $singleVm.Threads
        DynamicMemory =  $True
        MemoryMinimumBytes =  $singleVm.Memory
        MemoryMaximumBytes =  $singleVm.MaxMemory
        ErrorAction =  'Stop'
        PassThru =  $True
        Verbose =  $True
    }
    $VMDVDParam = @{
        VMName = $VMName
        Path = $ISO
        ErrorAction = 'Stop'
        Verbose = $True
    }
    $VMFirmwareParam =@{
        VMName = $VMName
        FirstBootDevice = (Get-VMDvdDrive -VMName $VMName)
    }
    New-VM @Using:NewVMParam
    Set-VM @Using:SetVMParam
    Add-VMDvdDrive @Using:VMDVDParam
    Set-VMFirmware @Using:VMFirmwareParam
    Start-VM -Name $VMName

}