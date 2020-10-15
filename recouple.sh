#!/bin/sh

# ------------------------------------------------------------------------------
#
# recouple.sh -- Shell script to recouple Vera after a previous decouple.sh
# Copyright (C) 2020 Patrick H. Rigney (rigpapa), All Rights Reserved
#
# Please see https://github.com/toggledbits/Vera-Decouple
#
# ------------------------------------------------------------------------------

_VERSION=20290

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

echo "Running recouple.sh version $_VERSION"

SAVEDIR=${SAVEDIR:=/root/.decouple-saved}

FORCE=0
if [ "${1:-}" == "-f" ]; then
	shift
	FORCE=1
fi
if [ $FORCE -eq 0 ]; then
	if [ ! -d ${SAVEDIR} ]; then
		cat <<-EOF1
			$0: ${SAVEDIR} not found
			Can't restore automatically. If you have a saved copy of the directory, please
			restore it to the path above and run again. If you don't have the save data,
			you can run this script with the "-f" flag and it will install system default
			versions of the config files, or you can do a factory reset of the device.
		EOF1
		exit 255
	fi
	if [ ! -f ${SAVEDIR}/decouple-version ]; then
		cat <<-EOF2
			$0: ${SAVEDIR} invalid/incomplete.
			The directory does not appear to have a decouple save in it. Make sure there
			is a / at the end of the pathname shown above. If not, please fix the setting
			used on the command line. If the path is correct, your decouple may not have
			finished. You can run this script with "-f" to force recouple; any missing
			configuration will be replaced with factory defaults.
		EOF2
		exit 255
	fi
	if [ -f ${SAVEDIR}/recoupled ]; then
		cat <<-EOF4
			$0: It appears you have already recoupled this system. You can force this
			script to run by using the -f option, but be warned that if it has been some
			time since the recouple, configuration files may have been changed auto-
			matically by the cloud services, and the recouple will reverse that, poten-
			tially installing servers that no longer exist in Vera's cloud. That risk is
			low, but present. Proceed with -f at your own risk! Here's the recouple time:
		EOF4
		ls -l ${SAVEDIR}/recoupled
		exit 255
	fi
fi

echo "Restoring default (cloud) NTP time servers..."
uci delete system.ntp.server
while uci delete ntpclient.@ntpserver[-1] >/dev/null 2>&1; do n=0; done
for s in 0.openwrt.pool.ntp.org 1.openwrt.pool.ntp.org; do
	key=$(uci add ntpclient ntpserver)
	uci set ntpclient.$key.hostname=$s
	uci set ntpclient.$key.port=123
	uci add_list system.ntp.server=$s
done
uci commit ntpclient
uci commit system.ntp
/etc/init.d/sysntpd restart
/etc/init.d/ntpclient restart

echo "Restoring default DNS servers (Google DNS)..."
uci delete dhcp.@dnsmasq[0].server
for s in 8.8.8.8 8.8.4.4; do
	uci add_list dhcp.@dnsmasq[0].server="$s"
done
uci commit dhcp
/etc/init.d/dnsmasq restart

log=$(uci -q get system.@system[0].log_ip)
if [ -n "$log" ]; then
	echo ; echo "You have enabled remote system logging (via syslog) to $log."
	askyn keep_log "Continue remote syslog [y/n]? "
	if [ "$keep_log" == "N" ]; then
		uci delete system.@system[0].log_ip
		uci delete system.@system[0].log_proto
		uci delete system.@system[0].log_port
		uci commit system
		/etc/init.d/log restart
		echo "Remote syslog now disabled."
	fi
fi

echo "Re-enabling NetworkMonitor..."
if [ ! -s ${SAVEDIR}/check_internet ]; then
	cp /mios/etc/init.d/check_internet /etc/init.d/
else
	fgrep -v 'touch /var/run/nm.stop # decouple' ${SAVEDIR}/check_internet > /etc/init.d/check_internet
fi
chmod +x /etc/init.d/check_internet
rm -f /var/run/nm.stop
if [ ! -L /usr/bin/InternetOk ]; then
	rm /usr/bin/InternetOk
	ln -s /mios/usr/bin/InternetOk /usr/bin/
fi

keep_local_backup=N
if fgrep '# decouple_daily_backup' /etc/crontabs/root >/tmp/decouple-cron ; then
	echo ; echo "Local daily backups are enabled. Recoupling will restart the cloud backups to"
	echo "Vera/MiOS/eZLO, but you have the option of continuing the local backups simul-"
	echo "taneously or disabling them."
	askyn keep_local_backup "Keep doing the daily local backups [y/n]? "
fi

echo "Restoring root's crontab..."
if [ ! -s ${SAVEDIR}/crontab-root ]; then
	crontab -u root /mios/etc/crontabs/root
else
	crontab -u root ${SAVEDIR}/crontab-root
fi
if [ "${keep_local_backup}" == "Y" ]; then
	cat /tmp/decouple-cron >>/etc/crontabs/root
fi

echo "Restoring remote access and cloud services..."
if [ ! -s ${SAVEDIR}/servers.conf ]; then
	cp /mios/etc/cmh/servers.conf /etc/cmh/ || exit 1
else
	cp ${SAVEDIR}/servers.conf /etc/cmh/ || exit 1
fi
if [ ! cp ${SAVEDIR}/services.conf /etc/cmh/ ]; then
	echo "Recovering /etc/cmh/services.conf..."
	/usr/bin/Report_AP.sh
fi
# Force relay on
sed -i 's/Permissions_Relay=.*/Permissions_Relay=1/' /etc/cmh/services.conf

. /etc/cmh/servers.conf
for s in $(awk -F= '/^Server_/ { print $1 }' /etc/cmh/servers.conf); do
	eval "Z=\$$s"
	echo "    + restoring ${s} to ${Z}"
	nvram get mios_${s} >/dev/null && nvram set mios_${s}=${Z}
	sed -i "s/^Settings_${s}=.*/Settings_${s}=${Z}/" /etc/cmh/services.conf
done

# Note we don't undo the move of dropbear because it's harmless and actually,
# an improvement Vera themselves should have made.

# Restore provisioning at boot
if [ -z "$(ls -1 /etc/rc.d/S*-provision_vera.sh 2>/dev/null)" ]; then
	# Note on Edge is /mios, the .sh is missing; present on Plus
	cp -P /mios/etc/rc.d/S*-provision_vera* /etc/rc.d/
fi
if [ -z "$(ls -1 /etc/rc.d/S*-cmh-ra 2>/dev/null)" ]; then
	cp -P /mios/etc/rc.d/S*-cmh-ra /etc/rc.d/
fi
# NB: Not replacing mios_fix_time, since its brokenness is regressive.

# And our own boot script
rm -f /etc/init.d/decouple /etc/rc.d/S*decouple

[ -f ${SAVEDIR}/decouple-version ] && touch ${SAVEDIR}/recoupled

cat <<EOF3
Done! Cloud service configuration has been restored.
	* The changes do not take effect until you have completed a full reboot.
	* Once you have verified that the system is working satisfactorily, you
	  may delete the decouple save directory (recommended); it is:
	  ${SAVEDIR}

Reboot your Vera now by typing: /sbin/reboot
EOF3

exit 0
