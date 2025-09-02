# Manual Keycloak Client Setup for Grafana

## Steps to create the Grafana client in Keycloak:

1. **Access Keycloak Admin Console**
   - Go to: https://keycloak.ai-servicers.com/admin
   - Login with admin / SecureAdminPass2024!

2. **Create New Client**
   - Navigate to: Clients → Create client
   - Fill in:
     - **Client ID**: `grafana`
     - **Name**: `Grafana`
     - **Always display in UI**: On
   - Click "Next"

3. **Configure Client**
   - **Client authentication**: ON
   - **Authorization**: OFF
   - **Standard flow**: ON
   - **Direct access grants**: ON
   - Click "Next"

4. **Login Settings**
   - **Valid redirect URIs**: 
     ```
     https://grafana.ai-servicers.com/*
     ```
   - **Valid post logout redirect URIs**: 
     ```
     https://grafana.ai-servicers.com/*
     ```
   - **Web origins**: 
     ```
     https://grafana.ai-servicers.com
     ```
   - Click "Save"

5. **Get Client Secret**
   - Go to the "Credentials" tab
   - Copy the "Client secret" value

6. **Update Environment File**
   - Edit `/home/administrator/projects/secrets/grafana.env`
   - Replace `REPLACE_WITH_KEYCLOAK_SECRET` with the copied secret

## Alternative: Generate Random Secret

If you want to generate a random secret for now:

```bash
# Generate a random secret
SECRET=$(openssl rand -base64 32 | tr -d '\n')
echo "Generated secret: $SECRET"

# Update the env file
sed -i "s/OAUTH2_PROXY_CLIENT_SECRET=.*/OAUTH2_PROXY_CLIENT_SECRET=$SECRET/" /home/administrator/projects/secrets/grafana.env
```

Then update the client in Keycloak with this secret.