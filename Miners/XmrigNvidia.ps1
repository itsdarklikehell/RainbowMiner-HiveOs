﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\NVIDIA-Xmrig\xmrig-nvidia.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.8.1-xmrignvidia/xmrig-nvidia-2.8.1-cuda-9_2-win64-rbm.zip"
$Port = "303{0:d2}"
$DevFee = 0.0
$Cuda = "9.2"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cryptonight/1"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/2"; Params = "--bfactor=12"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/msr"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/rto"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xao"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xtl"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/0"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/1"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/ipbc"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/tube"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/xhv"; Params = ""}
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
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

if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}

$Session.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','

    $Commands | ForEach-Object {
        
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            $xmrig_algo = if ($_.MainAlgorithm -eq "cryptonightv7") {"cryptonight"} else {$_.MainAlgorithm}
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path      = $Path
                Arguments = "-R 1 --cuda-devices=$($DeviceIDsAll) --api-port $($Miner_Port) -a $($xmrig_algo) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --keepalive $(if ($Pools.$Algorithm_Norm.Name -eq "NiceHash") {"--nicehash"}) --donate-level=0 $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API       = "XMRig"
                Port      = $Miner_Port
                Uri       = $Uri
                DevFee    = $DevFee
                ManualUri = $ManualUri
            }
        }
    }
}