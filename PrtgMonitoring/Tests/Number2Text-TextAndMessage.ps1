function Get-TextualForNumber{
    param(
        [Parameter(Mandatory=$true)]
        [int]$number
    )
    $rv = "unknown"
    $textualNumbers01 = @("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen")
    $textualNumbers10 = @("twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety")
    if ($number -lt 20) {
        $rv = $textualNumbers01[$number]
    }
    elseif ($number -lt 100) {
        $nr01 = $number % 10
        $nr10 = ($number - $nr01)/10
        $rv = "{0}{1}" -f $textualNumbers10[$nr10-2], $textualNumbers01[$nr01]
    }
    $rv
}

$minute = (get-date).Minute

$txt = Get-TextualForNumber -number $minute
"0:{1}:{2}" -f $minute, $txt
