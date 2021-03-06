$ErrorActionPreference = "Stop"

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $NodeName,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $Credential
    )

    $cimSession = Get-CimSession $NodeName $Credential
    $ret = Test-RemoteConfiguration $cimSession

    return @{
        NodeName = $NodeName
        InDesiredState = $ret.InDesiredState
    }
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $NodeName,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $NodeName,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    $cimSession = Get-CimSession $NodeName $Credential

    do
    {
        # TODO: add a timeout
        $ret = Test-RemoteConfiguration $cimSession
        if (!$ret.InDesiredState)
        {
            Start-Sleep -Seconds 1
        }
    }
    until($ret.InDesiredState)

    return $true
}


function Get-CimSession
{
    param
    (
        [ValidateNotNullOrEmpty()]
        [System.String]
        $NodeName,

        [System.Management.Automation.PSCredential]
        $Credential
    )

    # TODO: Add params for the SSL "skip" options, authentication and port
    $opt = New-CimSessionOption -UseSsl:$true -SkipCACheck:$true -SkipCNCheck:$true -SkipRevocationCheck:$true
    return New-CimSession -Credential:$Credential -ComputerName:$NodeName -Port:5986 -Authentication:basic -SessionOption:$opt
}


function Test-RemoteConfiguration
{
    param (
       [ValidateNotNull()]
       [Microsoft.Management.Infrastructure.CimSession]
       $cimSession
    )

    while($true)
    {
        try
        {
            $ret = Invoke-CimMethod -CimSession $cimSession -Namespace root/microsoft/windows/DesiredStateConfiguration `
                                                      -ClassName MSFT_DSCLocalConfigurationManager -Name TestConfiguration
            return $ret
        }
        catch
        {
            if ($_.FullyQualifiedErrorId -ne "OMI:MI_Result:1,Microsoft.Management.Infrastructure.CimCmdlets.InvokeCimMethodCommand")
            {
                throw
            }

            Write-Debug "Cannot call MSFT_DSCLocalConfigurationManager.TestConfiguration on ($cimSession.ComputerName) as an operation is in progress, retrying"
            Write-Debug $_
            Start-Sleep -Seconds 1
        }
    }
}


Export-ModuleMember -Function *-TargetResource
