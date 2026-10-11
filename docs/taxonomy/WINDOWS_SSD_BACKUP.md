# Learning App — Windows SSD Backup

**Status:** Backup script committed to GitHub; no local SSD backup has yet been created.  
**Project:** Learning App Supabase, xzvkdwebtbxlrxagtzlv.  
**Script:** tool/backup_hosted_learningapp.ps1  
**Companion:** [Controlled Hosted Import](CONTROLLED_PRODUCTION_TAXONOMY_IMPORT.md).

## Is the second SSD reliable?

A second, physically independent SSD is a sensible **first recovery copy**. It protects against the system drive failing. If both drives remain inside the computer, it is **not off-site**: theft, power incidents, ransomware, fire or accidental deletion may destroy both.

Before production ingestion, have a **verified SSD backup plus a separately encrypted second copy away from the PC**. A cloud sync folder is not safe for raw, unencrypted database archives. Strong encryption and verification of actual off-site availability are essential.

## One-time Windows setup

1. In File Explorer → This PC, find the physical SSD drive letter (example: E:). The script checks that the drive is physically different from the Windows disk.
2. Install PostgreSQL **17 or newer command-line tools**. Use the [official PostgreSQL Windows download](https://www.postgresql.org/download/windows/) or, if available, an elevated PowerShell command:

~~~powershell
winget install --id PostgreSQL.PostgreSQL.17 --exact
~~~

3. Open the [Learning App Supabase project's Connect panel](https://supabase.com/dashboard/project/xzvkdwebtbxlrxagtzlv) and select **Session Pooler** unless direct IPv6 connections work. Privately note **database host, port and username**. The username is typically postgres followed by the project ref on a session pooler connection. Use the PostgreSQL **database password**, not your dashboard login password or API service-role key.
4. Open PowerShell in your local LearningApp repository checkout. The script is now in its main GitHub branch after the PR is merged. If you have uncommitted work locally, protect it before updating your checkout.

## Run the backup

Change E to the letter of the separate physical SSD:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\backup_hosted_learningapp.ps1 -DriveLetter E
~~~

If the Connect panel specifies a different database port, use -DbPort:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\backup_hosted_learningapp.ps1 -DriveLetter E -DbPort 6543
~~~

The script prompts privately for the database host, username, and hidden password. It rejects a connection whose host and username cannot be identified as the Learning App project. It does not send credentials to GitHub or ChatGPT.

It creates a compressed custom-format PostgreSQL archive covering the **public, auth, storage metadata, and supabase_migrations database schemas**. It includes table data from those schemas, but it **does not** include external object bytes from Supabase Storage buckets.

The expected output on E: is a pair of files similar to:

~~~text
E:\LearningAppBackups\learningapp-xzvkdwebtbxlrxagtzlv-20261011-190000.dump
E:\LearningAppBackups\learningapp-xzvkdwebtbxlrxagtzlv-20261011-190000.manifest.json
~~~

On success, it verifies the archive table of contents, checks required Learning App and auth-user entries, fully decompresses the archive without writing to a database, and records file length plus **SHA-256** in the manifest.

**A successful decompression is not a test restore.** Restore rehearsal on a disposable PostgreSQL instance is recommended. The script fails closed if Postgres permissions or an export/verification step are unavailable.

## Keep it safe

- Prefer a BitLocker-encrypted separate SSD, with its recovery key safely stored elsewhere. The raw archive contains sensitive application and authentication data.
- Keep a second **encrypted** copy in an independent location (another disconnected drive kept elsewhere or a reputable, user-controlled encrypted remote vault).
- Never upload unencrypted backup files to GitHub, ChatGPT, or a consumer cloud-sync folder.
- An optional -SecondaryFolder argument only makes a second SHA-256-checked copy to an existing directory. The script refuses common direct cloud-sync paths and **does not certify encryption or off-site location**. Prefer managing encrypted off-site transfer separately.
- A different partition on the same physical Windows disk is not accepted as a backup destination.

To verify a file's checksum later:

~~~powershell
(Get-FileHash -Algorithm SHA256 "E:\LearningAppBackups\YOUR-BACKUP.dump").Hash.ToLowerInvariant()
~~~

Compare it to the sha256 property in the accompanying manifest. For encrypted second copies, verify the hash **after decrypting** the backup archive.

## Once both backup copies are ready

1. Ensure GitHub Actions has the secured secrets SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY for Learning App; never add these to repository files.
2. In GitHub → Actions → [Controlled Official Taxonomy Import](https://github.com/RACCHUS/LearningApp/actions/workflows/controlled-official-taxonomy-import.yml), select main and **preflight**. Confirm all read-only checks pass.
3. After independently verifying the off-site copy, select **import**, enter the exact Learning App project ref, the location/reference of the off-site backup (not its password), and the **plaintext archive hash** from the manifest. The GitHub workflow validates the input's format but cannot inspect your SSD or prove a restore works.
4. Verify the hosted taxonomy counts, source artifacts, target versions, lessons and users afterwards. Never use db reset on the production project.

**No live hosted import happens when the backup script or this runbook is merged.**

## Reference documentation

- [Supabase Backups](https://supabase.com/docs/guides/platform/backups)
- [PostgreSQL pg_dump](https://www.postgresql.org/docs/17/app-pgdump.html)
- [PostgreSQL pg_restore](https://www.postgresql.org/docs/17/app-pgrestore.html)
- [Official Supabase CLI platform export alternative](https://supabase.com/docs/guides/self-hosting/restore-from-platform)
