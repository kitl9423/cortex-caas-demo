FROM distributions.traps.paloaltonetworks.com/agent-docker-pull/aaa1c5b345734aebbb61d0bcebc41fa2/method:9.3.0.220 AS cortex_agent

# 1. Base image vulnerable to Spring4Shell
FROM tomcat:9.0.59-jdk11-openjdk-slim

# 2. Install wget to download malware, clear default Tomcat apps
RUN apt-get update && apt-get install -y wget curl && rm -rf /usr/local/tomcat/webapps/*

# 3. Copy the compiled vulnerable Spring application
COPY app/target/helloworld.war /usr/local/tomcat/webapps/ROOT.war

# 4. Create malware directory
RUN mkdir -p /tmp/malware && chmod 777 /tmp/malware

# 5. Inject the plain text file for the Secret Scanning demo
# Creating a specific directory makes it easy to point out during the demo
RUN mkdir -p /opt/secrets
COPY dummy-aws-creds.txt /opt/secrets/aws-credentials.txt

# 6. Expose default port
EXPOSE 8080

# 7. Define Entrypoint

# --- Cortex Agent ---

USER root

COPY --from=cortex_agent /opt/traps /opt/traps
COPY --from=cortex_agent /etc/panw-init /etc/panw-init
COPY --from=cortex_agent /var/log/traps-install.log /var/log/traps-install.log
COPY --from=cortex_agent /etc/ssl/certs/ /etc/ssl/certs/
COPY --from=cortex_agent /usr/share/ca-certificates/ /usr/share/ca-certificates/

ENV XDR_CA_CERTS_LOCATION="/etc/ssl/certs/ca-certificates.crt" \
    XDR_INIT_ROOT_DIR="/etc/panw-init" \
    XDR_DISTRIBUTION_ID="aaa1c5b345734aebbb61d0bcebc41fa2" \
    XDR_CONTAINER_MODE="embeddedcontainer" \
    XDR_DISTRIBUTION_SERVER="https://distributions.traps.paloaltonetworks.com"

RUN mkdir -p /usr/lib/ssl/certs && \
    ln -sf /etc/ssl/certs/ca-certificates.crt /usr/lib/ssl/cert.pem && \
    ln -sf /etc/ssl/certs /usr/lib/ssl/certs

RUN ln -sf /opt/traps/bin/initd /initd

RUN /opt/traps/scripts/embedded_caas/musl_compat.sh \
 && /opt/traps/scripts/embedded_caas/alpine_shims.sh

RUN mkdir -p /etc/panw && echo '["catalina.sh", "run"]' > /etc/panw/dypd_entry && chmod 666 /etc/panw/dypd_entry

ENTRYPOINT ["/initd"]
