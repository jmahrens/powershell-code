$Credential = Get-Credential -Message 'Domain credentials'
Add-Computer -DomainName 'contoso.com' -OUPath 'OU=Computers,DC=Contoso,DC=com' -Credential $Credential