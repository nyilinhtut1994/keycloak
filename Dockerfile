FROM quay.io/keycloak/keycloak:latest as builder

# Configure for Postgres
ENV KC_DB=postgres

# Download SCIM 2.0 extension (Captain-P-Goldfish/scim-for-keycloak)
# Check https://github.com/Captain-P-Goldfish/scim-for-keycloak/releases for the version
# matching your Keycloak major version (KC_MAJOR) before deploying.
ARG KC_MAJOR=26
ARG SCIM_VERSION=7.7.1
RUN curl -fsSL \
  "https://github.com/Captain-P-Goldfish/scim-for-keycloak/releases/download/keycloak-scim-${SCIM_VERSION}/scim-for-keycloak-kc-${KC_MAJOR}-b${SCIM_VERSION}.jar" \
  -o /opt/keycloak/providers/scim-for-keycloak.jar

WORKDIR /opt/keycloak
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:latest
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# Azure Container Apps uses port 8080 by default
EXPOSE 8080

ENTRYPOINT ["/opt/keycloak/bin/kc.sh", "start", "--optimized", "--hostname-strict=false"]
