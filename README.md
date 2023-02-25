# Vera Cloud De-coupler/Re-coupler

**CURRENT VERSION: 23056**

**KNOW WHAT YOU'RE GETTING INTO: READ THIS ENTIRE DOCUMENT BEFORE DOING ANYTHING.**

These scripts decouple a Vera Home Automation Controller from the many cloud services to which it normally connects. It is generally accepted that Veras are more stable when not connected to the mother ship, as outages of these cloud services often causes spurious reloads of Luup or even reboots of the system. Decoupled systems use less RAM and CPU as well.
Decoupling also improves system reliability when Internet access is not available.

The only required services are DNS and NTP (time), and a lapse in the former does not affect system stability. If one provides a stable local NTP server (which can be as simple and inexpensive as a RPi/ESP8266/ESP32 with an add-on RTC), then it is possible to run a decoupled Vera entirely off-grid with no Internet access whatsoever and have a stable system.

The scripts also make facilities for local (LAN) storage of rotated log files and daily configuration backups.

What decoupling *does not do* is restrict the Vera from accessing cloud or other Internet-based services at all. While it principally removes Vera's cloud services, it does not prevent you from using other services if they are important to your automations/configuration. A decoupled Vera will therefore happily collect weather data from a third-party API, or operate your garden sprinklers, smart garage door openers or thermostats, through their respective cloud services. Eliminating these cloud connections, if that is your goal, is elective for you and simply a matter of not using those plugins.

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

## Preparation

First, make sure your Vera is fully configured:

* The unit is registered and listed in your Controllers list at https://home.getvera.com;
* The unit's location settings are properly set (*Settings > Location*);
* The unit is running the version of firmware that you want to run, and that version is supported by this tool;
* All of the other settings under *Users & Account Info* are properly configured;
* You have installed any plugins from the App Marketplace that can only be installed from there.

Second, you're going to need to decide if you want to continue to use external (cloud) time servers, or use a local (LAN) time server. It's not strictly necessary to use a local LAN server, and there are many ways to build such a server and end up no better than if you didn't have one and just stuck with the cloud. See my discussion toward the end of this document regarding the merits and problems of various options.

* If your Internet access is stable most of the time and you rarely have power failures, and when you do have power failures, it's OK with you if the Vera needs a few minutes and maybe an automatic reboot/reload or two before it stabilizes, then using the default cloud time servers (pool.ntp.org) is OK. Note that even brief periods of "bogus" time on your Vera can cause it to fire date/time-based automations errantly.
* If you regularly have no Internet access, frequent prolonged outages of Internet, frequent power failures, or use a lot of time-based automations, then setting up a local NTP server is likely the better choice. Again, see the discussion on choosing/building an NTP time server near the end of this document.

Finally, you'll need to make a similar decision for DNS. The default DNS servers are the Google DNS servers at 8.8.8.8 and 8.8.4.4. This is probably fine, but there are good arguments to be made that a local DNS service provided by your router or another device in your network is actually a better choice. Either way, the availability of DNS will not affect system stability, so do what makes the most sense to you (I use my router's DNS cache/forwarder).

> TIP: Your NTP and DNS servers, and your Vera, should all use static IP addresses, in case the network's DHCP server is down or fails.

## Installing the Scripts

To install the scripts, SSH into your Vera, and then:

1. In your SSH window, type `curl -L -o decouple.zip https://codeload.github.com/toggledbits/Vera-Decouple/zip/main`
2. Unzip the script package: `unzip decouple.zip`

Once you've unzipped the archive, you may delete the ZIP archive if you wish.

## Configuring for Decoupling

Configuration is done by modifying the `decouple-config.sh` file (only &mdash; do not modify the other files). That means you'll need to use an editor on your Vera, and by default, the standard editor is `vi`, Bill Joy's wonderful ubiquitous visual editor that's as easy to learn as a saxophone. If you are comfortable in `vi`, no problem; if you need a more basic editor, proceed immediately to "Running `decouple.sh`" below, and the script will offer to install the `nano` editor for you. You can then edit the configuration file and run the script again.

Everything in the configuration file has reasonable defaults. The default value will be used when the configuration variable is either commented out or set to blank. A variable is commented out when a '#' appears in the left margin before its name. To uncomment a variable, remove that '#', and then add any value to the right of the equal ('=') sign. Do not change the name of the variable, or add any spaces before or after the equal sign. Although it is usually not necessary, you can surround the value in double-quote marks (i.e. `DNSSERVER=192.168.0.1` and `DNSSERVER="192.168.0.1"` are equivalent).

OK. Ready? Let's see what we can configure. Remember, if any config variable is commented out or blank, the default shown will be used:

* `NTPSERVER`: [default: `"0.openwrt.pool.ntp.org 1.openwrt.pool.ntp.org"`] Set to the IP address(es) of the NTP servers you would like to use. To remove dependency on Internet access, this should be one or more servers on your local LAN.
* `DNSSERVER`: [default: `"8.8.8.8 8.8.4.4"` (Google DNS)] Set to the DNS servers you would like to use. The use of local or cloud DNS services makes little difference in stability to your Vera system. If your router provides DNS cache/forwarder service, that's a fine choice.
* `KEEP_MIOS_WEATHER`: [default: 0] If non-zero, the MiOS cloud weather service will not be decoupled/disabled. This is for users of the VOTS plugin.
* `LOG_SERVER`: [default: no log storage] Set to the (one) IP address of the server to receive logs. If blank/unset, logs are discarded. If set, you will also need to set `LOG_USER` and `LOG_PASS` to the username and password, respectively, of the FTP account on that server to receive the log files. You must also create a subdirectory of that account's home directory with the same name as the serial number of your Vera unit. The logs will be uploaded to this directory. FTP is the only protocol supported by this proces.
* `SYSLOG_SERVER`: [default: no syslog logging] Set to the IP address of a SysLog remote server to receive logging from the Vera. If blank/not set, no remote Syslog logging will occur. The default protocol for logging is UDP, on destination port 514. You may the protocol to TCP by setting `SYSLOG_PROTO=tcp`; the port can be changed by setting `SYSLOG_PORT`.
* `DAILY_BACKUP_SERVER`: [default: no automatic daily backups] Set to the IP address of a server to receive daily configuration backups from your Vera system. When you decouple from the cloud, the daily backups cannot be stored on Vera's servers. If blank/not set, no daily backups will be done and you must back up manually. You can set `DAILY_BACKUP_PROTO` to one of `ftp` (the default), `ftps` (for FTP+SSL), or `scp`. You should also set `DAILY_BACKUP_USER` and `DAILY_BACKUP_PASS` to the username and password of the account to receive the backup archives. A subdirectory in that account's home of the same name as the Vera serial number is required as well. Password-less backup using public key authentication is possible; see below.

> If you are using `scp` for daily local backups and would like to use public key authentication rather than hard-coding a password here, set `DAILY_BACKUP_PASS` to `@`. Then run `decouple.sh`. After it runs, you will find a file `vera_ssh_key.txt` in the `/root` folder. Append the contents of this file to the `authorized_keys` file or equivalent for the *target system's* user account (e.g. on Linux, this would be `~user/.ssh/authorized_keys` on the target server, where `user` is the username you assigned to `DAILY_BACKUP_USER`; check your Linux system's `ssh` documentation for permissions required on the `.ssh` subdirectory and `authorized_keys` files if they don't already exist and you need to create them).

## Running `decouple.sh`

**ALWAYS BACK UP BEFORE RUNNING THE SCRIPT. BACK UP YOUR ZWAVE NETWORK AS WELL.**

After making the necessary changes to the `decouple-config.sh` file, you can run the script: `sh decouple.sh`. The script will perform the necessary steps, and save original copies of modified configuration files in a (hidden) save directory, in case you want to recouple later. Follow any instructions the script gives you. Normally, the only instruction you will get is to reboot at the end. Once you've rebooted, decoupling is in full effect.

```
root@MiOS_500xxxxx:~# sh decouple.sh
Running decouple.sh version 20288
Preliminary checks OK. Decouple this Vera from cloud services [Y/N]? y
Setting NTP server(s) to 192.168.0.15 192.168.0.44...
Setting DNS server(s) to 192.168.0.15 192.168.0.44...
Enabling syslog remote logging to 192.168.0.15...
Setting up daily system backups to 192.168.0.164 via ftp...
Disabling remote access...
Disabling NetworkMonitor...
Updating root's crontab...
Decoupling Vera cloud servers...
Turning on log uploads to 192.168.0.15...
Connecting log server 192.168.0.15 for upload/rotation...

OK. We're done here. Your Vera has been decoupled from the cloud services.
When ready, please reboot by running /sbin/reboot
root@MiOS_500xxxxx:~# /sbin/reboot
    <remote server has disconnected>
```

> It's normal and expected that a decoupled Vera will have its "Service" LED extinguished. This indicates that the system is not connected to the Vera/MiOS/eZLO cloud services.

The default location for the decoupler's saved configuration `/root/.decouple-saved` (you may need to do `ls -a` to see it), and I don't recommend that you change it, and don't delete it. It's not a bad idea to `tar` it along with the decouple and recouple scripts (e.g. `tar czf decouple-saved.taz .decouple-saved decouple.sh recouple.sh`), and save the archive off-system.

If something goes wrong, you can usually fix the problem (following message instructions or enlisting my help &mdash; see *Questions and Support* below), and then safely re-run the script. The script has considerable safeguards to ensure that original configurations are captured and preserved, and modifications are done properly if they haven't already been done.

If you decide you want to change your decoupling configuration, it is usually only necessary to modify the `decouple-config.sh` file with your changes and re-run `decouple.sh`. It is *not* necessary to recouple first.

## Recoupling to the Mother Ship

The `recouple.sh` script is provided to allow you to recouple your Vera to the company cloud services.

> Updating firmware, doing a factory reset, or restoring a backup made before decoupling will also recouple your Vera.

Once you've recoupled, the decouple save directory (default `/root/.decouple-saved`) should be regarded as invalid and discarded.

If you lose the decouple save directory or it becomes corrupt, the script will warn you and stop. You can override the stop by supplying the `-f` option on the command line. Any missing configuration will simply be restored to factory default, and the Vera should eventually update it to whatever settings the cloud services determine are correct for your unit. This is a fail-safe to ensure that you can always get back to cloud-connected service.

## Questions and Support

**THIS IS VERY IMPORTANT! PLEASE PLAY BY THE RULES!**

Because discussion of decoupling has in the past drifted into territory that has gotten people banned from the Vera Community, please **do not** ask questions or report problems there. Use the [Issues](https://github.com/toggledbits/Vera-Decouple/issues) section of this repository for that purpose exclusively.

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
