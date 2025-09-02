#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Grafana Keycloak Client Setup ===${NC}"

# Authenticate with Keycloak
echo -e "${YELLOW}→ Authenticating with Keycloak...${NC}"
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials \
  --server https://localhost:8443 \
  --realm master \
  --user admin \
  --password 'SecureAdminPass2024!' \
  --truststore /opt/keycloak/conf/truststore.jks \
  --trustpass changeit

# Create Grafana client
echo -e "${YELLOW}→ Creating Grafana client...${NC}"
CLIENT_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients \
  -r master \
  -s clientId=grafana \
  -s enabled=true \
  -s clientAuthenticatorType=client-secret \
  -s protocol=openid-connect \
  -s publicClient=false \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=true \
  -s serviceAccountsEnabled=false \
  -s authorizationServicesEnabled=false \
  -s redirectUris='["https://grafana.ai-servicers.com/*"]' \
  -s webOrigins='["https://grafana.ai-servicers.com"]' \
  -s attributes='{"backchannel.logout.session.required":"true","backchannel.logout.revoke.offline.tokens":"false"}' \
  -i)

echo "Created client with ID: $CLIENT_ID"

# Get the client secret
echo -e "${YELLOW}→ Retrieving client secret...${NC}"
SECRET=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/$CLIENT_ID/client-secret \
  -r master \
  --fields value \
  --format csv \
  --noquotes)

echo -e "${GREEN}✓ Keycloak client 'grafana' created successfully${NC}"
echo ""
echo "Client Secret: ${SECRET}"
echo ""
echo "Update /home/administrator/projects/secrets/grafana.env with:"
echo "OAUTH2_PROXY_CLIENT_SECRET=${SECRET}"

# Update the env file automatically
SECRETS_FILE="/home/administrator/projects/secrets/grafana.env"
if [ -f "$SECRETS_FILE" ]; then
    sed -i "s/OAUTH2_PROXY_CLIENT_SECRET=.*/OAUTH2_PROXY_CLIENT_SECRET=${SECRET}/" "$SECRETS_FILE"
    echo -e "${GREEN}✓ Updated $SECRETS_FILE with client secret${NC}"
fi