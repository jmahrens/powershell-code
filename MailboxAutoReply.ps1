$Identity = "user@contoso.com"
$Message = ""
$Start = "8/21/2023 08:00:00"
$End = "8/28/2023 23:00:00"

Connect-ExchangeOnline
Set-MailboxAutoReplyConfiguration -Identity $Identity -AutoReplyState Scheduled -StartTime $Start -EndTime $End -InternalMessage $Message -ExternalMessage $Message -ExternalAudience All