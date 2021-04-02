#!/bin/sh

# ------------------------------------------------------------------------------
#
# decouple.sh -- Shell script to decouple Vera from its cloud services.
# Copyright (C) 2020 Patrick H. Rigney (rigpapa), All Rights Reserved
#
# Please see decouple-config.sh for special configuration information.
# READ THE DOCUMENTATION AT https://github.com/toggledbits/Vera-Decouple
#
# ------------------------------------------------------------------------------

_VERSION=21091

askyn() {
	local __ans
	local __resultvar
	__resultvar="${1:-ans}"
	while true; do
		echo -e -n "${2:-}"
		read __ans
		case "$__ans" in
			[Yy]* )
				eval "${__resultvar}=Y"
				break
				;;
			[Nn]* )
				eval "${__resultvar}=N"
				break
				;;
		esac
		echo "Please answer Y or N."
	done
}

echo "Running decouple.sh version $_VERSION"

[ -d /etc/cmh ] || { echo "$0: runs on Vera Plus, Secure, Edge only"; exit 255; }

if [ -s /proc/diag/model ]; then
	p=$(cat /proc/diag/model)
else
	p=$(awk '/^machine/ { print $4 }' /proc/cpuinfo)
fi
if [ -z "$p" ]; then
	p=$(cat /etc/cmh/vera_model)
fi
case "$p" in
	"NA301"|"G450"|"G550") # Vera Edge|Plus|Secure
		;;
	"930") # Plus, Edge via /etc/cmh/vera_model
		;;
	*)
		echo "$0 does not work on this Vera model (${p})."
		echo "It only works on Vera Plus, Secure, and Edge."
		exit 255
esac
fw=$(fgrep 1.7. /etc/cmh/version | sed 's/1.7.//')
if [[ "$fw" == "" || $fw -lt 4452 || $fw -gt 5351 ]]; then
	echo "$0 is not certified for systems running $(cat /etc/cmh/version)."
	exit 255
fi
if [ ! -f decouple-config.sh ]; then
	echo "$0: can't find config file decouple-config.sh"
	exit 255
fi

if [ ! -f /usr/bin/nano ]; then
	echo "It appears the 'nano' editor is not installed. If you're comfortable with"
	echo "'vi', that's not a problem, but I can install nano for you now, if you wish."
	askyn inst_nano "Install nano editor now [y/n]? "
	if [ "${inst_nano}" == "Y" ]; then
		opkg update
		opkg install nano
	fi
fi

. decouple-config.sh

SAVEDIR=${SAVEDIR:-/root/.decouple-saved}

if [ -f ${SAVEDIR}/recoupled ]; then
	echo "$0: ${SAVEDIR} already used"
	echo "The decouple save directory appears to have already been used to recouple. If"
	echo "it has been some time since your last decouple/recouple, the saved config-"
	echo "uration could be stale and invalid."
	askyn ans "Do you want to clear the data and start fresh [Y/N]? "
	[ "${ans:-}" == "Y" ] && rm -f ${SAVEDIR}/*
fi

askyn ans "Preliminary checks OK. Decouple this Vera from cloud services [Y/N]? "
[ "${ans:-}" == "Y" ] || exit 255

mkdir -p ${SAVEDIR}/

if [ -n "${NTPSERVER:-}" ]; then
	echo "Setting NTP server(s) to ${NTPSERVER}... "
	words="${NTPSERVER}"
else
	echo "Setting default NTP servers (openwrt.pool.ntp.org)..."
	words="0.openwrt.pool.ntp.org 1.openwrt.pool.ntp.org"
fi
if [ -n "$words" ]; then
	uci delete system.ntp.server
	while uci delete ntpclient.@ntpserver[-1] >/dev/null 2>&1; do n=0; done
	for s in $words; do
		key=$(uci add ntpclient ntpserver)
		uci set ntpclient.$key.hostname=$s
		uci set ntpclient.$key.port=123
		uci add_list system.ntp.server=$s
	done
	uci commit ntpclient
	uci commit system.ntp
	/etc/init.d/sysntpd restart
	/etc/init.d/ntpclient restart
else
	echo "*** No NTP configuration changes are being made."
fi

if [ -n "${DNSSERVER:-}" ]; then
	echo "Setting DNS server(s) to ${DNSSERVER}..."
	words="${DNSSERVER}"
else
	echo "Setting default DNS servers (Google DNS)..."
	words="8.8.8.8 8.8.4.4"
fi
if [ -n "$words" ]; then
	uci delete dhcp.@dnsmasq[0].server
	for s in $words; do
		uci add_list dhcp.@dnsmasq[0].server="$s"
	done
	if [ ${KEEP_MIOS_WEATHER:-0} -ne 0 ]; then
		noms="apps.mios.com"
	else
		noms="weather.mios.com apps.mios.com"
	fi
	for s in ${noms}; do
		uci add_list dhcp.@dnsmasq[0].server="/$s/"
	done
	uci commit dhcp
	/etc/init.d/dnsmasq restart
else
	echo "*** No DNS configuration changes are being made."
fi

if [ -n "${SYSLOG_SERVER:-}" ]; then
	echo "Enabling syslog remote logging to ${SYSLOG_SERVER}..."
	uci set system.@system[0].log_ip=${SYSLOG_SERVER}
	uci set system.@system[0].log_port=${SYSLOG_PORT:-514}
	uci set system.@system[0].log_proto=${SYSLOG_PROTO:-udp}
	uci commit system
	/etc/init.d/log restart
elif fgrep log_ip /etc/config/system >/dev/null; then
	echo "Disabling syslog remote logging..."
	uci delete system.@system[0].log_ip >/dev/null 2>&1
	uci delete system.@system[0].log_port >/dev/null 2>&1
	uci delete system.@system[0].log_proto >/dev/null 2>&1
	uci commit system
	/etc/init.d/log restart
fi

if [ -n "${DAILY_BACKUP_SERVER:-}" ]; then
	echo "Setting up daily system backups to ${DAILY_BACKUP_SERVER} via ${DAILY_BACKUP_PROTO:-ftp}..."
	usr=${DAILY_BACKUP_USER:-verabackup}
	if [ "${DAILY_BACKUP_PROTO:-}" == "scp" ]; then
		if [ "${DAILY_BACKUP_PASS:-}" == "@" ]; then
			opts="-i /etc/dropbear/dropbear_rsa_host_key"
			targ="${usr}@${DAILY_BACKUP_SERVER}"
		else
			opts=""
			targ="${usr}:${DAILY_BACKUP_PASS:-}@{DAILY_BACKUP_SERVER}"
		fi
		cat <<SCPBACKUPSCRIPT >/usr/bin/decouple_daily_backup.sh
#!/bin/sh

# DO NOT EDIT -- AUTOMATICALLY GENERATED FILE
# This file is part of rigpapa's decoupler. See https://github.com/toggledbits/Vera-Decouple
# Created by $_VERSION on $(date)

ser="\$(nvram get vera_serial)"
target="${targ}"
dest_path="\${ser}/ha-gateway-backup_\${ser}_\$(cat /etc/cmh/version)_\$(date +%F).tgz"

sh /usr/bin/backup-store.sh D
scp ${opts} /tmp/Backup_download.tgz \${target}:\${dest_path}
rm -f /tmp/Backup_download.tgz
SCPBACKUPSCRIPT
	else
		cmd="curl -T - -m 300 --connect-timeout 15"
		if [ "${DAILY_BACKUP_PROTO:-}" == "ftps" ]; then
			cmd="${cmd} --ftp-ssl"
		elif [ "${DAILY_BACKUP_PROTO:-ftp}" != "ftp" ]; then
			echo "Invalid DAILY_BACKUP_PROTO ('${DAILY_BACKUP_PROTO}'); only ftp, ftps, scp allowed."
			exit 255
		fi
		cat <<FTPBACKUPSCRIPT >/usr/bin/decouple_daily_backup.sh
#!/bin/sh

# DO NOT EDIT -- AUTOMATICALLY GENERATED FILE
# This file is part of rigpapa's decoupler. See https://github.com/toggledbits/Vera-Decouple
# Created by $_VERSION on $(date)

ser="\$(nvram get vera_serial)"
target_host="${DAILY_BACKUP_SERVER}"
target_auth="${usr}:${DAILY_BACKUP_PASS:-}"
dest_path="\${ser}/ha-gateway-backup_\${ser}_\$(cat /etc/cmh/version)_\$(date +%F).tgz"

sh /usr/bin/backup-store.sh D
cat /tmp/Backup_download.tgz | ${cmd} ftp://\${target_auth}@\${target_host}/\${dest_path}
rm -f /tmp/Backup_download.tgz
FTPBACKUPSCRIPT
	fi
	chmod +rx /usr/bin/decouple_daily_backup.sh
fi

if [ ! -f ${SAVEDIR}/services.conf ]; then
	cp /etc/cmh/services.conf ${SAVEDIR}/services.conf || exit 1
fi
if ! fgrep 'Permissions_Relay=0' /etc/cmh/services.conf >/dev/null; then
	echo "Disabling Vera's remote access services..."
	sed -i 's/Permissions_Relay=.*/Permissions_Relay=0/' /etc/cmh/services.conf
	/etc/init.d/cmh-ra stop
fi

echo "Disabling NetworkMonitor..."
if [ -L "/usr/bin/InternetOk" ]; then
	rm -f /usr/bin/InternetOk # unlink
	echo 'exit 0 # decouple' >/usr/bin/InternetOk
fi
chmod +rx /usr/bin/InternetOk
if grep '^NM_WATCHDOG_FILE=' /usr/bin/Rotate_Logs.sh >/dev/null; then
	rm -f /usr/bin/Rotate_Logs.sh
	sed '/^NM_WATCHDOG_FILE=/,/^fi/c \
		# decouple removed \
		' </mios/usr/bin/Rotate_Logs.sh >/usr/bin/Rotate_Logs.sh
fi
chmod +rx /usr/bin/Rotate_Logs.sh
if ! grep '^exit 0 # decouple' /usr/bin/Start_NetworkMonitor.sh >/dev/null; then
	rm -f /usr/bin/Start_NetworkMonitor.sh
	sed '/===BEGIN===/a \
log "$0 disabled by decouple" # decouple \
touch /var/run/nm.stop # decouple \
exit 0 # decouple \
' </mios/usr/bin/Start_NetworkMonitor.sh >/usr/bin/Start_NetworkMonitor.sh
fi
chmod +rx /usr/bin/Start_NetworkMonitor.sh
if [ ! -f ${SAVEDIR}/check_internet ]; then
	cp /etc/init.d/check_internet ${SAVEDIR}/
fi
if ! fgrep 'touch /var/run/nm.stop # decouple' /etc/init.d/check_internet >/dev/null; then
	awk '/bin\/Start_NetworkMonitor.sh/ { print "touch /var/run/nm.stop # decouple.sh"; print $0; next } { print; }' </etc/init.d/check_internet >/tmp/decouple.tmp && \
		mv /tmp/decouple.tmp /etc/init.d/check_internet
fi
chmod +rx /etc/init.d/check_internet
/etc/init.d/check_internet stop >/dev/null 2>&1
touch /var/run/nm.stop

echo "Updating root's crontab..."
if [ ! -f ${SAVEDIR}/crontab-root ]; then
	crontab -u root -l > ${SAVEDIR}/crontab-root
fi
# 20290: &servi pattern is to fix a stray newline output in 20289
crontab -u root -l | \
	grep -Fv '# decouple' | \
	grep -v '&servi *$' | \
	awk '/^#/ { print; next } /Rotate_Logs/ { print; next } { print "# "$0 }' >/tmp/decouple.tmp
cat <<CRONMORE >>/tmp/decouple.tmp
# decouple additions ($_VERSION)
0 */4 * * * rm -f /etc/cmh/alerts.json /etc/cmh/persist/* # decouple
CRONMORE
if [ -n "${DAILY_BACKUP_SERVER:-}" ]; then
	cat <<BACKUPCRON >>/tmp/decouple.tmp
23 0 * * * curl -o - -m 30 'http://127.0.0.1:3480/data_request?id=action&serviceId=urn:micasaverde-com:serviceId:ZWaveNetwork1&action=BackupDongle&DeviceNum=1' 2>&1 | logger -t decouple_daily_backup # decouple
5 0 * * * /usr/bin/decouple_daily_backup.sh 2>&1 | logger -t decouple_daily_backup # decouple
BACKUPCRON
fi
crontab -u root /tmp/decouple.tmp && rm /tmp/decouple.tmp

echo "Decoupling Vera cloud servers..."
if [ ! -f ${SAVEDIR}/servers.conf ]; then
	cp /etc/cmh/servers.conf ${SAVEDIR}/servers.conf || exit 1
fi
. /etc/cmh/servers.conf
for s in $(awk -F= '/^Server_/ { print $1 }' /etc/cmh/servers.conf); do
	eval "Z=\$$s"
	# echo "    + updating ${s} to ${Z}"
	nvram get mios_${s} >/dev/null && nvram set mios_${s}=${Z}
	sed -i "s/^Settings_${s}=.*/Settings_${s}=${Z}/" /etc/cmh/services.conf
done
nvram commit >/dev/null 2>&1

if [ -z "${LOG_SERVER:-}" ]; then
	echo "Turning off log uploads..."
	sed -i 's/ArchiveLogsOnServer=1/ArchiveLogsOnServer=0/' /etc/cmh/cmh.conf
else
	echo "Turning on log uploads to ${LOG_SERVER}..."
	sed -i 's/ArchiveLogsOnServer=0/ArchiveLogsOnServer=1/' /etc/cmh/cmh.conf
	sed -i "s/Server_Log_User=.*/Server_Log_User=/" /etc/cmh/servers.conf
	sed -i "s/Server_Log_Pass=.*/Server_Log_Pass=/" /etc/cmh/servers.conf
fi
awk '/^Server_/ { sub("=.*$", "=127.0.0."NR); print; next } { print }' < ${SAVEDIR}/servers.conf > /etc/cmh/servers.conf
if [ -n "${LOG_SERVER:-}" ]; then
	sed -i "s/Server_Log=.*/Server_Log=${LOG_SERVER}/" /etc/cmh/servers.conf
	sed -i "s/Server_Log_User=.*/Server_Log_User=${LOG_USER}/" /etc/cmh/servers.conf
	sed -i "s/Server_Log_Pass=.*/Server_Log_Pass=${LOG_PASS}/" /etc/cmh/servers.conf
fi

# PLATFORM: NA301 on 5245, dropbear starts at 50
# PLATFORM: G450 on 5186, dropbear starts at 15 (before network at 20?)
# Start dropbear earlier, so we can debug other startup problems more easily.
if [ -L /etc/rc.d/S50dropbear ]; then
	sed -i 's/START=.*/START=21/' /etc/init.d/dropbear
	mv -f /etc/rc.d/S50dropbear /etc/rc.d/S21dropbear
fi

# Prevent the provisioning scripts from running at boot. We're provisioned,
# and running it with no auth servers stalls the boot.
rm -f /etc/rc.d/S*-provision_vera*
rm -f /etc/rc.d/S*-cmh-ra

# OpenWRT has a default sysfixtime that runs early (first) and does a good job of
# approximating a usable time prior to NTP service. Vera then runs a script that
# undoes that, disastrously. Disable the Vera script on systems that don't have RTC
# (I'm not even sure what, if any, do).
[ -e /dev/rtc0 ] || rm -f /etc/rc.d/S*mios_fix_time*

# Our own startup script
cat <<BOOTSCRIPT >/etc/init.d/decouple
#!/bin/sh /etc/rc.common

# Inserted by decouple $_VERSION

START=999

boot() {
	/usr/bin/set_led.sh off service
}
BOOTSCRIPT
chmod +rx /etc/init.d/decouple
( cd /etc/rc.d/ ; ln -sf ../init.d/decouple S999decouple )

cp decouple-config.sh ${SAVEDIR}/
echo -n "$_VERSION" >${SAVEDIR}/decouple-version

if [ -n "${DAILY_BACKUP_SERVER}" -a "${DAILY_BACKUP_PROTO}" == "scp" -a "${DAILY_BACKUP_PASS}" == "@" ]; then
	echo ; echo "*** Don't forget to append the following public key to the SSH authorized_keys"
	echo "    file for user ${DAILY_BACKUP_USER:-verabackup} on your backup server ${DAILY_BACKUP_SERVER}."
	echo "    Although it may wrap on your screen, it should be placed as a single (long)"
	echo "    line in the authorized_hosts file. A copy of this key has been left in file"
	echo "    /root/vera-ssh-pubkey.txt as well."
	dropbearkey -y -f /etc/dropbear/dropbear_rsa_host_key | grep -i '^ssh-rsa' | tee /root/vera-ssh-pubkey.txt
fi

cat <<EOF

OK. We're done here. Your Vera has been decoupled from the Vera/eZLO cloud services.
When ready, please reboot by running /sbin/reboot
EOF

exit 0
