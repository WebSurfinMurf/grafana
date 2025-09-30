#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Grafana Deployment with Keycloak OAuth2 ===${NC}"

# Project paths
PROJECT_DIR="/home/administrator/projects/grafana"
DATA_DIR="/home/administrator/projects/data/grafana"
SECRETS_DIR="/home/administrator/projects/secrets"

# Load environment variables
if [ ! -f "$SECRETS_DIR/grafana.env" ]; then
    echo -e "${RED}✗ grafana.env not found in $SECRETS_DIR${NC}"
    echo "Please create it with OAUTH2_PROXY_CLIENT_SECRET"
    exit 1
fi

source "$SECRETS_DIR/grafana.env"

# Create data directory
echo -e "${YELLOW}→ Creating data directory...${NC}"
mkdir -p "$DATA_DIR"
# Grafana will handle permissions itself

# Stop existing containers
echo -e "${YELLOW}→ Stopping existing containers...${NC}"
docker stop grafana 2>/dev/null || true
docker rm grafana 2>/dev/null || true
docker stop grafana-auth-proxy 2>/dev/null || true
docker rm grafana-auth-proxy 2>/dev/null || true

# Ensure networks exist
echo -e "${YELLOW}→ Ensuring networks exist...${NC}"
docker network create traefik-proxy 2>/dev/null || echo "Network traefik-proxy already exists"
docker network create monitoring-net 2>/dev/null || echo "Network monitoring-net already exists"
docker network create keycloak-net 2>/dev/null || echo "Network keycloak-net already exists"
docker network create grafana-net 2>/dev/null || echo "Network grafana-net already exists"

# Deploy Grafana (on grafana-net, NOT on traefik-proxy)
echo -e "${YELLOW}→ Deploying Grafana...${NC}"
docker run -d \
  --name grafana \
  --restart unless-stopped \
  --network grafana-net \
  --network-alias grafana \
  --user root \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  -e GF_INSTALL_PLUGINS=redis-datasource \
  -e GF_SERVER_ROOT_URL=https://grafana.ai-servicers.com \
  -e GF_SERVER_SERVE_FROM_SUB_PATH=false \
  -e GF_AUTH_PROXY_ENABLED=true \
  -e GF_AUTH_PROXY_HEADER_NAME=X-Forwarded-User \
  -e GF_AUTH_PROXY_HEADER_PROPERTY=username \
  -e GF_AUTH_PROXY_AUTO_SIGN_UP=true \
  -e GF_AUTH_PROXY_ENABLE_LOGIN_TOKEN=false \
  -e GF_AUTH_PROXY_WHITELIST=172.16.0.0/12,10.0.0.0/8,192.168.0.0/16 \
  -e GF_USERS_ALLOW_SIGN_UP=true \
  -e GF_USERS_AUTO_ASSIGN_ORG=true \
  -e GF_USERS_AUTO_ASSIGN_ORG_ROLE=Admin \
  -v "$DATA_DIR:/var/lib/grafana" \
  grafana/grafana:latest

# Connect to additional networks
echo -e "${YELLOW}→ Configuring network connections...${NC}"
docker network connect monitoring-net grafana
docker network connect redis-net grafana

# Deploy OAuth2 Proxy
echo -e "${YELLOW}→ Deploying OAuth2 Proxy...${NC}"
docker run -d \
  --name grafana-auth-proxy \
  --restart unless-stopped \
  --network traefik-proxy \
  -e OAUTH2_PROXY_PROVIDER=keycloak-oidc \
  -e OAUTH2_PROXY_CLIENT_ID=grafana \
  -e OAUTH2_PROXY_CLIENT_SECRET="$OAUTH2_PROXY_CLIENT_SECRET" \
  -e OAUTH2_PROXY_REDIRECT_URL=https://grafana.ai-servicers.com/oauth2/callback \
  -e OAUTH2_PROXY_EMAIL_DOMAINS="*" \
  -e OAUTH2_PROXY_SKIP_OIDC_DISCOVERY=true \
  -e OAUTH2_PROXY_OIDC_JWKS_URL=http://keycloak:8080/realms/master/protocol/openid-connect/certs \
  -e OAUTH2_PROXY_LOGIN_URL=https://keycloak.ai-servicers.com/realms/master/protocol/openid-connect/auth \
  -e OAUTH2_PROXY_REDEEM_URL=http://keycloak:8080/realms/master/protocol/openid-connect/token \
  -e OAUTH2_PROXY_OIDC_ISSUER_URL=https://keycloak.ai-servicers.com/realms/master \
  -e OAUTH2_PROXY_INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL=true \
  -e OAUTH2_PROXY_COOKIE_SECRET="$(openssl rand -base64 32 | tr -d '\n' | cut -c1-32)" \
  -e OAUTH2_PROXY_COOKIE_SECURE=true \
  -e OAUTH2_PROXY_UPSTREAMS=http://grafana:3000/ \
  -e OAUTH2_PROXY_PASS_HOST_HEADER=false \
  -e OAUTH2_PROXY_HTTP_ADDRESS=0.0.0.0:4180 \
  -e OAUTH2_PROXY_SKIP_PROVIDER_BUTTON=false \
  -e OAUTH2_PROXY_PASS_AUTHORIZATION_HEADER=true \
  -e OAUTH2_PROXY_PASS_ACCESS_TOKEN=true \
  -e OAUTH2_PROXY_PASS_USER_HEADERS=true \
  -e OAUTH2_PROXY_SET_XAUTHREQUEST=true \
  -e OAUTH2_PROXY_SET_AUTHORIZATION_HEADER=true \
  -e OAUTH2_PROXY_PREFER_EMAIL_TO_USER=true \
  -l traefik.enable=true \
  -l traefik.http.routers.grafana.rule="Host(\`grafana.ai-servicers.com\`)" \
  -l traefik.http.routers.grafana.entrypoints=websecure \
  -l traefik.http.routers.grafana.tls=true \
  -l traefik.http.routers.grafana.tls.certresolver=cloudflare \
  -l traefik.http.services.grafana.loadbalancer.server.port=4180 \
  quay.io/oauth2-proxy/oauth2-proxy:latest

# Connect OAuth2 proxy to additional networks
echo -e "${YELLOW}→ Connecting OAuth2 proxy to additional networks...${NC}"
docker network connect keycloak-net grafana-auth-proxy
docker network connect grafana-net grafana-auth-proxy
docker network connect monitoring-net grafana-auth-proxy

# Wait for containers to start
echo -e "${YELLOW}→ Waiting for containers to start...${NC}"
sleep 5

# Check status
if docker ps | grep -q "grafana" && docker ps | grep -q "grafana-auth-proxy"; then
    echo -e "${GREEN}✓ Grafana deployed successfully${NC}"
    echo ""
    echo -e "${GREEN}Access Grafana at:${NC} https://grafana.ai-servicers.com"
    echo ""
    echo "Data sources to configure:"
    echo "  • Loki: http://loki:3100"
    echo "  • Prometheus (if deployed): http://prometheus:9090"
    echo ""
    echo "Default admin credentials (for direct access if needed):"
    echo "  Username: admin"
    echo "  Password: admin"
else
    echo -e "${RED}✗ Deployment failed${NC}"
    echo "Grafana logs:"
    docker logs grafana --tail 20
    echo ""
    echo "OAuth2 Proxy logs:"
    docker logs grafana-auth-proxy --tail 20
    exit 1
fi