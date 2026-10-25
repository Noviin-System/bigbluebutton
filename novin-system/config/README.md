# BigBlueButton Configuration Overrides Mapping

This directory maintains custom configuration overrides for BigBlueButton 3.0.x nodes.

| Local Repo Path | Deployment Target (Override Path) | Original Upstream File (Overridden) | Purpose |
| :--- | :--- | :--- | :--- |
| `config/nginx/erp-redirect.nginx` | `/etc/bigbluebutton/nginx/erp-redirect.nginx` | Drop-in include | Redirects `/b` to `/bigbluebutton` for ERP compatibility |
| `config/nginx/bigbluebutton.template` | `/etc/nginx/sites-available/bigbluebutton` | `/etc/nginx/sites-available/bigbluebutton` | Main HTTPS VHost template with SSL mappings |
| `config/nginx.conf` | `/etc/nginx/nginx.conf` | `/etc/nginx/nginx.conf` | High concurrency tuning (worker_connections, rlimit) |
| `config/journald.conf` | `/etc/systemd/journald.conf` | `/etc/systemd/journald.conf` | Limits system journal disk consumption (500M cap) |
| `config/systemd/bbb-web-override.conf` | `/etc/systemd/system/bbb-web.service.d/override.conf` | Systemd service default unit | High concurrency limit tuning (NOFILE, TasksMax) and runtime dir |
| `config/hosts.template` | `/etc/hosts` | `/etc/hosts` | Loopback binding for host FQDN and server IP |
| `config/bbb-web.properties` | `/etc/bigbluebutton/bbb-web.properties` | `/usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties` | Web settings, plugin manifests, default slide |
| `config/turnserver.conf` | `/etc/turnserver.conf` | `/etc/turnserver.conf` | Coturn server daemon configuration |
| `config/turn-stun-servers.xml` | `/etc/bigbluebutton/turn-stun-servers.xml` | `/usr/share/bbb-web/WEB-INF/classes/spring/turn-stun-servers.xml` | STUN/TURN bindings for Spring/bbb-web |
| `config/recording/presentation.yml` | `/etc/bigbluebutton/recording/presentation.yml` | `/usr/local/bigbluebutton/core/scripts/presentation.yml` | Recording video resolution and MP4 format |

### Key System Directories Reference
- **Recordings Output Directory:** `/var/bigbluebutton/published/presentation/` (Target path where processed recordings are published and served).

### Deployment Rules
- Upstream files must NOT be directly edited in place.
- All overrides must reside in `/etc/bigbluebutton/` or system daemon paths.
- Variables like `__DOMAIN__` and `__SERVER_IP__` are dynamically rendered during node provisioning.

