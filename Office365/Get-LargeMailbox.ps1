#Requires -Module ExchangeOnlineManagement
[CmdletBinding()]

# Set the threshold size. Change this to your preferred value.
$size_Threshold_GB = 40

# Get a list of all mailboxes
$mailbox_List = Get-EXOMailbox -ResultSize Unlimited | Select-Object DisplayName, PrimarySMTPAddress, UserPrincipalName

# Create an empty array to hold the report
$finalResult = @()

# Loop through each of the mailbox object inside the $mailbox_List variable.
foreach ($mailbox in $mailbox_List) {
    # Get the Mailbox Size in GB, rounded with two-decimal places
    $mailbox_size_GB = [math]::Round(((Get-EXOMailboxStatistics -Identity $mailbox.UserPrincipalName).TotalItemSize.Value.toBytes() / 1GB),2)

    <#
    Compare the mailbox size with the configured threshold.
    If the mailbox size is bigger than the threshold, add the result to the report.
    #>

    Write-Verbose("{0} : {1}gb" -f $mailbox.DisplayName, $mailbox_size_GB)
    if ($mailbox_size_GB -gt $size_Threshold_GB) {

        <#
        Create the object with properties 'Display Name', 'Email Address' and 'Mailbox Size (GB)'
        Then add it to the final report.
        #>
        $finalResult += (
            New-Object psobject -Property @{
                'Display Name'      = $mailbox.DisplayName
                'Email Address'     = $mailbox.PrimarySMTPAddress
                'Mailbox Size (GB)' = $mailbox_size_GB
            }
        )
    }
}

# return the final result
return $finalResult