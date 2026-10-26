# hl2270dw-ipp-bridge

Helm chart for the Brother HL-2270DW CUPS IPP-Everywhere bridge, so
Windows 11 Protected Print mode can use it. It deploys the
[`hl2270dw-ipp-bridge`](https://github.com/dtandersen/dockerfiles/tree/main/hl2270dw-ipp-bridge)
image. It is built on the TrueCharts
[`common`](https://truecharts.org/common/) library chart.

The printer alone is IPP 1.0 + PCL-only (no PDF/PWG-Raster, not Mopria
certified). The bridge fronts it with CUPS IPP 2.0/2.1 +
`mopria-certified 1.3`, advertising `application/pdf, image/pwg-raster,
image/urf`. Windows sends PDF to the bridge, CUPS renders PDF -> PCL via
Ghostscript + brlaser, then forwards RAW to the printer.

## Values

```yaml
printer:
  name: HL2270DW
  deviceUri: socket://192.168.100.1:9100
  ppd: ""
```

These render as the image's `PRINTER_NAME`, `PRINTER_DEVICE_URI`, and
`PRINTER_PPD` environment variables. `printer.name` is the CUPS queue name,
also the IPP resource path `ipp://<svc>:631/printers/<name>`.
`printer.deviceUri` is the backend URI — `socket/9100` RAW is most reliable
for the HL-2270DW; change it if your printer DHCP moves. `printer.ppd`
overrides the driver (e.g. `drv:///brlaser.drv/br2270dw.ppd`); empty means
auto-pick 2270dw > brlaser > generpcl.

The chart also ships these defaults:

- image `ghcr.io/dtandersen/hl2270dw-ipp-bridge:main`
- a `Deployment` (single replica, `Recreate`) with `emptyDir` volumes for
  `/etc/cups`, `/var/spool/cups`, `/var/cache/cups`
- a `LoadBalancer` service on TCP `631` -> container `8631` (Windows must reach IPP on the LAN —
  ClusterIP alone is not enough; the container listens on unprivileged 8631)
- TCP probes on `8631`
- `lp` (uid/gid 7, created by the cups package) via a minimal securityContext
  override — TrueCharts defaults to 568, but `lp` already owns CUPS spool/cache
  dirs. Still no root, no capabilities; unprivileged 8631, logs to stderr;
  `/etc/cups`, `/var/spool/cups`, `/var/cache/cups` are writable `emptyDir` mounts

There is no mDNS through Kubernetes, so add the printer in Windows
manually by URL:

```text
http://<bridge-ip>:631/printers/HL2270DW
```

Driver: Microsoft IPP Class Driver (inbox, automatic in Protected Print mode).
Pin a stable LAN IP with `service.main.loadBalancerIP` (MetalLB pool, same
subnet as Windows clients) so the URL survives pod restarts, or switch
`service.main.type` to `NodePort` without MetalLB.

## Helmfile

```yaml
releases:
  - name: hl2270dw-ipp-bridge
    chart: dtandersen/hl2270dw-ipp-bridge
    namespace: printing
    createNamespace: true
    values:
      - printer:
          deviceUri: socket://192.168.100.1:9100
        service:
          main:
            # loadBalancerIP: 192.168.100.10
            type: LoadBalancer
```

All other values are supplied by the TrueCharts common chart. See the [common
chart documentation](https://truecharts.org/common/) for options including
`resources`, `podOptions`, `persistence`, `service`, `ingress`, `hpa`, and
security contexts.
