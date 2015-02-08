openvpn_autoconfig
==================

### Changes from Tinfoil Security version:
- Added TLS-Auth for extra security (via https://github.com/djchen/openvpn_autoconfig/commit/603fcc43d856c7313392efd912440b654900eacf)
- Use OpenDNS for resolvers
- Make RSA key a variable and use 4096 by default
- Make certificate expiration date a parameter
- Disable client certificate reuse
- Create client certificates for multiple clients
- Make OpenVPN certificate directory a setting and create directory if it doesn't exist
- Use HTTPS for acquiring IP address (via https://github.com/tinfoil/openvpn_autoconfig/commit/59fb6c47fb200d336d0e1eac884f1e3f1cc2823b)
- Use persistent IP addresses for each client
- Maximum number of clients set by length of client array
- Determine if IP tables have already been updated for OpenVPN and don't update if script is run again

Configuration scripts to automatically configure OpenVPN on an Ubuntu server.

Inspired/borrowed heavily from https://github.com/jpetazzo/dockvpn and https://www.tinfoilsecurity.com/blog/dont-get-pwned-on-public-wifi-use-your-own-vpn-tutorial-guide-how-to.

### To do
- Create setup that works with either tcp or udp
