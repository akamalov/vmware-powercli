<#
    .SYNOPSIS 
    Configure shares parameters for system traffic with distributed switchs and Network I/O control.
    .DESCRIPTION
    You can use Network I/O Control on a distributed switch to configure bandwidth allocation for the traffic that is related to the main system features in vSphere:
    - Management
    - Fault Tolerance
    - iSCSI
    - NFS
    - Virtual SAN
    - vMotion
    - vSphere Replication
    - vSphere Data Protection Backup
    - Virtual machine
    With this function you'll be able to configure shares for system traffic.
    The amount of bandwidth available to a system traffic type is determined by its relative shares and by the amount of data that the other system features are transmitting. 
    .NOTES
    Written by Erwan Quelin under MIT licence.
    .PARAMETER VDS
    VDS name or object.
    .PARAMETER Type
    Traffic type (management, vmotion, vsan...).
    .PARAMETER Share
    Shares (low, normal, high or custom).
    .PARAMETER Value
    Value of th custom share.
    .EXAMPLE
    Set-VDSInfrastructureTrafficResourceConfig.ps1 -VDS 'VDS01' -Type 'vsan' -Shares 'high'

    Set the 'vsan' traffic resource config to 'normal'.
    .EXAMPLE
    Set-VDSInfrastructureTrafficResourceConfig.ps1 -VDS 'VDS01' -Type 'vsan' -Shares 'custom' -Value 150

    Set the 'vsan' traffic resource config to a 'custom' value of 150.
    .EXAMPLE
    Get-VDSwitch -Name VDS01 | Set-VDSInfrastructureTrafficResourceConfig.ps1 -Type vdp -Shares low

    Set the 'vdp' traffic resource config to 'low' by providing the VDS through a pipeline. 
#>

Function Set-VDSInfrastructureTrafficResourceConfig {
    [CmdletBinding(SupportsShouldProcess = $True,ConfirmImpact = 'High')]
    Param (
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [Object]$VDS,
        [Parameter(Mandatory=$true)]
        [ValidateSet('management','faultTolerance','vmotion','virtualMachine','iSCSI','nfs','hbr','vsan','vdp')]
        [String]$Type,
        [Parameter(Mandatory=$true)]
        [ValidateSet('low','normal','high','custom')]
        [String]$Share,
        [Parameter(Mandatory=$false)]
        [uint32]$Value
    )

    Switch ($VDS.GetType().Name) {
        'String' {$VDS = Get-VDSwitch -Name $VDS -ErrorAction SilentlyContinue}
        'VmwareVDSwitchImpl' {$VDS = Get-VDSwitch -Name $VDS -ErrorAction SilentlyContinue}
        default {Throw 'Please provide an valid VDS name or object'} 
    }

    If (Get-VDSwitch -Name $VDS.Name -ErrorAction SilentlyContinue) {

        #Creates DVSConfigSpec object
        $DVSConfigSpec = New-Object vmware.vim.DVSConfigSpec

        #Retrieves actual config version of the VDS
        $DVSConfigSpec.ConfigVersion = $VDS.ExtensionData.Config.ConfigVersion

        #Retrieves actual configuration
        $DVSConfigSpec.InfrastructureTrafficResourceConfig = $VDS.ExtensionData.Config.InfrastructureTrafficResourceConfig

        #Modify the traffic resource config with informations provided by parameters
        ($DVSConfigSpec.InfrastructureTrafficResourceConfig | where-object {$_.key -match $Type}).AllocationInfo.Shares.Level = $Share

        #Set the value of the custom share if specified
        If ($Share -eq 'custom') {
            ($DVSConfigSpec.InfrastructureTrafficResourceConfig | where-object {$_.key -match $Type}).AllocationInfo.Shares.Shares = $Value
        }

        #Reconfigure the DVS
        If ($pscmdlet.ShouldProcess($VDS.Name,"Modify traffic $Type with value $Share")) {
            Try {
                $VDS.ExtensionData.ReconfigureDvs($DVSConfigSpec)
            }
            Catch {
                Throw $_
            }
        }
        
        #Return VDS object
        Get-VDSwitch -Name $VDS.Name
    }
}