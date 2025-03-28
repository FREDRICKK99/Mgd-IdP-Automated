FROM ubuntu:jammy

# Install base dependencies
RUN apt-get update && \
    apt-get install -y lsb-release curl gnupg ldap-utils debconf-utils make openssl

# Add the NetworkRADIUS repository key
RUN install -d -o root -g root -m 0755 /etc/apt/keyrings && \
    curl -s 'https://packages.networkradius.com/pgp/packages%40networkradius.com' | tee /etc/apt/keyrings/packages.networkradius.com.asc > /dev/null && \
    printf 'Package: /freeradius/\nPin: origin "packages.networkradius.com"\nPin-Priority: 999\n' | tee /etc/apt/preferences.d/networkradius > /dev/null && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.networkradius.com.asc] http://packages.networkradius.com/freeradius-3.2/ubuntu/jammy jammy main" | tee /etc/apt/sources.list.d/networkradius.list > /dev/null

# Preconfigure FreeRADIUS LDAP settings
#RUN echo "freeradius freeradius/ldap_server string ldap://mgd-idp.renu.ac.ug:389" | debconf-set-selections && \
#    echo "freeradius freeradius/ldap_server seen true" | debconf-set-selections

# Install FreeRADIUS and required packages non-interactively
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y freeradius freeradius-ldap freeradius-utils vim --no-install-recommends

# Copy configuration files
COPY ca.cnf /etc/freeradius/certs/ca.cnf
COPY client.cnf /etc/freeradius/certs/client.cnf
COPY server.cnf /etc/freeradius/certs/server.cnf

RUN cd /etc/freeradius/certs && rm *.p12 *.pem *.der *.csr *.crl *.key  index.txt* serial*  *.crt

RUN chown -R freerad:freerad /etc/freeradius

# Set up FreeRADIUS certificates
RUN cd /etc/freeradius/certs && runuser -u freerad -- make

COPY clients.conf /etc/freeradius/clients.conf
COPY proxy.conf /etc/freeradius/proxy.conf

COPY ldap /etc/freeradius/mods-available/ldap
COPY eap /etc/freeradius/mods-available/eap

COPY eduroam /etc/freeradius/sites-available/eduroam
COPY eduroam-inner-tunnel /etc/freeradius/sites-available/eduroam-inner-tunnel

# Ensure correct permissions for FreeRADIUS certificate files
RUN chown freerad:freerad /etc/freeradius/certs/server.pem && \
    chmod 600 /etc/freeradius/certs/server.pem

# Ensure entire FreeRADIUS folder is owned by freerad
RUN chown -R freerad:freerad /etc/freeradius



RUN rm -rf /etc/freeradius/sites-enabled/default
RUN rm -rf /etc/freeradius/sites-enabled/inner-tunnel

# Set up FreeRADIUS certificates
#RUN cd /etc/freeradius/certs && runuser -u freerad -- make

# Enable required FreeRADIUS modules and sites
RUN ln -s ../mods-available/ldap /etc/freeradius/mods-enabled/ldap && \
    ln -s ../sites-available/eduroam /etc/freeradius/sites-enabled/eduroam && \
    ln -s ../sites-available/eduroam-inner-tunnel /etc/freeradius/sites-enabled/eduroam-inner-tunnel

# Ensure entire FreeRADIUS folder is owned by freerad (again, after modifications)
RUN chown -R freerad:freerad /etc/freeradius

# Expose RADIUS ports
EXPOSE 1812/udp
EXPOSE 1813/udp


# Choose ONE of the following CMD instructions:

# 1. Start FreeRADIUS normally (production mode):
 CMD ["/usr/sbin/freeradius"]

# 2. Start FreeRADIUS in debug mode (for troubleshooting):
#CMD ["/usr/sbin/freeradius", "-X"]

# 3. Start FreeRADIUS as a service (if absolutely necessary):
# CMD ["/usr/sbin/freeradius"] # Use this if you have a specific reason to run it as a service


# IMPORTANT: Comment out the CMD instruction you *don't* want to use.
