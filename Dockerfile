# Choose a default image
# Check https://hub.docker.com/r/kong/kong-gateway/tags for latest versions
FROM kong/kong-gateway:2.8.1.4-alpine


# Establish variables for Kong and hardset our plugin
ENV KONG_PLUGINS: "bundled,lce-route-by-header"
# This variable informs Kong where to look for custom code
ENV KONG_LUA_PACKAGE_PATH="/usr/local/share/lua/5.1/?.lua;;/usr/local/custom/?.lua;;"

# Copy our code
COPY ./kong/plugins/lce-route-by-header /usr/local/share/lua/5.1/kong/plugins/lce-route-by-header