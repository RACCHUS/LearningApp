<#
.SYNOPSIS
    Guarded Supabase Production Migration Deployment Tool (Windows PowerShell).

.DESCRIPTION
    Implements Phase 4 permanent prevention controls from MIGRATION_HISTORY_REPAIR_DECISION_PLAN.md.
    Enforces project identity verification, dirty-migration blocking, process serialization lock,
    preflight version gate, push dry-run validation, live push, postflight parity gate,
    and sanitized JSON audit reporting.

.PARAMETER DryRun
    Perform preflight and dry-run push without applying changes to hosted Supabase.

.PARAMETER AllowDirty
    Allow running even if untracked non-migration files exist in git (migrations must be clean).

.PARAMETER ForceUnlock
    Clear an existing deployment lock if a previous deployment crashed.

.PARAMETER ProjectRef
    Target Supabase project ref (default: xzvkdwebtbxlrxagtzlv).

.PARAMETER ReportDir
    Directory to store audit reports (default: build/migration_deployment_reports).

.EXAMPLE
    .\tool\guarded_supabase_deploy.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$AllowDirty,
    [switch]$ForceUnlock,
    [string]$ProjectRef = "xzvkdwebtbxlrxagtzlv",
    [string]$ReportDir = "build/migration_deployment_reports"
)

$ErrorActionPreference = "Stop"

$argsList = @("run", "tool/guarded_supabase_deploy.dart")
if ($DryRun) { $argsList += "--dry-run" }
if ($AllowDirty) { $argsList += "--allow-dirty" }
if ($ForceUnlock) { $argsList += "--force-unlock" }
if ($ProjectRef) { $argsList += "--project-ref"; $argsList += $ProjectRef }
if ($ReportDir) { $argsList += "--report-dir"; $argsList += $ReportDir }

Write-Host "Invoking guarded migration deployment workflow..." -ForegroundColor Cyan
& dart $argsList
if ($LASTEXITCODE -ne 0) {
    Write-Error "Guarded migration deployment workflow failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}
