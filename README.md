### about
this script configures the system to support hibernate

#### license  
[![license](https://img.shields.io/github/license/almaceleste/configure-hibernate.svg?longCache=true)](https://github.com/almaceleste/configure-hibernate/blob/master/LICENSE)

<!-- #### wiki -->

#### usage:
```
configure-hibernate.sh [options]
```
#### options:  
```
    --help              show this help and exit
    --unset-recordfail  (single option) create a service to unset grub recordfail and get the 
                        grub boot menu will not appear on boot after hibernation. this option 
                        is necessary only if your system is already configured for hibernation, 
                        but you found out that the grub boot menu appear at boot time after 
                        hibernation, and you want to disable it
    --polkit=path.pkla  path to the polkit .pkla file for configuration, e.g. 
                        /etc/polkit-1/localauthority/50-local.d/org.freedesktop.hibernate.pkla
    --suffix=something  suffix for backup files. if absent, the datetime stamp will be used
    --swap=identifier   identifier of the swap partition, something like UUID=84a9...b17 or 
                        /dev/nvme0n1p2
    --test              test your system for hibernation compatibility
    --version           show version info and exit
```

configures the system to support hibernate. asks sudo privileges to change system files.

all options may be absent. use it only if you know what you do and want to get some specific 
result. if the option is absent, it will be calculated automatically.  

### support me
[![Beerpay](https://beerpay.io/almaceleste/configure-hibernate/badge.svg?style=beer-square)](https://beerpay.io/almaceleste/configure-hibernate) [![Beerpay](https://beerpay.io/almaceleste/configure-hibernate/make-wish.svg?style=flat-square)](https://beerpay.io/almaceleste/configure-hibernate?focus=wish)
[![](https://img.shields.io/badge/Paypal-donate_me-blue.svg?longCache=true&logo=paypal)](https://www.paypal.me/almaceleste "paypal | donate me") 
