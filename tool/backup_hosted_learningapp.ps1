#Requires -Version 5.1
<#
.SYNOPSIS
  Back up the Learning App hosted Supabase database to a SEPARATE physical SSD.

.DESCRIPTION
  Creates an isolated, compressed PostgreSQL custom-format archive with
  public, auth, storage metadata and migration-history schemas; validates the
  archive TOC and decompression, and writes a SHA-256 manifest next to the dump.
  Can also make a verified second copy at an explicitly supplied location.

  Never logs or stores the database password or connection string in a file.
  Cannot and does NOT claim that a complete restore was tested.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\backup_hosted_learningapp.ps1 -DriveLetter E
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\backup_hosted_learningapp.ps1 -DriveLetter E -SecondaryFolder "C:\Users\you\OneDrive\PrivateBackups"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z]$')]
  [string] $DriveLetter,

  [string] $DbHost,
  [string] $DbUser,
  [ValidateRange(1,65535)]
  [int] $DbPort = 5432,
  [string] $Database = 'postgres',

  [string] $SecondaryFolder,
  [switch] $AllowSamePhysicalDisk
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$expectedProjectRef = 'xzvkdwebtbxlrxagtzlv'
$drive = $DriveLetter.Trim().ToUpperInvariant()
$destinationRoot = "$($drive):\LearningAppBackups"
$completed = $false
$archivePath = $null
$manifestPath = $null
$secretHandle = [IntPtr]::Zero

function Resolve-PgTool([string] $Name) {
  $fromPath = Get-Command $Name -ErrorAction SilentlyContinue
  if ($null -ne $fromPath) { return $fromPath.Source }

  foreach ($major in 17,18,19) {
    $path = "C:\Program Files\PostgreSQL\$major\bin\$Name.exe"
    if (Test-Path -LiteralPath $path) { return $path }
  }
  throw "$Name was not found. Install PostgreSQL 17+ command-line tools and rerun. No backup was created."
}

try {
  $targetPartition = Get-Partition -DriveLetter $drive -ErrorAction Stop
  $targetDisk = $targetPartition | Get-Disk -ErrorAction Stop
  $systemDrive = $env:SystemDrive.Substring(0,1)
  $systemPartition = Get-Partition -DriveLetter $systemDrive -ErrorAction Stop
  $systemDisk = $systemPartition | Get-Disk -ErrorAction Stop

  Write-Host "Destination: $destinationRoot"
  Write-Host "SSD location: disk $($targetDisk.Number) ($($targetDisk.FriendlyName))"
  if ($targetDisk.Number -eq $systemDisk.Number -and -not $AllowSamePhysicalDisk) {
    throw "Drive $drive is on the SAME physical disk as Windows ($systemDrive). Choose a separate physical SSD, or explicitly use -AllowSamePhysicalDisk only for non-production testing."
  }

  $freeSpace = (Get-Volume -DriveLetter $drive).SizeRemaining
  if ($freeSpace -lt 1024*1024*1024) {
    throw "The selected drive has less than 1 GiB free. Choose a drive with more free space."
  }

  if (-not $DbHost) { $DbHost = Read-Host 'Database host from Supabase Dashboard > Connect (session pooler recommended)' }
  if (-not $DbUser) { $DbUser = Read-Host 'Database username from the same connection details' }
  if ([string]::IsNullOrWhiteSpace($DbHost) -or [string]::IsNullOrWhiteSpace($DbUser)) {
    throw 'Database host and username are required.'
  }

  $pgDump = Resolve-PgTool 'pg_dump'
  $pgRestore = Resolve-PgTool 'pg_restore'
  $versionOutput = (& $pgDump --version) -join ' '
  if ($versionOutput -notmatch '(\d+)(?:\.\d+)?\s*$' -or [int]$Matches[1] -lt 17) {
    throw "The database uses PostgreSQL 17. Install pg_dump/pg_restore 17 or later. Detected: $versionOutput"
  }

  New-Item -Path $destinationRoot -ItemType Directory -Force | Out-Null
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $base = "learningapp-$expectedProjectRef-$stamp"
  $archivePath = Join-Path $destinationRoot "$base.dump"
  $manifestPath = Join-Path $destinationRoot "$base.manifest.json"
  if (Test-Path -LiteralPath $archivePath) { throw 'A backup file with this timestamp already exists. Retry.' }

  Write-Host ''
  Write-Host 'Supabase database password (hidden; never paste this into ChatGPT or GitHub).'
  $securePassword = Read-Host -AsSecureString 'Database password'
  $secretHandle = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
  $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretHandle)
  $env:PGHOST = $DbHost
  $env:PGPORT = [string]$DbPort
  $env:PGUSER = $DbUser
  $env:PGDATABASE = $Database
  $env:PGSSLMODE = 'require'
  Write-Host ''
  Write-Host 'Creating backup with PostgreSQL client (public, auth, storage metadata, Supabase migration history)...'
  # IMPORTANT: --schema is intentional. An unrestricted raw pg_dump of a
  # managed Supabase database can try to export internal managed objects.
  # Storage API object bytes are NOT contained in this database archive.
  $dumpArgs = @(
    '--format=custom',
    '--compress=6',
    '--no-owner',
    '--no-acl',
    '--schema=public',
    '--schema=auth',
    '--schema=storage',
    '--schema=supabase_migrations',
    "--file=$archivePath"
  )
  & $pgDump @dumpArgs
  if ($LASTEXITCODE -ne 0) { throw "pg_dump exited with code $LASTEXITCODE. No validated backup exists." }

  $backupInfo = Get-Item -LiteralPath $archivePath
  if ($backupInfo.Length -lt 1024) { throw "Archive appears truncated ($($backupInfo.Length) bytes)." }

  $toc = & $pgRestore --list $archivePath
  if ($LASTEXITCODE -ne 0) { throw 'pg_restore failed to read backup table-of-contents.' }
  $tocText = $toc -join [Environment]::NewLine
  foreach ($expectedEntry in @('TABLE DATA public learning_targets','TABLE DATA auth users')) {
    if ($tocText -notmatch [regex]::Escape($expectedEntry)) {
      throw "Critical backup item missing: $expectedEntry. Do not run the hosted taxonomy import."
    }
  }

  # Decode every compressed backup member. This DOES NOT restore into a DB;
  # it catches corruption beyond only reading the archive's TOC.
  Write-Host 'Checking complete archive decompression (no database writes)...'
  & $pgRestore --file=NUL $archivePath
  if ($LASTEXITCODE -ne 0) { throw 'Archive decompression failed. Do not use this backup.' }

  $hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
  $manifest = [ordered]@{
    project_ref = $expectedProjectRef
    created_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    archive_file = $backupInfo.Name
    bytes = [long]$backupInfo.Length
    sha256 = $hash
    schemas = @('public','auth','storage','supabase_migrations')
    validation = 'pg_restore --list + full archive decode; not a tested database restore'
    storage_object_bytes_included = $false
    offsite_copy_verified = $false
  }
  $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

  if ($SecondaryFolder) {
    $secondRoot = [IO.Path]::GetFullPath($SecondaryFolder)
    if (-not (Test-Path -LiteralPath $secondRoot)) {
      throw "Secondary folder not found: $secondRoot. Backup on SSD exists, but cloud/second-copy verification was NOT completed."
    }
    $secondaryArchive = Join-Path $secondRoot $backupInfo.Name
    $secondaryManifest = Join-Path $secondRoot (Split-Path -Leaf $manifestPath)
    if ([IO.Path]::GetFullPath($secondaryArchive) -eq [IO.Path]::GetFullPath($archivePath)) {
      throw 'Secondary backup is the same path as the primary archive.'
    }
    Copy-Item -LiteralPath $archivePath -Destination $secondaryArchive -ErrorAction Stop
    $copyHash = (Get-FileHash -LiteralPath $secondaryArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($copyHash -ne $hash) { throw 'Secondary copy checksum mismatch. Do not import.' }
    $manifest.offsite_copy_verified = $true
    $manifest.secondary_copy_verified_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    $manifest.secondary_copy_notice = 'Checksum checked locally; cloud upload or off-site storage is NOT verified.'
    $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Copy-Item -LiteralPath $manifestPath -Destination $secondaryManifest -Force
    Write-Host "Second copy checksum verified at: $secondaryArchive"
  }

  $completed = $true
  Write-Host ''
  Write-Host 'BACKUP SUCCEEDED (archive integrity checked; full database restore not tested)'
  Write-Host "Archive: $archivePath"
  Write-Host "Manifest: $manifestPath"
  Write-Host "SHA-256: $hash"
  Write-Host "Size: $($backupInfo.Length) bytes"
  Write-Host 'Keep this backup ENCRYPTED. An SSD in the same computer is NOT an off-site copy.'
  Write-Host 'Store a second ENCRYPTED copy away from the computer before production import.'
  Write-Host 'Do not upload the .dump file or reveal database credentials in this conversation.'
}
finally {
  Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
  Remove-Item Env:\PGHOST -ErrorAction SilentlyContinue
  Remove-Item Env:\PGUSER -ErrorAction SilentlyContinue
  Remove-Item Env:\PGPORT -ErrorAction SilentlyContinue
  Remove-Item Env:\PGDATABASE -ErrorAction SilentlyContinue
  Remove-Item Env:\PGSSLMODE -ErrorAction SilentlyContinue
  if ($secretHandle -ne [IntPtr]::Zero) {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretHandle)
  }
  if (-not $completed -and $archivePath -and (Test-Path -LiteralPath $archivePath)) {
    # A failed verification must not leave an apparently usable backup archive.
    $failedPath = "$archivePath.INCOMPLETE"
    Move-Item -LiteralPath $archivePath -Destination $failedPath -Force -ErrorAction SilentlyContinue
    Write-Warning "A partial/unchecked archive may exist at $failedPath. Do NOT use it to authorize production import."
  }
}
