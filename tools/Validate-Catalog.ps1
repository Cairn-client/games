# Copyright (C) 2026 the Cairn contributors. SPDX-License-Identifier: GPL-3.0-only
<#
.SYNOPSIS
    Checks the catalog the way the launcher will read it: games.json, every games/<id>/game.json and the pictures they name.
.DESCRIPTION
    The launcher refuses a file it does not understand and keeps the last good copy, so a mistake here never breaks a launcher --
    but it does mean the change does not arrive. This script runs in CI on every push and should be run before one.
    The rules are those of Cairn.Setup/Catalog.cs in the launcher repository (ids, paths, limits); if they change there, change them here.
#>
[CmdletBinding()]
param([string] $Root = '')
if (-not $Root) { $Root = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..' }

$ErrorActionPreference = 'Stop'
$errors = New-Object System.Collections.Generic.List[string]
function Fail([string] $m) { $script:errors.Add($m) }
function Items($x) { if ($null -eq $x) { ,@() } else { ,@($x) } }

$MaxFile = 256KB
$MaxPicture = 3MB
$idRx = '^[A-Za-z0-9_-]{1,40}$'
$verRx = '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
$repoRx = '^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9._-]{1,100}$'

function Read-Json([string] $path) {
    $f = Get-Item $path
    if ($f.Length -gt $MaxFile) { Fail "$($f.Name) is larger than 256 KB"; return $null }
    try { return (Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { Fail "$path is not valid JSON: $($_.Exception.Message)"; return $null }
}
function Test-Image([string] $name) {
    if ($name.Length -eq 0 -or $name.Length -gt 100 -or $name.StartsWith('/') -or $name.Contains('..') -or $name.Contains(':') -or $name.Contains('\')) { return $false }
    if ($name -notmatch '^[A-Za-z0-9_./-]+$') { return $false }
    return @('.jpg', '.jpeg', '.png', '.webp') -contains ([IO.Path]::GetExtension($name).ToLowerInvariant())
}

$listPath = Join-Path $Root 'games.json'
$list = Read-Json $listPath
if ($null -eq $list) { $errors | % { Write-Host "FAIL  $_" -ForegroundColor Red }; exit 1 }
if ($list.schema -ne 1) { Fail 'games.json: schema must be 1' }

$components = @{}
if ($list.components) { foreach ($p in $list.components.PSObject.Properties) { $components[$p.Name] = $p.Value } }
foreach ($k in $components.Keys) {
    $c = $components[$k]
    if ($k -notmatch $idRx) { Fail "component '$k': not a plain id" }
    if (-not $c.name) { Fail "component '$k': no name" }
    if ($c.kind -notmatch $idRx) { Fail "component '$k': no kind" }
    if ($c.kind -eq 'steam-app' -and -not ($c.appId -is [int] -or $c.appId -is [long])) { Fail "component '$k': a steam-app needs an appId" }
}

$ids = @{}
foreach ($g in (Items $list.games)) {
    if ($g.id -notmatch $idRx) { Fail "games.json: '$($g.id)' is not a plain id"; continue }
    if ($ids.ContainsKey($g.id)) { Fail "games.json: '$($g.id)' is listed twice" }
    $ids[$g.id] = $g
    if ($g.repo -and $g.repo -notmatch $repoRx) { Fail "games.json: '$($g.id)' has a bad repo '$($g.repo)'" }
}
foreach ($p in (Items $list.packs)) { if ($p.id -notmatch $idRx -or $p.repo -notmatch $repoRx) { Fail "games.json: bad pack entry '$($p.id)'" } }
foreach ($b in (Items $list.blocked)) {
    if ($b.pack -notmatch $idRx) { Fail "blocked: bad pack '$($b.pack)'" }
    $hasV = [bool]$b.version; $hasM = [bool]$b.max
    if ($hasV -eq $hasM) { Fail "blocked '$($b.pack)': give either version or max" }
    if ($hasV -and $b.version -notmatch $verRx) { Fail "blocked '$($b.pack)': bad version" }
    if ($hasM -and $b.max -notmatch $verRx) { Fail "blocked '$($b.pack)': bad max" }
}
$noticeIds = @{}
foreach ($n in (Items $list.notices)) {
    if ($n.id -notmatch $idRx) { Fail "notice '$($n.id)': not a plain id" }
    if ($noticeIds.ContainsKey($n.id)) { Fail "notice '$($n.id)': listed twice" }
    $noticeIds[$n.id] = $true
    if (-not $n.title) { Fail "notice '$($n.id)': no title" }
    if ($n.kind -and @('known-issue', 'news') -notcontains $n.kind) { Fail "notice '$($n.id)': kind must be known-issue or news" }
    foreach ($v in @($n.fromLauncher, $n.untilLauncher)) { if ($v -and $v -notmatch $verRx) { Fail "notice '$($n.id)': bad launcher version '$v'" } }
    foreach ($gid in (Items $n.games)) { if (-not $ids.ContainsKey($gid)) { Fail "notice '$($n.id)': unknown game '$gid'" } }
}

# every game folder is listed, and every listed game has either a folder or a repository that publishes its game.json
$gamesDir = Join-Path $Root 'games'
$dirs = if (Test-Path $gamesDir) { Get-ChildItem $gamesDir -Directory } else { @() }
foreach ($d in $dirs) { if (-not $ids.ContainsKey($d.Name)) { Fail "games/$($d.Name) is not listed in games.json" } }
foreach ($id in $ids.Keys) {
    $dir = Join-Path $gamesDir $id
    if (-not (Test-Path $dir)) { if (-not $ids[$id].repo) { Fail "'$id' has neither a games/$id folder nor a repo" }; continue }
    $gp = Join-Path $dir 'game.json'
    if (-not (Test-Path $gp)) { Fail "games/$id has no game.json"; continue }
    $m = Read-Json $gp
    if ($null -eq $m) { continue }
    if ($m.schema -ne 1) { Fail "games/$id/game.json: schema must be 1" }
    if ($m.id -ne $id) { Fail "games/$id/game.json: id is '$($m.id)'" }
    if (-not $m.name) { Fail "games/$id/game.json: no name" }
    if ($m.accent -and $m.accent -notmatch '^#[0-9A-Fa-f]{6}$') { Fail "games/$id/game.json: bad accent" }
    if ($m.exe -and ($m.exe -notmatch '^[A-Za-z0-9._ -]{1,80}$' -or $m.exe.Contains('..'))) { Fail "games/$id/game.json: bad exe" }
    $pics = @()
    if ($m.images) {
        foreach ($k in 'background', 'logo', 'hero', 'poster') { if ($m.images.$k) { $pics += $m.images.$k } }
        $pics += (Items $m.images.screenshots)
        if ((Items $m.images.screenshots).Count -gt 8) { Fail "games/$id/game.json: more than 8 screenshots" }
    }
    foreach ($pic in $pics) {
        if (-not (Test-Image $pic)) { Fail "games/$id/game.json: '$pic' is not a plain picture file name"; continue }
        $fp = Join-Path $dir $pic
        if (-not (Test-Path $fp)) { Fail "games/$id/game.json names $pic, which is not in the folder"; continue }
        if ((Get-Item $fp).Length -gt $MaxPicture) { Fail "games/$id/$pic is larger than 3 MB" }
    }
    foreach ($req in (Items $m.requires)) {
        if ($req -is [string]) { if (-not $components.ContainsKey($req)) { Fail "games/$id/game.json requires '$req', which games.json does not define" } }
        elseif ($req -and -not ($req.id -and $req.kind -and $req.name)) { Fail "games/$id/game.json: an inline requirement needs id, kind and name" }
    }
    foreach ($grp in (Items $m.features)) {
        if (-not $grp.title) { Fail "games/$id/game.json: a feature group has no title" }
        foreach ($f in (Items $grp.items)) {
            if (-not $f.name) { Fail "games/$id/game.json: a feature has no name" }
            if ($f.status -and @('ready', 'inTest', 'planned') -notcontains $f.status) { Fail "games/$id/game.json: feature status '$($f.status)'" }
        }
    }
    foreach ($c in (Items $m.content)) { if ($c -notmatch $idRx) { Fail "games/$id/game.json: bad content id '$c'" } }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host "FAIL  $_" -ForegroundColor Red }
    Write-Host "$($errors.Count) problem(s)" -ForegroundColor Red
    exit 1
}
Write-Host ("OK    {0} game(s), {1} component(s), {2} blocked, {3} notice(s)" -f $ids.Count, $components.Count, (Items $list.blocked).Count, (Items $list.notices).Count) -ForegroundColor Green
