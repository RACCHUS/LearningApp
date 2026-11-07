# Prototype isolation image for the Excel pilot. Not production approved.
# Build with context tool/software_learning (not the entire Flutter repository).
# Pin the exact upstream digest before any hosted deployment.
FROM python:3.13-slim-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY --chown=65532:65532 xlsx_snapshot.py xlsx_worker.py ./
USER 65532:65532
ENTRYPOINT ["python", "-I", "-S", "/app/xlsx_worker.py"]
