# https://docs.microsoft.com/en-us/dotnet/standard/base-types/standard-numeric-format-strings?redirectedfrom=MSDN

$nr = 20/3

Write-Host("{0} no format" -f $nr)
Write-Host("{0:c} currency, regional" -f $nr)
Write-Host("{0:e3} exponent, regional" -f $nr)
Write-Host("{0:f3} fixed point, regional" -f $nr)
Write-Host("{0:g3} scientific, regional" -f $nr)
Write-Host("{0:n2} 1000-sep, regional" -f $nr)
Write-Host("{0:r17} roundtrip" -f $nr)
Write-Host("{0:x} hex (=66)" -f 166)

