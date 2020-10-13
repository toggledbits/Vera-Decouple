# -----------------------------------------------------------------------------
#
# Configuration file for decouple.sh/recouple.sh.
#
# See the README for discussion on these variables. The only required variable
# to decouple is NTPSERVER.
# -----------------------------------------------------------------------------

# NTPSERVER sets the local NTP server IP address. To decouple, you must provide
# a local NTP server or your Vera will not be able to set its clock. Many
# routers and NAS systems provide a built-in NTP server that you can enable.
# Whatever you use, it is recommended that it have a hardware real-time clock
# that is battery backed. See the README for specific details.
NTPSERVER="192.168.0.15 192.168.0.44"

# Your local LAN DNS server. To fully decouple, a local LAN DNS server is
# required. Most routers provide this functionality, as well as many NAS
# systems. You can leave this commented out and your Vera will use Google DNS,
# but if Internet access fails, any plugins or other facilities on your Vera
# that need to do DNS lookups will fail during that outage. See the README.
DNSSERVER="192.168.0.15 192.168.0.44"

# LOG_SERVER and friends can be used to set up a local LAN target to which logs
# are copied when log rotation occurs. If commented out, uploading of logs is
# disabled (to both Vera/eZLO and anywhere in your LAN). Otherwise, you can un-
# comment it and set it to the name or IP address of your local log server. The
# local server must be FTP-enabled; you can set the username and password as
# needed. The target user directory must have (and own) a subdirectory with the
# same name as your Vera serial number.
LOG_SERVER=192.168.0.164
LOG_USER=veralogs
LOG_PASS=xyzzy

# SYSLOG_SERVER allows you to log system messages to a LAN-local syslog server.
# You can also change the default port (514) and protocol (default: udp; or tcp).
# If you don't know what any of this means, leave it all commented out.
SYSLOG_SERVER=192.168.0.15
#SYSLOG_PORT=514
#SYSLOG_PROTO=udp

# DAILY_BACKUP sets the target for uploading of automatic daily backups. If 
# blank or commented out, daily backups will not be performed and you need to
# back up manually yourself. Otherwise, you can set the IP address of the (FTP)
# target for backups. The target account must have a subdirectory with the same
# name as the system serial number. The DAILY_BACKUP_PROTO can be ftp (default),
# ftps (for FTP+SSL), or scp. If you use scp and you prefer to use key auth, set
# DAILY_BACKUP_PASS to @ and put the key in /etc/decouple_backup_server.key on 
# the Vera.
DAILY_BACKUP_SERVER=192.168.0.164
#DAILY_BACKUP_PROTO=ftp
DAILY_BACKUP_USER=veralogs
DAILY_BACKUP_PASS=xyzzy
