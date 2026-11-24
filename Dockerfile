ARG KEYCLOAK_VERSION=26.8.2
FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION} AS builder

# Configure for Postgres
ENV KC_DB=postgres

WORKDIR /opt/keycloak
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# Azure Container Apps uses port 8080 by default
EXPOSE 8080

ENTRYPOINT ["/opt/keycloak/bin/kc.sh", "start", "--optimized", "--hostname-strict=false"]
