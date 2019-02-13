﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\AMD-SgminerMTP\sgminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.1.0-sgminermtp/sgminermtp-0.1.0.zip"
$ManualUri = "https://github.com/zcoinofficial/sgminer/releases"
$Port = "411{0:d2}"
$DevFee = 0.0

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "mtp"; Params = "--kernel mtp --worksize 64 -I 20"; ParamsVega = "--kernel mtp_nvidia4 --worksize 64 -I 22"}    
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Session.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
    $Miner_PlatformId = $Miner_Device | Select -Property Platformid -Unique -ExpandProperty PlatformId

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
            [PSCustomObject]@{
                Name        = $Miner_Name
                DeviceName  = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path        = $Path
                Arguments   = "$($_."Params$(if ($Miner_Model -match "(gfx900|vega)") {"Vega"})") --device $($DeviceIDsAll) --api-port $($Miner_Port) --api-listen -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --gpu-platform $($Miner_PlatformId)"
                HashRates   = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API         = "Xgminer"
                Port        = $Miner_Port
                Uri         = $Uri
                DevFee      = $DevFee
                ManualUri   = $ManualUri
                EnvVars     = @("GPU_FORCE_64BIT_PTR=0")
            }
        }
    }
}