FROM linuxserver/code-server:4.125.0

USER root

# Allow abc user to run sudo without a password
RUN echo "abc ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install Node.js 22, git, and verify
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get update && \
    apt-get install -y nodejs git xvfb x11vnc novnc websockify openbox xdotool && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    node --version && npm --version

WORKDIR /config/workspace
#///////
# Clone the Playwright MCP Javascript repository from GitHub
RUN git clone --branch main https://github.com/rohitsaraswat7865/Playwright_MCP_Javascript.git . && \
  chown -R abc:abc /config/workspace

# Document ports used by this image
# 8443 = code-server UI | 9323 = Playwright report/trace | 6080 = noVNC
EXPOSE 8443 9323 6080

# Openbox config: auto-position Playwright Inspector on the right side
RUN mkdir -p /etc/openbox && \
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<openbox_config xmlns="http://openbox.org/3.4/rc">\n  <placement>\n    <policy>Smart</policy>\n    <center>no</center>\n  </placement>\n  <applications>\n    <application title="Playwright Inspector">\n      <position force="yes"><x>1300</x><y>0</y></position>\n      <size><width>620</width><height>1080</height></size>\n    </application>\n  </applications>\n</openbox_config>\n' \
    > /etc/openbox/rc.xml

# Auto-start Xvfb, x11vnc, noVNC as s6 services on container boot
ENV DISPLAY=:1
RUN mkdir -p /custom-cont-init.d && \
    printf '#!/bin/bash\nnohup Xvfb :1 -screen 0 1920x1080x24 >/dev/null 2>&1 &\nsleep 2\nnohup openbox --display :1 --config-file /etc/openbox/rc.xml >/dev/null 2>&1 &\nnohup x11vnc -display :1 -forever -nopw -quiet -rfbport 5900 >/dev/null 2>&1 &\nsleep 1\nnohup websockify --web /usr/share/novnc 6080 localhost:5900 >/dev/null 2>&1 &\n' \
    > /custom-cont-init.d/01-vnc.sh && \
    chmod +x /custom-cont-init.d/01-vnc.sh

# Pre-install Playwright Test for VS Code extension
RUN mkdir -p /config/extensions && \
    HOME=/config /app/code-server/bin/code-server \
        --extensions-dir /config/extensions \
        --install-extension ms-playwright.playwright && \
    chown -R abc:abc /config/extensions
