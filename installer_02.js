addEventListener('fetch', event => {
  const ua = event.request.headers.get('user-agent') || ''
  const isBrowser = /mozilla|chrome|safari|opera|edge/i.test(ua)
  
  if (isBrowser) {
    // Browser
    event.respondWith(new Response(
`# ZIVPN Installer - Protected v1.0
╔═════════════════════════════╗
║ 🧑‍💻 S C R I P T  B Y  မောင်သုည[🇲🇲]║
╚═════════════════════════════╝`,
      { headers: { 'Content-Type': 'text/plain; charset=utf-8' } }
    ))
  } else {
    // Terminal/curl installer script
    event.respondWith(new Response(
`#!/bin/bash
# ZIVPN Installer - Cloudflare Protected v1.0

echo "========================================"
echo "    ZIVPN ENTERPRISE INSTALLATION"
echo "    🔒 Fully Cloudflare-Embedded"
echo "========================================"

CF_WORKER="https://khaing.zivpn-delivery.workers.dev"

echo "[1] Downloading main installer..."
curl -sSL "\$CF_WORKER/udp.sh" -o /tmp/zivpn-udp.sh

chmod +x /tmp/zivpn-udp.sh
echo "[2] Running secured installer..."
bash /tmp/zivpn-udp.sh`,
      { headers: { 'Content-Type': 'text/x-shellscript' } }
    ))
  }
})
