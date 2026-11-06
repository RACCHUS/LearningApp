#!/usr/bin/env bash
set -e

# ==============================================================================
# LearningApp Turnkey Self-Hosting Bootstrap Script (Linux/macOS)
# ==============================================================================

echo "=========================================================="
echo "  LearningApp Turnkey Self-Hosting Infrastructure Setup  "
echo "=========================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$SCRIPT_DIR"

# 1. Environment file check
if [ ! -f .env ]; then
  echo "📝 Creating .env from .env.example..."
  cp .env.example .env
  echo "⚠️ Notice: Generated default .env. For production, please edit deploy/self-host/.env with secure credentials."
fi

# 2. Re-compile consolidated migration schema bundle
echo "🔄 Compiling database schema bundle from migrations..."
(cd "$ROOT_DIR" && dart run tool/self_host_bootstrap.dart --generate-bundle deploy/self-host/init-scripts/01-full-schema.sql)

# 3. Check for docker compose
if ! command -v docker &> /dev/null; then
  echo "❌ Error: Docker is not installed or not in PATH."
  exit 1
fi

echo "🚀 Starting LearningApp services via Docker Compose..."
docker compose up -d

echo "⏳ Waiting for PostgreSQL database to be healthy..."
until [ "$(docker inspect -f {{.State.Health.Status}} learningapp-db 2>/dev/null)" == "healthy" ]; do
  sleep 2
done

echo ""
echo "=========================================================="
echo "✅ LearningApp Self-Hosting Stack is Ready!"
echo "=========================================================="
echo "🌐 API Gateway (Kong):   http://localhost:8000"
echo "🗄️ REST API (PostgREST): http://localhost:8000/rest/v1"
echo "🔐 Auth (GoTrue):        http://localhost:8000/auth/v1"
echo "📦 Storage API:          http://localhost:8000/storage/v1"
echo ""
echo "To connect your Flutter client to this self-hosted instance, run:"
echo "  flutter run -d chrome \\"
echo "    --dart-define=SUPABASE_URL=http://localhost:8000 \\"
echo "    --dart-define=SUPABASE_ANON_KEY=\$(grep ANON_KEY .env | cut -d '=' -f2)"
echo "=========================================================="

