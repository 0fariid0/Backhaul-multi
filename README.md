```
./backhaul
```
```
sniffer = true  
web_port = 2060 
sniffer_log = "backhaul.json"
```
wws
✅ ترنسپورت wss اضافه شد. برای استفاده در cdn کلادفلر و اتصال با پورت‌های https به کار میاد. سرور ایران نیاز به tls داره ولی سرور خارج فعلا روی حالت allow insecure هست.

✅ یه باگ کوچیکی که گاهی اوقات در ws رخ میداد هم حل شد. 

✅ برای wss در فایل کانفیگ سرور ایران باید دو مورد زیر رو اضافه کنید:
```
tls_cert = "/root/server.crt"      
tls_key = "/root/server.key"
```


```
[server]# Local, IRAN
bind_addr = "0.0.0.0:3080" # Address and port for the server to listen (mandatory).
transport = "tcp"          # Protocol ("tcp", "tcpmux", or "ws", optional, default: "tcp").
token = "your_token"       # Authentication token (optional).
keepalive_period = 20      # Specify keep-alive period in seconds. (optional, default: 20 seconds)
nodelay = false            # Enable TCP_NODELAY (optional, default: false).
channel_size = 2048        # Tunnel channel size. Excess connections are discarded. Only for tcp and ws mode (optional, default: 2048).
connection_pool = 8        # Number of pre-established connections. Only for tcp and ws mode (optional, default: 8).
mux_session = 1            # Number of mux sessions for tcpmux. (optional, default: 1).
log_level = "info"         # Log level ("panic", "fatal", "error", "warn", "info", "debug", "trace", optional, default: "info").

ports = [ # Local to remote port mapping in this format LocalPort=RemotePort (mandatory).
    "4000=5201",
    "4001=5201",
]
```
```
[client]  # Behind NAT, firewall-blocked
remote_addr = "0.0.0.0:3080" # Server address and port (mandatory).
transport = "tcp"            # Protocol ("tcp", "tcpmux", or "ws", optional, default: "tcp").
token = "your_token"         # Authentication token (optional).
keepalive_period = 20        # Specify keep-alive period in seconds. (optional, default: 20 seconds)
nodelay = false              # Use TCP_NODELAY (optional, default: false).
retry_interval = 1           # Retry interval in seconds (optional, default: 1).
log_level = "info"           # Log level ("panic", "fatal", "error", "warn", "info", "debug", "trace", optional, default: "info").
mux_session = 1              # Number of mux sessions for tcpmux. (optional, default: 1).

forwarder = [ # Forward incoming connection to another address. optional.
   "4000=IP:PORT",
   "4001=127.0.0.1:9090",
]
```
