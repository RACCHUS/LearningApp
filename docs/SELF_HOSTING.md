# 🌐 Turnkey Self-Hosting & Forking Guide

> **Normative Platform Reference**: `ARCHITECTURE_REVIEW.md §3 (OPP-6)` & `EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md`  
> **Status**: Production Ready (Phase 3 Milestone 2)

LearningApp provides a first-class, turnkey self-hosting and white-label forking architecture. Any educational institution, training provider, or open-source contributor can deploy their own completely sovereign, private learning instance with zero dependence on proprietary third-party clouds or vendor lock-in.

---

## 🏛️ System Architecture

Self-hosted deployments run as a containerized microservice mesh managed via Docker Compose:

1. **Kong API Gateway (`kong:2.8.1`)**: Exposes port `8000` (HTTP) and `8443` (HTTPS), routing `/rest/v1/*` to PostgREST, `/auth/v1/*` to GoTrue, and `/storage/v1/*` to Supabase Storage.
2. **PostgreSQL 15 (`supabase/postgres:15.8.1.189`)**: Pre-packaged with `pgcrypto`, `uuid-ossp`, `pg_trgm`, and `vector` extensions.
3. **PostgREST 12 (`postgrest/postgrest:v12.2.0`)**: Configured to serve both `public` and `api` schemas to satisfy client contract requirements.
4. **GoTrue (`supabase/gotrue:v2.164.0`)**: Handles user authentication, anonymous guest sessions (`auth.signInAnonymously()`), and JWT verification.
5. **Storage API (`supabase/storage-api:v1.14.3`)**: Manages uploaded curriculum manifests, audio files, and media artifacts.

---

## ⚡ Deployment in 3 Minutes

### 1. Prerequisites
- Docker Engine $\ge 20.10$ and Docker Compose $\ge 2.0$.
- Minimum hardware: 2 vCPUs, 2 GB RAM, 10 GB disk space.
- Dart SDK $\ge 3.8.0$ (optional, only if generating custom migration bundles from source).

### 2. Configuration & Launch
Clone the repository and enter the self-hosting directory:
```bash
git clone https://github.com/RACCHUS/LearningApp.git
cd LearningApp/deploy/self-host
```

Copy the environment template:
```bash
cp .env.example .env
```

Review and adjust `.env` variables:
- `POSTGRES_PASSWORD`: Strong password for the database.
- `JWT_SECRET`: Minimum 32-character secret for signing JWTs.
- `SITE_URL`: Base URL of your web client (e.g. `https://learn.yourdomain.org`).
- `API_EXTERNAL_URL`: Public gateway URL (e.g. `https://api.yourdomain.org`).

Run the automated bootstrap:
```bash
# On Linux / macOS:
./bootstrap.sh

# On Windows PowerShell:
.\bootstrap.ps1
```

All services will initialize, mount the initial schemas, apply all 86 migrations in order, and become healthy.

---

## 🎨 White-Labeling & Fork Branding (`brand.json`)

LearningApp decouples its core learning engine from application branding. You can customize the name, tagline, theme colors, and enabled feature flags without touching source code.

Create a `brand.json` configuration file:
```json
{
  "app_name": "CivicsMaster",
  "tagline": "Evidence-Based US Citizenship Exam Preparation",
  "organization_name": "Citizenship Literacy Institute",
  "organization_url": "https://civicsmaster.org",
  "support_email": "help@civicsmaster.org",
  "primary_color_hex": "#1E88E5",
  "secondary_color_hex": "#43A047",
  "dark_primary_color_hex": "#64B5F6",
  "dark_secondary_color_hex": "#81C784",
  "terms_of_service_url": "https://civicsmaster.org/terms",
  "privacy_policy_url": "https://civicsmaster.org/privacy",
  "features": {
    "enable_byok_ai": false,
    "enable_hands_free": true,
    "enable_offline_sync": true,
    "enable_adult_literacy": true,
    "enable_performance_assessments": true,
    "enable_taxonomy_explorer": true,
    "enable_qti_export": true,
    "enable_community_qa": true
  }
}
```

### Compiling with Custom Brand

Build the release web artifact:
```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://api.yourdomain.org \
  --dart-define=SUPABASE_ANON_KEY=your-production-anon-key \
  --dart-define-from-file=brand.json
```

---

## 🔄 Applying Upstream Migrations

When pulling new releases from upstream `LearningApp`, run:
```bash
dart run tool/self_host_bootstrap.dart --generate-bundle deploy/self-host/init-scripts/01-full-schema.sql
```

To apply pending migrations to a running self-hosted container:
```bash
docker exec -i learningapp-db psql -U postgres postgres < deploy/self-host/init-scripts/01-full-schema.sql
```
*(Every migration statement in the bundle is idempotent and records applied versions into `supabase_migrations.schema_migrations` with `ON CONFLICT (version) DO NOTHING`.)*

---

## 🔒 Security & Maintenance

1. **SSL/TLS**: Terminate TLS at your front-facing reverse proxy (e.g. Nginx, Traefik, or Caddy). Never expose port 5432 or internal container ports directly to the public internet.
2. **Backups**: Configure a daily cron backup:
   ```bash
   docker exec -t learningapp-db pg_dump -U postgres postgres | gzip > "backup_$(date +%Y%m%d).sql.gz"
   ```
3. **Restores**:
   ```bash
   gunzip -c backup_20261106.sql.gz | docker exec -i learningapp-db psql -U postgres postgres
   ```

