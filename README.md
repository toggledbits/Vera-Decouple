# Vera Cloud De-coupler/Re-coupler

**KNOW WHAT YOU'RE GETTING INTO: READ THIS ENTIRE DOCUMENT BEFORE DOING ANYTHING.**

These scripts decouple a Vera Home Automation Controller from the many cloud services to which it normally connects. It is generally accepted that Veras are more stable when not connected to the mother ship, as outages of these cloud services often causes spurious reloads of Luup or even reboots of the system. Decoupled systems use less RAM and CPU as well.
Decoupling also improves system reliability when Internet access is not available.

The only required services are DNS and NTP (time), and a lapse in the former does not affect system stability. If one provides a stable local NTP server (which can be as simple and inexpensive as a RPi/ESP8266/ESP32 with an add-on RTC), then it is possible to run a decoupled Vera entirely off-grid with no Internet access whatsoever and have a stable system.

The scripts also make facilities for local (LAN) storage of rotated log files and daily configuration backups.

## System Requirements

These scripts are intended only for Vera Plus, Secure and Edge system running 7.0.29 firmware or higher (to the current release version as of this writing). Users on 7.0.30, which existed only in a public beta, are advised to upgrade to 7.0.31, as the earlier firmware has a specific defect that causes "Christmas Lights" (blinking status lights on an otherwise dead unit) when Internet access becomes unavailable for an extended period of time.

Do not use these scripts on any Vera that does not meet the above requirements.

## Cautions and Disclaimer

**THESE SCRIPTS ARE EXPERIMENTAL. YOUR USE OF THESE SCRIPTS IS SOLELY AND ENTIRELY AT YOUR OWN RISK, WITHOUT RESERVATION.** I've received no help from Vera in creating these scripts, it's all based on years of discovery and learning about these systems organically. But I have no direct visibility to the source code or internals of many Vera-created parts of these systems, including Luup itself and the many tools they've added to the base OS to make it their own. Most of the learning has therefore been done in a wake of experiments, many failed; some of those failures are obvious immediately, and some take weeks or months to manifest. Things can change on these systems without notice, so while these appear to work now, Vera/eZLO can do anything it wants, including taking specific action to prevent the operation of these scripts, in future. **THESE SCRIPTS ARE THEREFORE OFFERED AS-IS AND AS-AVAILABLE WITH NO WARRANTIES, EXPRESS OR IMPLIED, WHATSOEVER.**

Decoupling from Vera's cloud is not without consequences; these include:

* Remote access isn't possible, including that by Vera/eZLO support, unless you later recouple. **Vera Support will likely take the view that this script voids your system warranty.**
* Uploading of logs to their cloud services doesn't happen, so even if you recouple and give Vera Support access to your unit, they won't have logs for events prior to the recouple.
* Certain pages within the UI will not work in the absence of Vera's cloud services, including *Settings > Location* and *Settings > Firmware*.
* Native Vera notifications, including those driven through Reactor and VeraAlerts, will not work. Other notification methods should continue to be available, however.
* You will not have access to the App Marketplace for plugins (you can still manually install them via *Apps > Develop apps*).
* Daily backups of your system to Vera's storage won't be done. The script provides a facility for daily backups to be performed and uploaded to a local server that you provide, if you wish. Otherwise, you will need to do backups manually.

Common sense applies here. Vera has gone to great lengths to design a system that runs tightly with their cloud services. Disabling their cloud services forces the system to run in a manner counter to its design, and that has inherent risks known, anticipated, and unforeseen. You accept these risks as your own and are going in eyes wide open.

## Status

Vera Edge: Version 20288, tested by rigpapa 2020-10-14, running property on 5245 (7.32 beta)

Vera Plus: Version 20288, tested by rigpapa 2020-10-14, running property on 5186 (7.31 GA)

Vera Secure: NOT TESTED

## Preparation

First, make sure your Vera is fully configured:

* The unit is registered and listed in your Controllers list at https://home.getvera.com;
* The unit's location settings are properly set (*Settings > Location*);
* The unit is running the version of firmware that you want to run, and that version is supported by this tool;
* All of the other settings under *Users & Account Info* are properly configured;
* You have installed any plugins from the App Marketplace that can only be installed from there.

Second, you're going to need to decide if you want to continue to use external (cloud) time servers, or use a local (LAN) time server. It's not strictly necessary to use a local LAN server, and there are many ways to build such a server and end up no better than if you didn't have one and just stuck with the cloud. See my discussion toward the end of this document regarding the merits and problems of various options.

* If your Internet access is stable most of the time and you rarely have power failures, and when you do have power failures, it's OK with you if the Vera needs a few minutes and maybe an automatic reboot/reload or two before it stabilizes, then using the default cloud time servers (pool.ntp.org) is OK. Note that even brief periods of "bogus" time on your Vera can cause it to fire date/time-based automations errantly.
* If you regularly have no Internet access, frequent prolonged outages of Internet, requent power failures, or use a lot of time-based automations, then setting up a local NTP server is likely the better choice. Again, see the discussion on choosing/building an NTP time server near the end of this document.

Finally, you'll need to make a similar decision for DNS. The default DNS servers are the Google DNS servers at 8.8.8.8 and 8.8.4.4. This is probably fine, but there are good arguments to be made that a local DNS service provided by your router or another device in your network is actually a better choice. Either way, the availability of DNS will not affect system stability, so do what makes the most sense to you (I use my router's DNS cache/forwarder).

> TIP: Your NTP and DNS servers, and your Vera, should all use static IP addresses, in case the network's DHCP server is down or fails.

## Configuring for Decoupling

Configuration is done by modifying the `decouple-config.sh` file (only &mdash; do not modify the other files). This can be done on a Windows or other system before uploading the script package to your Vera, or you can just do the editing on your Vera. If you choose to do the latter, you should either be comfortable in `vi`, or have the alternate (and easier) `nano` editor installed. `nano` is not normally installed on factory Vera systems, so if you need it, you'll need to install it by issuing the following commands:

```
opkg update
opkg install nano
```

Everything in the configuration file has reasonable defaults. The default value will be used when the configuration variable is either commented out or set to blank. A variable is commented out when a '#' appears in the left margin before its name. To uncomment a variable, remove that '#', and then add any value to the right of the equal ('=') sign. Do not change the name of the variable, or add any spaces before or after the equal sign. Although it is usually not necessary, you can surround the value in double-quote marks (i.e. `DNSSERVER=192.168.0.1` and `DNSSERVER="192.168.0.1"` are equivalent).

OK. Ready? Let's see what we can configure...

### NTP -- Network Time

To use a local NTP server, uncomment and set the `NTPSERVER` variable to its IP address. If you want to use the default cloud (`openwrt.pool.ntp.org`) time servers, you can either leave this variable commented out or blank. If you want to provide your own server pool, put in the full hostname of the pool (e.g. if you're in Oz, you might decide to use `0.au.pool.ntp.org`). The closer the server/pool is, the better.

If you have multiple NTP servers, list them comma-separated and surrounded in quotes, like this:

```
NTPSERVER="192.168.0.15 192.168.0.44"
```

### DNS -- Always Cloudy

If you choose to use a local (LAN) DNS server, uncomment and set the `DNSSERVER` variable in `decouple-config.sh` to its IP address. To keep the system defaults (Google DNS), set the variable blank or leave it commented out.

You can set multiple DNS servers by listing them with spaces between, surrounded in quotes:

```
DNSSERVER="192.168.0.15 192.168.0.44"
```

> No matter what we do, Vera will always require a source of DNS (Domain Name Service) services &mdash; one or more servers that translate internet names to addresses. This is so fundamental to the operation of any network device that it's impossible to completely divorce it from the cloud. DNS is probably *the* original cloud service, dating back many decades to the very origins of IP networking. Even if you have a local DNS server, it still reaches out over the Internet to other servers to resolve names; it's inescapable. The good news is, DNS failures generally do not affect stability of your Vera. It may cause plugins that use remote APIs some heartburn, but the most likely cause of DNS failures is loss of Internet access, and those plugins aren't getting to those APIs under those circumstances then anyway.

### Vera Log Files (LuaUPnP.log)

Veras optionally upload their log files to the Vera/eZLO cloud (a feature you can turn on and off through the UI). The `decouple.sh` script can redirect this uploading to a server on your LAN, if you choose. If you uncomment and set the `LOG_SERVER` variable in `decouple-config.sh`, the script will configure your Vera to upload logs to that target server. The target server must have FTP enabled; this is the only protocol available. You will need to create an FTP account on the server to which the log files can be uploaded. Supply the username and password for the account in the `LOG_USER` and `LOG_PASS` variables. The home directory on the FTP server must have a subdirectory named for the serial number of your Vera; this subdirectory is where the Vera will drop the files.

The uploading of log files is controlled by the "Archive old logs on MiOS" setting in the Vera UI's *Settings > Logs* page. If you have set up a local log server, you can turn the uploading on and off at will without disrupting the local target server configuration. Note, however, that if you do not set up a local log server when you decouple, and you enable this setting, the Vera will attempt to upload log files to a non-existent IP address and errors will be generated in various logs on the Vera. I'm not yet sure what the long-term effect may be, but it could include filling up disk space, so be careful here.

### Daily Backups

A cloud-coupled Vera will upload daily backups to the Vera/MiOS/eZLO cloud storage servers. Decoupled systems, of course, cannot. If you have a local server to which backups can be uploaded, uncomment and set `DAILY_BACKUP_SERVER` to its IP address. Set `DAILY_BACKUP_PROTO` to one of `ftp`, `ftps` (for FTP+SSL), or `scp` for the upload method, and set `DAILY_BACKUP_USER` and `DAILY_BACKUP_PASS` as needed.

> If you are using `scp` and would like to use public key authentication rather than hard-coding a password here, set `DAILY_BACKUP_PASS` to `@`. Then retrieve your Vera's public key by running `dropbearkey -y -f /etc/dropbear/dropbear_rsa_host_key` on the Vera command line; copy/append that text *except the header and `Fingerprint` line* into the `authorized_keys` file or equivalent for the target system's user account (e.g. on Linux, this would be `~user/.ssh/authorized_keys` on the target server).

### Not Quite Everything

Hardcoded within the UI is the access to Vera/MiOS's weather API. Since failing these requests is completely benign to system stability, I haven't spent any time worrying about decoupling them. Your Vera will continue to hit those cloud servers occasionally when Internet is available, and will quietly do nothing when Internet is not.

If you discover any other cloud accesses after decoupling, please let me know.

## Running `decouple.sh`

**ALWAYS BACK UP BEFORE RUNNING THE SCRIPT. BACK UP YOUR ZWAVE NETWORK AS WELL.**

After making the necessary changes to the `decouple-config.sh` file, you can run the script: `sh decouple.sh`. The script will perform the necessary steps, and save original copies of modified configuration files in a (hidden) save directory, in case you want to recouple later. Follow any instructions the script gives you. Normally, the only instruction you will get is to reboot at the end. Once you've rebooted, decoupling is in full effect.

> It's normal and expected that a decoupled Vera will have its "Service" LED extinguished. This indicates that the system is not connected to the Vera/MiOS/eZLO cloud services.

The default location for the decoupler's saved configuration `/root/.decouple-saved` (you may need to do `ls -a` to see it), and I don't recommend that you change it, and don't delete it. It's not a bad idea to tar it along with the decouple and recouple scripts, and save the archive off-system.

If something goes wrong, you can usually fix the problem (following message instructions or enlisting my help), and then safely re-run the script. The script has considerable safeguards to ensure that original configurations are captured and preserved, and modifications are done properly if they haven't already been done.

If you decide you want to change your decoupling configuration, it is usually only necessary to modify the `decouple-config.sh` file with your changes and re-run `decouple.sh`. It is *not* necessary to recouple first.

## Recoupling to the Mother Ship

The `recouple.sh` script is provided to allow you to recouple your Vera to the company cloud services.

> Updating firmware, doing a factory reset, or restoring a backup made before decoupling will also recouple your Vera.

Once you've recoupled, the decouple save directory (default `/root/.decouple-saved`) should be regarded as invalid and discarded.

If you lose the decouple save directory or it becomes corrupt, the script will warn you and stop. You can override the stop by supplying the "-f" option on the command line. Any missing configuration will simply be restored to factory default, and the Vera should eventually update it to whatever settings the cloud services determine are correct for your unit. This is a fail-safe to ensure that you can always get back to cloud-connected service.

## Considerations for Your Own NTP Time Server

In the Vera world, the quality of a time source is based on availability more than accuracy. If the time server is unavailable when Vera boots, Vera will boot up with a default time that is inaccurate, perhaps unacceptably so, and this will persist until the time server can be reached. During this period, date and time-based automations will run errantly because the system time is just wrong. When Vera finally can reach a time server, it often reboots, since large adjustments of time cause bigger problems than just rebooting.

> Decoupled Vera systems do not go through a bunch of usually-useless gyrations and attempts to set the world right that coupled systems do when time or Internet access isn't available. This adds considerable stability to the system, and reduces the problem to just a boot-time issue.

The time problem is solved by building a highly-available, sufficiently-accurate time source on your LAN. This sounds a bit daunting, but it can actually be done for very little money and achieve excellent results. And there's a spectrum of solutions, so what you do, how difficult it is to implement and maintain, and how much it costs really depends on how far you want to go minimizing the problem.

A few options look like this:

* Best: time server has a hardware real time clock synced to external sources and both the clock and the entire system are battery-backed. Battery-backup of the RTC itself usually takes the form of a coin-cell battery. System backup is usually a traditional UPS or similar, larger battery system. The advantages here compound: the system is immune to brief power failures and will thus provide time service immediately when power is restored and other network devices/systems restart; if the power outage exceeds the UPS capacity, the hardware real time clock is still able to keep time, and when the time server reboots, it will begin with a query to the RTC to get a time very close to actual right from the start; synchronization with external sources discliplines the clock for best accuracy/consistency, and when synchronization isn't possible (e.g. Internet outage), the software and hardware-backed system clock continues to run. Most desktop PCs and full-size server PCs have RTCs, but be wary &mdash; this is one of the areas where manufacturers engineer cost out of the system quite often.
* Good: time server without a hardware RTC, but running an NTP service and externally synced, and battery-backed (UPS or similar). The expectation here is that the system stays running in all but the worst of cases (prolonged power outage). Because the system stays running, it is usually immediately available to answer time queries when other devices have power restored, increasing the likelihood that Vera, in particular, will not have to start with a bogus default time and resync later (it can resync immediately). During an Internet outage, the system can't sync, but the software clock is free-running and should be sufficiently accurate, as long as the time server itself doesn't reboot. If that happens, all bets are off.
* Acceptable: time server with a hardware RTC and no external synchronization, UPS-backed. A network with no Internet access would use this approach, for example. The network time will at least be consistent across all devices, but the time will only be as accurate as the hardware clock can achieve, and you'll probably need to adjust it manually from time to time.
* Unacceptable -- Time server with no hardware real time clock and no UPS/battery backup. This is unacceptable because there is no way for the time server to accurate time when it starts up (particularly if there is no Internet access), and the time server itself may not boot up sufficiently quickly to respond to the Vera's queries during its boot-up, resulting in the Vera also having bogus default time at startup.

If you use your router for NTP service on your network, and your router is not plugged into a UPS, you are in the *unacceptable* category unless you can confirm that your router has a hardware RTC (if it does, you're *good* or *acceptable* depending on system configuration).

If you use your NAS connected to a UPS for NTP service, you are in the *good* category if it has no real time clock, or *best* if it does.

If you use an RPi/ESP8266/ESP32 with an RTC hat/shield/board, the RTC is battery-backed, and the RPi itself is UPS-powered, you are in the *best* category. This can usually be achieved very cheaply and is highly recommended. If you can't do this right from the start, make it a plan to get there. It'll be fun and educational. For myself, I've chosen an Adafruit Ethernet Featherwing ($19.95) and a Feather RTC ($8.95); I'll publish the code for my solution in future, and I may also do a GPS version (which gives stratum 1 time service).

> While you're at it, consider the timing issues around power restoration throughout your network. If your time server comes up quickly or never loses power, but there's an Ethernet switch that does between it and the Vera, the boot time of the Ethernet switch also becomes a factor in whether or not the Vera can get time when it wants it. It's worth your effort to think these things through and relocate network devices or even change equipment if necessary. Likewise, consider that if all the equipment comes up quickly enough, but it takes your Internet provider and router longer to negotiate the connection and begin passing traffic, you may have a problem that only a hardware real time clock can fully mitigate.

Also, in order to reduce the number of points of failure, it is highly recommended that your NTP and DNS servers use static IP addressing (DHCP reservations are not adequate), and your Vera as well.
