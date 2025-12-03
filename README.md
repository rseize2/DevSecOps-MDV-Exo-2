# CI/CD DevSecOps Pipeline

Structure
- docker-compose.yml
- .env
- scripts/process_images.sh
- .github/workflows/ci-cd.yml

Secrets required in GitHub repository settings
- REGISTRY_USER
- REGISTRY_TOKEN
- COSIGN_PRIVATE_KEY_B64
- COSIGN_PUBLIC_KEY_B64

Usage
Push to main to trigger the pipeline or run workflow manually.