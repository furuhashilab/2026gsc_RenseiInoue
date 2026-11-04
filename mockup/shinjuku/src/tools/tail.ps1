function J($v) {
  if ($null -eq $v) { return 'null' }
  if ($v -is [System.Management.Automation.PSObject]) { $v = $v.psobject.BaseObject }
  if ($v -is [string]) { return $ser.Serialize($v) }
  if ($v -is [double] -or $v -is [int] -or $v -is [decimal] -or $v -is [long]) { return ([double]$v).ToString('R', $inv) }
  if ($v -is [System.Collections.IDictionary]) { return '{' + (($v.Keys | % { $ser.Serialize([string]$_) + ':' + (J $v[$_]) }) -join ',') + '}' }
  if ($v -is [System.Collections.IEnumerable]) { $parts = foreach ($x in $v) { J $x }; return '[' + ($parts -join ',') + ']' }
  return $ser.Serialize([string]$v)
}
$json = J $outObj
