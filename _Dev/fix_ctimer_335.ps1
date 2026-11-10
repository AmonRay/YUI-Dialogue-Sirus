# Redirects retail dot-style C_Timer.X(...) calls to the addon-local DUI_C_Timer (see Compat_335.lua).
# Sirus' C_Timer uses colon methods, so C_Timer.After(d, f) breaks there.
$root = Split-Path -Parent $PSScriptRoot
$enc = New-Object System.Text.UTF8Encoding($false)
$total = 0
Get-ChildItem -Path $root -Recurse -Filter *.lua | Where-Object {
    $_.FullName -notmatch '\\(_Build|\.git|_Dev)\\' -and $_.Name -ne 'Compat_335.lua'
} | ForEach-Object {
    $text = [IO.File]::ReadAllText($_.FullName)
    $count = ([regex]::Matches($text, '(?<![\w\.])C_Timer\.')).Count
    if ($count -gt 0) {
        $new = [regex]::Replace($text, '(?<![\w\.])C_Timer\.', 'DUI_C_Timer.')
        [IO.File]::WriteAllText($_.FullName, $new, $enc)
        Write-Output ("{0}: {1}" -f $_.FullName.Substring($root.Length + 1), $count)
        $total += $count
    }
}
Write-Output "Total: $total"
