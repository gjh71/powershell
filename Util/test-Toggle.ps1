function testToggle{
    param(
        [switch]$toggle
    )
    Write-host("toggle: {0}" -f $toggle)
}


testToggle
testToggle -toggle
