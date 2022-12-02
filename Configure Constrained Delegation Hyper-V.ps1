$Host1 = "Host 1"
$Host2 = "Host 2"

$H1Spns = @("Microsoft Virtual System Migration Service/$Host1", "cifs/$Host1")
$H2Spns = @("Microsoft Virtual System Migration Service/$Host2", "cifs/$Host2")

$DelegationProperty = "msDS-AllowedToDelegateTo"
$delegateToSpns = $H1Spns + $H2Spns

$H1Account = Get-ADComputer $Host1
$H1Account | Set-ADObject -Add @{$DelegationProperty=$delegateToSpns}
Set-ADAccountControl $H1Account -TrustedToAuthForDelegation $true 


$H2Account = Get-ADComputer $Host2
$H2Account | Set-ADObject -Add @{$DelegationProperty=$delegateToSpns}
Set-ADAccountControl $H2Account -TrustedToAuthForDelegation $true 