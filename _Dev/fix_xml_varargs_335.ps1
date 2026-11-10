# 3.3.5a: inline XML script handlers are NOT vararg functions (except OnEvent),
# so '...' is a compile error. Replace it with the handler's named arguments.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$args335 = @{
    'OnLoad' = ''; 'OnShow' = ''; 'OnHide' = '';
    'OnEnter' = 'motion'; 'OnLeave' = 'motion';
    'OnClick' = 'button, down'; 'PreClick' = 'button, down'; 'PostClick' = 'button, down';
    'OnDoubleClick' = 'button';
    'OnMouseDown' = 'button'; 'OnMouseUp' = 'button';
    'OnMouseWheel' = 'delta'; 'OnKeyDown' = 'key'; 'OnKeyUp' = 'key'; 'OnChar' = 'text';
    'OnUpdate' = 'elapsed'; 'OnSizeChanged' = 'w, h'; 'OnValueChanged' = 'value';
    'OnTextChanged' = 'userInput'; 'OnEditFocusGained' = ''; 'OnEditFocusLost' = '';
    'OnEnterPressed' = ''; 'OnEscapePressed' = ''; 'OnTabPressed' = '';
    'OnDragStart' = 'button'; 'OnDragStop' = ''; 'OnReceiveDrag' = '';
    'OnHyperlinkEnter' = 'link, text'; 'OnHyperlinkLeave' = ''; 'OnHyperlinkClick' = 'link, text, button';
    'OnVerticalScroll' = 'offset'; 'OnHorizontalScroll' = 'offset'; 'OnScrollRangeChanged' = 'xrange, yrange';
    'OnAnimFinished' = ''; 'OnModelLoaded' = '';
}
$total = 0
Get-ChildItem -Path $root -Recurse -Filter *.xml | Where-Object { $_.FullName -notmatch '\\(_Build|\.git)\\' } | ForEach-Object {
    $file = $_.FullName
    $text = [System.IO.File]::ReadAllText($file)
    $count = 0
    $new = [regex]::Replace($text, '<(On\w+|PreClick|PostClick)>(.*?)</\1>', {
        param($m)
        $name = $m.Groups[1].Value
        $body = $m.Groups[2].Value
        if ($name -eq 'OnEvent' -or -not $body.Contains('...') -or -not $args335.ContainsKey($name)) { return $m.Value }
        $a = $args335[$name]
        # 'f(...)' -> 'f(a, b)' or 'f()' ; ', ...' leftovers -> ', a, b' or ''
        $body = $body.Replace('(...)', "($a)")
        if ($a -eq '') { $body = $body.Replace(', ...', '') } else { $body = $body.Replace('...', $a) }
        $script:count++
        return "<$name>$body</$name>"
    }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($count -gt 0) {
        [System.IO.File]::WriteAllText($file, $new, (New-Object System.Text.UTF8Encoding($false)))
        "{0}: {1} handler(s)" -f $file.Substring($root.Length + 1), $count
        $total += $count
    }
}
"Total: $total"
