# Grafana - Metrics and Logs Visualization

## Executive Summary
Grafana is the central visualization platform for the monitoring stack, providing dashboards and exploration tools for logs (from Loki) and metrics (from Prometheus/Netdata). Protected by Keycloak OAuth2 authentication with automatic SSO for administrators group.

## Current Status
- **Status**: ⚠️ Container Running but May Have Issues
- **URL**: https://grafana.ai-servicers.com
- **Container**: grafana (running 46+ minutes)
- **Auth Container**: grafana-auth-proxy (recently restarted)
- **Networks**: observability-net, traefik-proxy
- **Authentication**: Keycloak OAuth2 via proxy

## Known Issues
- **OAuth2 Proxy Restarts**: Auth proxy was restarted 13 seconds ago (was running 46 min)
- **Permission Issues**: Initial deployment had data directory permission errors
- **Running as Root**: Container runs as root to work around permission issues

## Architecture
```
Internet
    ↓
Traefik (websecure)
    ↓
grafana-auth-proxy (:4180)
    ├── → Keycloak (token validation) [via keycloak-net]
    └── → Grafana (:3000) [via observability-net]
```

## File Locations
- **Project**: `/home/administrator/projects/grafana/`
- **Data**: `/home/administrator/projects/data/grafana/`
- **Secrets**: `/home/administrator/projects/secrets/grafana.env`
- **Deploy Script**: `/home/administrator/projects/grafana/deploy.sh`
- **Keycloak Setup**: `/home/administrator/projects/grafana/setup-keycloak.sh`
- **Manual Setup**: `/home/administrator/projects/grafana/manual-keycloak-setup.md`

## Access Methods
- **External (SSO)**: https://grafana.ai-servicers.com (Keycloak OAuth2)
- **Internal API**: http://grafana:3000 (from observability-net)
- **Default Admin**: admin/admin (for direct container access only)

## Deployment Details

### Container Configuration
```bash
# Grafana container
--name grafana
--network observability-net
--user root  # Required for permission workaround
-v /home/administrator/projects/data/grafana:/var/lib/grafana
-e GF_SECURITY_ADMIN_PASSWORD=admin
-e GF_INSTALL_PLUGINS=redis-datasource
-e GF_SERVER_ROOT_URL=https://grafana.ai-servicers.com
```

### OAuth2 Proxy Configuration
```bash
# grafana-auth-proxy container
--name grafana-auth-proxy
--network traefik-proxy
--network keycloak-net  # CRITICAL: Must be on both networks
--network observability-net  # To reach Grafana
-e OAUTH2_PROXY_PROVIDER=keycloak-oidc
-e OAUTH2_PROXY_CLIENT_ID=grafana
-e OAUTH2_PROXY_CLIENT_SECRET=LXbr6VMZELA4e55Zhfa7ZTYshH55ZOIK
-e OAUTH2_PROXY_UPSTREAMS=http://grafana:3000/
```

## Common Operations

### Deploy/Redeploy
```bash
cd /home/administrator/projects/grafana && ./deploy.sh
```

### Check Status
```bash
# Check containers
docker ps | grep grafana

# View Grafana logs
docker logs grafana --tail 50 -f

# View OAuth2 proxy logs
docker logs grafana-auth-proxy --tail 50 -f
```

### Restart Services
```bash
# Restart both containers
docker restart grafana grafana-auth-proxy

# Or redeploy completely
cd /home/administrator/projects/grafana && ./deploy.sh
```

### Access Without SSO (Troubleshooting)
```bash
# Method 1: Reset admin password and port forward
docker exec -it grafana grafana-cli admin reset-admin-password newpassword
ssh -L 3000:localhost:3000 administrator@linuxserver.lan
# Then access http://localhost:3000 with admin/newpassword

# Method 2: Direct container access
docker exec -it grafana /bin/bash
# Use grafana-cli commands inside container
```

## Data Sources Configuration

### Available Data Sources
1. **Loki** (Logs)
   - URL: `http://loki:3100`
   - Access: Server (proxy)
   - No auth required (internal network)

2. **Prometheus** (Metrics - when deployed)
   - URL: `http://prometheus:9090`
   - Access: Server (proxy)

3. **Netdata** (System Metrics - indirect)
   - Access via MCP monitoring server
   - Not directly configured in Grafana

### Adding Data Sources
1. Login to Grafana
2. Navigate: Configuration → Data Sources
3. Click "Add data source"
4. Configure as needed

## Network Requirements
- **grafana**: Must be on `observability-net` (to be reached by proxy and reach Loki)
- **grafana**: Must be on `traefik-proxy` (for network alias)
- **grafana-auth-proxy**: Must be on THREE networks:
  - `traefik-proxy` (for Traefik routing)
  - `keycloak-net` (for token validation)
  - `observability-net` (to reach Grafana)

## Keycloak Configuration
- **Client ID**: grafana
- **Client Secret**: LXbr6VMZELA4e55Zhfa7ZTYshH55ZOIK (in secrets file)
- **Client Type**: Confidential
- **Valid Redirect URIs**: https://grafana.ai-servicers.com/*
- **Web Origins**: https://grafana.ai-servicers.com
- **Group Restriction**: None (all authenticated users allowed)

## Troubleshooting

### Issue: 502 Bad Gateway
```bash
# Check if Grafana is running
docker ps | grep grafana

# Check OAuth2 proxy can reach Grafana
docker exec grafana-auth-proxy wget -O- http://grafana:3000/api/health

# Verify network connectivity
docker exec grafana-auth-proxy ping -c 1 grafana
```

### Issue: 403 Forbidden / Authentication Failed
```bash
# Check OAuth2 proxy logs
docker logs grafana-auth-proxy --tail 50

# Verify Keycloak client secret
grep CLIENT_SECRET /home/administrator/projects/secrets/grafana.env

# Check user session
curl https://grafana.ai-servicers.com/oauth2/userinfo
```

### Issue: Permission Denied in Logs
```bash
# Container already runs as root, but if issues persist:
# Check data directory ownership
ls -la /home/administrator/projects/data/grafana/

# Fix permissions if needed (requires sudo)
sudo chown -R 472:472 /home/administrator/projects/data/grafana/

# Or remove data and let Grafana recreate
docker stop grafana
sudo rm -rf /home/administrator/projects/data/grafana/*
docker start grafana
```

### Issue: Cannot Connect to Loki
```bash
# Verify Loki is running
docker ps | grep loki

# Test from Grafana container
docker exec grafana wget -O- http://loki:3100/ready

# Check network
docker network inspect observability-net | grep -A5 grafana
```

## Dashboard Management

### Recommended Dashboards to Import
- **Loki Logs Explorer**: Built-in, use Explore tab
- **Docker Container Metrics**: Import ID 11600
- **Node Exporter Full**: Import ID 1860
- **Docker Monitoring**: Import ID 893

### Creating Dashboards
1. Click + → Create Dashboard
2. Add panels with queries
3. Save with descriptive name
4. Organize in folders

## Plugin Management
Currently installed plugins:
- `redis-datasource` - Redis data source

To add more plugins:
1. Edit deploy.sh
2. Add to `GF_INSTALL_PLUGINS` environment variable
3. Redeploy Grafana

## Performance Notes
- **Data Retention**: Controlled by data sources (Loki: 30 days)
- **Query Timeout**: Default 30 seconds
- **Max Data Points**: Auto-adjusted based on screen resolution
- **Browser Cache**: Use Shift+Refresh if dashboards don't update

## Security Considerations
- All external access via HTTPS only
- OAuth2 proxy handles authentication
- Direct Grafana access disabled from outside
- API keys can be created for programmatic access
- Default admin password should be changed in production

## Integration Points
- **Loki**: Primary log data source
- **Prometheus**: Metrics (when deployed)
- **Keycloak**: Authentication provider
- **Traefik**: Reverse proxy and SSL termination
- **MCP Monitoring**: Programmatic access to same data

## Backup Considerations
Important to backup:
- `/home/administrator/projects/data/grafana/grafana.db` - Dashboard definitions
- `/home/administrator/projects/data/grafana/plugins/` - Custom plugins
- Export dashboards as JSON for version control

## Common Issues & Solutions

### Grafana Updates Reset Permissions
The container may reset permissions on updates. Current workaround is running as root user.

### Session Timeout
OAuth2 proxy sessions expire after 7 days. Users need to re-authenticate.

### Dashboard Not Loading
- Clear browser cache
- Check data source connectivity
- Verify time range is appropriate

## Future Enhancements
- [ ] Add Prometheus for container metrics
- [ ] Configure alerting rules
- [ ] Set up notification channels
- [ ] Import standard dashboards library
- [ ] Configure LDAP as backup auth
- [ ] Set up dashboard provisioning

## Last Updated
- **2025-09-01 23:07**: Initial deployment with Keycloak OAuth2
- **2025-09-01 23:43**: Running with root user for permissions
- **Note**: Auth proxy shows recent restart (stability issue?)

---
*For restart/recovery: Run `/home/administrator/projects/grafana/deploy.sh`*