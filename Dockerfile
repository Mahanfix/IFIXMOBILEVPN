FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/IFIXMOBILEVPN

COPY IFIXMOBILEVPN.zip /tmp/IFIXMOBILEVPN.zip

RUN unzip -q /tmp/IFIXMOBILEVPN.zip -d /opt/IFIXMOBILEVPN \
    && rm -f /tmp/IFIXMOBILEVPN.zip \
    && if [ -d /opt/IFIXMOBILEVPN/IFIXMOBILEVPN ]; then \
         cp -a /opt/IFIXMOBILEVPN/IFIXMOBILEVPN/. /opt/IFIXMOBILEVPN/; \
         rm -rf /opt/IFIXMOBILEVPN/IFIXMOBILEVPN; \
       fi

CMD ["/bin/bash"]
