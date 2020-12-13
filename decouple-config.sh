# -----------------------------------------------------------------------------
#
# Configuration file for decouple.sh/recouple.sh.
#
# See the README for discussion on these variables.
# https://github.com/toggledbits/Vera-Decouple/blob/main/README.md
#
# -----------------------------------------------------------------------------

# NTPSERVER sets the local NTP server IP address(es) (space-separated list).
# If commented out or blank, servers at openwrt.pool.ntp.org will be used.
#NTPSERVER="192.168.0.15 192.168.0.44"
#NTPSERVER="0.fr.pool.ntp.org 1.fr.pool.ntp.org" # Example non-Vera cloud

# DNSSERVER sets the DNS server(s) to be used (space-separated list).
#DNSSERVER="192.168.0.15 192.168.0.44"
#DNSSERVER="8.8.8.8 8.8.4.4"    # Google DNS (cloud, non-Vera)

# LOG_SERVER to which to send logs when rotating.
#LOG_SERVER="192.168.0.164"
#LOG_USER="veralogs"
#LOG_PASS='magicwordshere'

# SYSLOG_SERVER allows you to log system messages to a LAN-local syslog server.
# You can also change the default port (514) and protocol (default: udp; or tcp).
# If you don't know what any of this means, leave it all commented out.
#SYSLOG_SERVER="192.168.0.15"
#SYSLOG_PORT=514
#SYSLOG_PROTO="udp"

# DAILY_BACKUP sets the target for uploading of automatic daily backups. If 
# blank or commented out, daily backups will not be performed and you need to
# back up manually yourself. Otherwise, you can set the IP address of the (FTP)
# target for backups. The target account must have a subdirectory with the same
# name as the system serial number. The DAILY_BACKUP_PROTO can be ftp (default),
# ftps (for FTP+SSL), or scp. If you use scp and you prefer to use key auth, set
# DAILY_BACKUP_PASS to @ and put the key in /etc/decouple_backup_server.key on 
# the Vera.
#DAILY_BACKUP_SERVER="192.168.0.164"
#DAILY_BACKUP_PROTO="ftp"
#DAILY_BACKUP_USER="verabackup"
#DAILY_BACKUP_PASS='magicwordsheretoo'

# KEEP_MIOS_WEATHER, if non-zero, will cause the MiOS cloud weather service to NOT
# be decoupled/disabled, so that weather information will continue to be displayed
# in the UI and by the VOTS plugin.
#KEEP_MIOS_WEATHER=1