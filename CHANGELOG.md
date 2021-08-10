# Vera-Decouple ChangeLog

https://github.com/toggledbits/Vera-Decouple

## 21222

* Support for 7.32 beta 4 (5385/6/7)
* Fix error in command line argument handling in recoupler.

## 20347

* New KEEP_MIOS_WEATHER flag to prevent decouple/disable of weather cloud service. This is for users of the VOTS plugin and was suggested by JW (issue #3).

## 20301

* Disable apps.mios.com

## 20294

* Make sure the alerts stay clear and system doesn't get bogged down trying to send alerts that cannot be delivered.

## 20290

* Fixed an issue where 20289 inserted an additiona  line feed in a cron job. To repair, you can either hand-edit the cron script (`crontab -u root -e`, join the "23 0" job and the line after), or just (re)run `decouple.sh` after updating to this version.

## 20289

* Initial release for Plus and Edge. Secure should be the same as Plus, but it needs to be tested.