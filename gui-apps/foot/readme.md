set it before install foot with pgo
sudo mkdir -p /var/tmp/foot-pgo-runtime
sudo chmod 700 /var/tmp/foot-pgo-runtime
 sudo XDG_RUNTIME_DIR="/var/tmp/foot-pgo-runtime"
sudo WAYLAND_DISPLAY="wayland-1"
sudo emerge -av foot
