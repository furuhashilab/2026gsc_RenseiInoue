# Builds the Shinjuku mockup from the template and the compact OSM data.
#   -DataDir : folder holding shinjuku-data.json and roads-data.json
#   -Out     : artifact version (body only)  /  -PagesOut : standalone HTML for GitHub Pages
param([string]$DataDir, [string]$Out, [string]$PagesOut)
$enc = New-Object Text.UTF8Encoding $false
# resolve relative paths against the current PowerShell location (.NET file APIs do not)
$abs = { param($p) if ($p) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p) } }
$DataDir = & $abs $DataDir; $Out = & $abs $Out; $PagesOut = & $abs $PagesOut
$tpl = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'shinjuku-template.html'), $enc)
$d = [IO.File]::ReadAllText((Join-Path $DataDir 'shinjuku-data.json'), $enc).Replace('</', '<\/')
$r = [IO.File]::ReadAllText((Join-Path $DataDir 'roads-data.json'), $enc).Replace('</', '<\/')
$body = $tpl.Replace('/*__DATA__*/', $d).Replace('/*__ROADS__*/', $r)
if ($Out) { [IO.File]::WriteAllText($Out, $body, $enc) }
if ($PagesOut) {
  $page = $body.Replace('<meta name="claude:viewport-fit-sides" content="cover">', '')
  $i = $page.IndexOf('<div class="app"')
  $head = $page.Substring(0, $i); $rest = $page.Substring($i)
  $html = "<!doctype html>`n<html lang=`"ja`">`n<head>`n<meta charset=`"utf-8`">`n<meta name=`"viewport`" content=`"width=1280`">`n<meta name=`"description`" content=`"新宿駅周辺のOpenStreetMapデータを3Dと2D（階の平面図）で表示する、立体アクセシビリティ表示案のモックアップ`">`n<style>body{margin:0}[hidden]{display:none!important}</style>`n$head</head>`n<body>`n$rest`n</body>`n</html>`n"
  New-Item -ItemType Directory -Force (Split-Path $PagesOut) | Out-Null
  [IO.File]::WriteAllText($PagesOut, $html, $enc)
}
"built"
