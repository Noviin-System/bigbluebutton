# Operational Tools and Diagnostics

This directory contains utility scripts for monitoring, health checks, and log inspection on BigBlueButton 3.0.x nodes.

| Script | Purpose | Execution |
| :--- | :--- | :--- |
| `check-presentation-errors.sh` | Inspects `bbb-web` logs for document conversion errors (`CountingPageException`, timeouts) | `sudo ./check-presentation-errors.sh [YYYY-MM-DD]` |

### Quick CLI Diagnostics Cheat Sheet

- **Live inspection for CountingPageException:**
```bash
	sudo grep -m 1 -A 60 "CountingPageException" /var/log/bigbluebutton/bbb-web.log

- **Archived log inspection:**
```bash
	sudo zcat /var/log/bigbluebutton/bbb-web.YYYY-MM-DD.log.gz | grep -iE "error|failed|CountingPageException|Timeout" | tail -n 50
  
