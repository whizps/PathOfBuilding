param(
	[Parameter(Mandatory = $true)][string]$PoBDir,
	[string]$PayloadDir = (Join-Path $PSScriptRoot "payload"),
	[switch]$Uninstall
)

$ErrorActionPreference = "Stop"

function Find-ScriptDir([string]$dir) {
	foreach ($candidate in @($dir, (Join-Path $dir "src"))) {
		if ((Test-Path (Join-Path $candidate "Launch.lua")) -and (Test-Path (Join-Path $candidate "Modules/Build.lua"))) {
			return (Resolve-Path $candidate).Path
		}
	}
	throw "Path of Building was not found in '$dir'. Choose the folder that contains 'Path of Building.exe'."
}

function Get-Style([string]$scriptDir) {
	$common = Get-Content -Raw -Path (Join-Path $scriptDir "Modules/Common.lua")
	if ($common -match "function new\(className, extraArg\)") { return "modern" }
	if ($common -match "function new\(className, \.\.\.\)") { return "legacy" }
	throw "This version of Path of Building uses an unknown class system. The Atlas patch needs an update."
}

function Read-Lines([string]$path) {
	$text = [System.IO.File]::ReadAllText($path)
	$eol = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
	$lines = [System.Collections.Generic.List[string]]::new()
	foreach ($line in ($text -split "`r?`n")) { $lines.Add($line) }
	return @{ Lines = $lines; Eol = $eol }
}

function Write-Lines([string]$path, $doc) {
	$text = [string]::Join($doc.Eol, $doc.Lines)
	[System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))
}

function Find-Single($lines, [scriptblock]$predicate, [string]$what) {
	$found = @()
	for ($i = 0; $i -lt $lines.Count; $i++) {
		if (& $predicate $lines[$i]) { $found += $i }
	}
	if ($found.Count -ne 1) {
		throw "Could not find a unique match for '$what' ($($found.Count) matches). This Path of Building version is not supported by this patch yet."
	}
	return $found[0]
}

function Apply-Ops($lines, $ops) {
	foreach ($op in $ops) {
		switch ($op.type) {
			"insertAfter" {
				$anchor = $op.anchor.Trim()
				$index = Find-Single $lines { param($l) $l.Trim() -eq $anchor } $anchor
				$lines.InsertRange($index + 1, [string[]]$op.lines)
			}
			"insertBefore" {
				$anchor = $op.anchor.Trim()
				$index = Find-Single $lines { param($l) $l.Trim() -eq $anchor } $anchor
				$lines.InsertRange($index, [string[]]$op.lines)
			}
			"replace" {
				$old = $op.old.Trim()
				$index = Find-Single $lines { param($l) $l.Trim() -eq $old } $old
				$lines[$index] = $op.new
			}
			"append" {
				$suffix = $op.suffix
				$index = Find-Single $lines { param($l) $l.TrimEnd().EndsWith($suffix) } $suffix
				$lines[$index] = $lines[$index].TrimEnd() + $op.text
			}
		}
	}
}

function Revert-Ops($lines, $ops) {
	$reversed = @($ops)
	[array]::Reverse($reversed)
	foreach ($op in $reversed) {
		switch ($op.type) {
			{ $_ -in "insertAfter", "insertBefore" } {
				$first = $op.lines[0].Trim()
				for ($i = 0; $i -lt $lines.Count; $i++) {
					if ($lines[$i].Trim() -eq $first) {
						$match = $true
						for ($j = 0; $j -lt $op.lines.Count; $j++) {
							if ($i + $j -ge $lines.Count -or $lines[$i + $j].Trim() -ne $op.lines[$j].Trim()) { $match = $false; break }
						}
						if ($match) { $lines.RemoveRange($i, $op.lines.Count); break }
					}
				}
			}
			"replace" {
				$new = $op.new.Trim()
				for ($i = 0; $i -lt $lines.Count; $i++) {
					if ($lines[$i].Trim() -eq $new) { $lines[$i] = $op.old; break }
				}
			}
			"append" {
				for ($i = 0; $i -lt $lines.Count; $i++) {
					if ($lines[$i].TrimEnd().EndsWith($op.text.TrimEnd())) {
						$trimmed = $lines[$i].TrimEnd()
						$lines[$i] = $trimmed.Substring(0, $trimmed.Length - $op.text.TrimEnd().Length)
						break
					}
				}
			}
		}
	}
}

$scriptDir = Find-ScriptDir $PoBDir
$style = Get-Style $scriptDir
$hooks = Get-Content -Raw -Path (Join-Path $PayloadDir "hooks.json") | ConvertFrom-Json
$styleHooks = $hooks.$style
$files = @{}
foreach ($property in $hooks.markers.PSObject.Properties) {
	$files[$property.Name] = $property.Value
}
$pluginDir = Join-Path $scriptDir "AtlasTab"

if ($Uninstall) {
	foreach ($name in $files.Keys) {
		$path = Join-Path $scriptDir $name
		$doc = Read-Lines $path
		if (([string]::Join("`n", $doc.Lines)).Contains($files[$name])) {
			$backup = Join-Path $pluginDir ("backup/" + (Split-Path $name -Leaf))
			if (Test-Path $backup) {
				Copy-Item -Force $backup $path
			} else {
				Revert-Ops $doc.Lines $styleHooks.$name
				Write-Lines $path $doc
			}
		}
	}
	Get-ChildItem -Path (Join-Path $scriptDir "Classes") -Filter "Atlas*.lua" | Remove-Item -Force
	Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $scriptDir "Data/AtlasTreeVersions.lua")
	Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $scriptDir "TreeData/Atlas")
	Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $pluginDir "backup")
	Write-Output "Atlas tab removed from $scriptDir"
	exit 0
}

$pending = @{}
$needBackup = @{}
foreach ($name in $files.Keys) {
	$path = Join-Path $scriptDir $name
	$backup = Join-Path $pluginDir ("backup/" + (Split-Path $name -Leaf))
	$doc = Read-Lines $path
	if (([string]::Join("`n", $doc.Lines)).Contains($files[$name])) {
		if (-not (Test-Path $backup)) {
			if (-not (Test-Path (Join-Path $pluginDir "version.txt"))) {
				Write-Output "This Path of Building already includes the Atlas tab. Nothing to do."
				exit 0
			}
			throw "$name is already modified but no original copy was found in '$backup'. Reinstall or update Path of Building, then run this installer again."
		}
		$doc = Read-Lines $backup
		Write-Output "Re-patching $name from the saved original"
	} else {
		$needBackup[$name] = $true
	}
	Apply-Ops $doc.Lines $styleHooks.$name
	$pending[$name] = $doc
}

New-Item -ItemType Directory -Force -Path (Join-Path $pluginDir "backup") | Out-Null
foreach ($name in $needBackup.Keys) {
	$path = Join-Path $scriptDir $name
	Copy-Item -Force $path (Join-Path $pluginDir ("backup/" + (Split-Path $name -Leaf)))
}
Copy-Item -Recurse -Force (Join-Path $PayloadDir "common/*") $scriptDir
Copy-Item -Recurse -Force (Join-Path $PayloadDir "$style/*") $scriptDir
foreach ($name in $pending.Keys) {
	Write-Lines (Join-Path $scriptDir $name) $pending[$name]
	Write-Output "Patched $name"
}
Copy-Item -Force (Join-Path $PayloadDir "version.txt") (Join-Path $pluginDir "version.txt")
Write-Output "Atlas tab ($style, $((Get-Content (Join-Path $PayloadDir 'version.txt')).Trim())) installed into $scriptDir"
