param([string]$In, [string]$Out)
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = [int]::MaxValue
$raw = [IO.File]::ReadAllText($In, [Text.Encoding]::UTF8)
$j = $ser.DeserializeObject($raw)
$lat0 = 35.6910; $lon0 = 139.6997
$MLAT = 111320.0; $MLON = 111320.0 * [Math]::Cos($lat0 * [Math]::PI / 180)
$inv = [Globalization.CultureInfo]::InvariantCulture
function P($lat, $lon) { [double[]]@([Math]::Round(([double]$lon - $lon0) * $MLON, 1), [Math]::Round(-([double]$lat - $lat0) * $MLAT, 1)) }
function T($t, $k) { if ($t -and $t.ContainsKey($k)) { [string]$t[$k] } else { $null } }

$B = New-Object System.Collections.ArrayList
$I = New-Object System.Collections.ArrayList
$Pt = New-Object System.Collections.ArrayList
$seen = @{}
$keep = 'name','name:en','wheelchair','wheelchair:description','toilets:wheelchair','level','repeat_on','amenity','shop','highway','entrance','door','railway','public_transport','operator','opening_hours','indoor','ref','step_count','ramp','automatic_door','width','check_date','cuisine','tourism','office','building'

foreach ($e in $j['elements']) {
  $t = $e['tags']; $type = $e['type']; $key = "$type/$($e['id'])"
  $isB = $t -and ($t.ContainsKey('building') -or $t.ContainsKey('building:part'))
  $ind = T $t 'indoor'
  if ($isB -and $e.ContainsKey('geometry') -and $type -eq 'way') {
    if ($seen.ContainsKey("b$key")) { continue }; $seen["b$key"] = 1
    $c = New-Object 'System.Collections.Generic.List[double]'
    foreach ($g in $e['geometry']) { $p = P $g['lat'] $g['lon']; [void]$c.Add($p[0]); [void]$c.Add($p[1]) }
    $lv = T $t 'building:levels'; $h = T $t 'height'; $ml = T $t 'building:min_level'; $mh = T $t 'min_height'; $ug = T $t 'building:levels:underground'
    [void]$B.Add(@($key, (T $t 'name'), $lv, $h, $ml, $mh, $ug, [int]($t.ContainsKey('building:part')), $c))
  }
  elseif ($isB -and $type -eq 'relation' -and $e.ContainsKey('members')) {
    foreach ($m in $e['members']) {
      if ($m['role'] -ne 'outer' -or -not $m.ContainsKey('geometry')) { continue }
      $c = New-Object 'System.Collections.Generic.List[double]'
      foreach ($g in $m['geometry']) { if ($g) { $p = P $g['lat'] $g['lon']; [void]$c.Add($p[0]); [void]$c.Add($p[1]) } }
      [void]$B.Add(@($key, (T $t 'name'), (T $t 'building:levels'), (T $t 'height'), (T $t 'building:min_level'), (T $t 'min_height'), (T $t 'building:levels:underground'), 0, $c))
    }
  }
  elseif ($ind -and $e.ContainsKey('geometry') -and $type -eq 'way') {
    if ($seen.ContainsKey("i$key")) { continue }; $seen["i$key"] = 1
    $lvl = T $t 'level'; if (-not $lvl) { continue }
    if ($ind -notin @('room','area','corridor','wall','footway','highway','yes','column','door')) { continue }
    $c = New-Object 'System.Collections.Generic.List[double]'
    foreach ($g in $e['geometry']) { $p = P $g['lat'] $g['lon']; [void]$c.Add($p[0]); [void]$c.Add($p[1]) }
    $nm = T $t 'name'; if (-not $nm) { $nm = T $t 'shop'; if ($nm) { $nm = '' } }
    $sub = ''
    if ($t.ContainsKey('shop')) { $sub = 'shop' } elseif ($t.ContainsKey('amenity')) { $sub = [string]$t['amenity'] } elseif ($t.ContainsKey('railway')) { $sub = [string]$t['railway'] }
    [void]$I.Add(@($ind, $lvl, (T $t 'name'), $sub, $c))
  }
  if ($t -and -not $isB -and ($t.ContainsKey('wheelchair') -or (T $t 'highway') -eq 'elevator' -or $t.ContainsKey('entrance') -or (T $t 'amenity') -eq 'toilets')) {
    if ($seen.ContainsKey("p$key")) { continue }; $seen["p$key"] = 1
    if ($type -eq 'node') { $lat = $e['lat']; $lon = $e['lon'] }
    elseif ($e.ContainsKey('center')) { $lat = $e['center']['lat']; $lon = $e['center']['lon'] }
    elseif ($e.ContainsKey('geometry')) { $gs = @($e['geometry']); $lat = ($gs | % { $_['lat'] } | measure -Average).Average; $lon = ($gs | % { $_['lon'] } | measure -Average).Average }
    else { continue }
    $p = P $lat $lon
    $tg = @{}; foreach ($k in $keep) { if ($t.ContainsKey($k)) { $tg[$k] = [string]$t[$k] } }
    [void]$Pt.Add(@($key, [double]$p[0], [double]$p[1], $tg))
  }
}
$outObj = @{ o = @($lat0, $lon0); b = $B; i = $I; p = $Pt; date = (Get-Date -Format 'yyyy-MM-dd') }
. (Join-Path $PSScriptRoot "tail.ps1")
[IO.File]::WriteAllText($Out, $json, (New-Object Text.UTF8Encoding $false))
"buildings $($B.Count) indoor $($I.Count) pois $($Pt.Count) bytes $($json.Length)"
