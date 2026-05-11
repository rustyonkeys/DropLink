param(
    [string]$ProgramPath = ""
)

$ErrorActionPreference = "Stop"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    throw "Run this script from an Administrator PowerShell window."
}

$rules = @(
    @{
        Name = "DropLink UDP Discovery"
        Protocol = "UDP"
        LocalPort = "45870"
    },
    @{
        Name = "DropLink HTTP Transfer"
        Protocol = "TCP"
        LocalPort = "45871"
    }
)

foreach ($rule in $rules) {
    $existing = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
    if ($existing) {
        $existing | Remove-NetFirewallRule
    }

    $params = @{
        DisplayName = $rule.Name
        Direction = "Inbound"
        Action = "Allow"
        Protocol = $rule.Protocol
        LocalPort = $rule.LocalPort
        Profile = "Private"
    }

    if ($ProgramPath) {
        $params.Program = (Resolve-Path $ProgramPath).Path
    }

    New-NetFirewallRule @params | Out-Null
    Write-Host "Allowed $($rule.Protocol) port $($rule.LocalPort) on Private networks."
}

Write-Host "DropLink firewall rules are ready." -ForegroundColor Green
