param([string]$In, [string]$Out)
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = [int]::MaxValue
$inv = [Globalization.CultureInfo]::InvariantCulture
$j = $ser.DeserializeObject([IO.File]::ReadAllText($In, [Text.Encoding]::UTF8))
$lat0 = 35.6910; $lon0 = 139.6997
$MLAT = 111320.0; $MLON = 111320.0 * [Math]::Cos($lat0 * [Math]::PI / 180)
$R = New-Object System.Collections.ArrayList
foreach ($e in $j['elements']) {
  $t = $e['tags']
  $k = if ($t.ContainsKey('railway')) { 'rail' } else { [string]$t['highway'] }
  $w = switch -regex ($k) { '^(motorway|trunk|primary)' { 14 } '^secondary' { 11 } '^tertiary' { 9 } 'rail' { 3 } default { 6 } }
  if ($t.ContainsKey('bridge') -or $t.ContainsKey('layer') -and [int]("0"+($t['layer'] -replace '[^0-9]','')) -gt 0) { $br = 1 } else { $br = 0 }
  $c = New-Object 'System.Collections.Generic.List[double]'
  foreach ($g in $e['geometry']) { $c.Add([Math]::Round(([double]$g['lon'] - $lon0) * $MLON, 1)); $c.Add([Math]::Round(-([double]$g['lat'] - $lat0) * $MLAT, 1)) }
  [void]$R.Add(@($k, $w, $c))
}
$outObj = $R
. (Join-Path $PSScriptRoot "tail.ps1")
[IO.File]::WriteAllText($Out, $json, (New-Object Text.UTF8Encoding $false))
"roads $($R.Count) bytes $($json.Length)"
