Cobbler (http://cobbler.github.io/) is an installation server that ties
together several of the services used in unattended network installation of
hosts.  The files in this repo make up the source for generating kickstart and
preseed files.  I have heavily modified some of the files distributed with the
source as indicated below.

## kickstarts/

This directory contains kickstart (and preseed) files for unattended
installation of Red Hat (and Debian/Ubuntu).  They make use of the Python
templating language Cheetah (http://www.cheetahtemplate.org/) to include
additional directives defined by the snippets.

## snippets/

This directory contains templates for filling in the kickstart and preseed
files.  Everything is relatively straight-forward except for `cc_prepartition`
and `cc_prepartition_debian` (and `per_profile/cc_prepartition_debian/*`).
These snippets construct the directives to setup partitions, software raid
volumes, LVM, and filesystems prior to the installation.  The work is driven by
metadata associated with a host (or the profile assigned to the host).  I'm
pretty proud of that.

## Sample Kickstart

Here is an example of what cobbler will generate given the templates:

```
install
key --skip
text
auth  --useshadow  --enablemd5
bootloader --location=mbr
zerombr
clearpart --all --initlabel
firewall --disabled
firstboot --disable
selinux --disabled
keyboard us
lang en_US
timezone --utc America/New_York
url --url=http://rhnmirror.foo.bar/rhel6.6-x86_64-server
skipx
reboot

# cobbler repos added to profile
#repo --name=rhel6-x86_64-server --baseurl=http://rhnmirror.foo.bar/rhel6-x86_64-server
repo --name=rhel6-x86_64-puppetlabs-products --baseurl=http://cobbler.foo.bar/cobbler/repo_mirror/rhel6-x86_64-puppetlabs-products
repo --name=rhel6-x86_64-puppetlabs-dependencies --baseurl=http://cobbler.foo.bar/cobbler/repo_mirror/rhel6-x86_64-puppetlabs-dependencies
repo --name=epel-6-x86_64 --baseurl=http://cobbler.foo.bar/cobbler/repo_mirror/epel-6-x86_64
repo --name=rhel6-x86_64-server-optional --baseurl=http://rhnmirror.foo.bar/rhel6-x86_64-server/Optional

#repo --name=rhel6-server --baseurl=http://rhnmirror.foo.bar/rhel6.5-x86_64-server/Server
#repo --name=rhel6-server-optional --baseurl=http://rhnmirror.foo.bar/rhel6.5-x86_64-server/Optional
#repo --name=epel-6 --baseurl=http://cobbler.foo.bar/cobbler/repo_mirror/epel-6-x86_64
#repo --name=puppetlabs-products --baseurl=http://cobbler.foo.bar/cobbler/repo_mirror/rhel6-x86_64-puppetlabs-products
#repo --name=puppetlabs-dependencies --baseurl=http://cobbler.foo.bar/cobbler/repo_mirror/rhel6-x86_64-puppetlabs-dependencies



# Using "new" style networking config, by matching networking information to the physical interface's
# MAC-address
%include /tmp/pre_install_network_config

# partition selection
%include /tmp/partinfo



%pre
set -x -v
exec 1>/tmp/ks-pre.log 2>&1

# Once root's homedir is there, copy over the log.
while : ; do
    sleep 10
    if [ -d /mnt/sysimage/root ]; then
        cp /tmp/ks-pre.log /mnt/sysimage/root/
        logger "Copied %pre section log to system"
        break
    fi
done &


curl "http://cobbler.foo.bar/cblr/svc/op/trig/mode/pre/system/killerbee1" -o /dev/null
# Start pre_install_network_config generated code
# generic functions to be used later for discovering NICs
mac_exists() {
  [ -z "$1" ] && return 1

  if which ip 2>/dev/null >/dev/null; then
    ip -o link | grep -i "$1" 2>/dev/null >/dev/null
    return $?
  elif which esxcfg-nics 2>/dev/null >/dev/null; then
    esxcfg-nics -l | grep -i "$1" 2>/dev/null >/dev/null
    return $?
  else
    ifconfig -a | grep -i "$1" 2>/dev/null >/dev/null
    return $?
  fi
}
get_ifname() {
  if which ip 2>/dev/null >/dev/null; then
    IFNAME=$(ip -o link | grep -i "$1" | sed -e 's/^[0-9]*: //' -e 's/:.*//')
  elif which esxcfg-nics 2>/dev/null >/dev/null; then
    IFNAME=$(esxcfg-nics -l | grep -i "$1" | cut -d " " -f 1)
  else
    IFNAME=$(ifconfig -a | grep -i "$1" | cut -d " " -f 1)
    if [ -z $IFNAME ]; then
      IFNAME=$(ifconfig -a | grep -i -B 2 "$1" | sed -n '/flags/s/:.*$//p')
    fi
  fi
}

# Start of code to match cobbler system interfaces to physical interfaces by their mac addresses
#  Start eth0
# Configuring eth0 (00:1d:09:70:3f:8d)
if mac_exists 00:1d:09:70:3f:8d
then
  get_ifname 00:1d:09:70:3f:8d
  echo "network --device=$IFNAME --bootproto=dhcp" >> /tmp/pre_install_network_config
fi
# End pre_install_network_config generated code





FIRSTDISK="sda"
## get disk size in GB
DISKSIZE=$(parted -sm /dev/$FIRSTDISK unit GB print | grep -e "$FIRSTDISK" | cut -d: -f2 | sed -e 's/GB$//')
if [ $DISKSIZE -gt 2100 ]
then
  ## bios boot partition necessary
  BIOSBOOT="part biosboot --fstype=biosboot --size=1 --ondisk="
else
  BIOSBOOT="# ignore this - "
fi

cat <<EOF > /tmp/partinfo
${BIOSBOOT}sda
part raid.01 --size=1000 --asprimary --ondisk=sda
part raid.02 --size=50000 --grow --ondisk=sda
${BIOSBOOT}sdb
part raid.11 --size=1000 --asprimary --ondisk=sdb
part raid.12 --size=50000 --grow --ondisk=sdb
raid /boot --fstype=ext3 --level=1 --device=md0 raid.01 raid.11
raid pv.01 --level=1 --device=md1 raid.02 raid.12
volgroup vg1 pv.01
logvol / --vgname=vg1 --size=15000 --name=root --fstype=ext4
logvol /var --vgname=vg1 --size=5000 --name=var --fstype=ext4
logvol /tmp --vgname=vg1 --size=2000 --name=tmp --fstype=ext4
logvol swap --vgname=vg1 --size=2000 --name=swap
EOF
cat /tmp/partinfo



%packages
@base
@core
@development
ntp
vim-enhanced
redhat-lsb
rpcbind
nfs-utils
-subscription-manager


%post
set -x -v
exec 1>/root/ks-post.log 2>&1


curl "http://cobbler.foo.bar/cblr/svc/op/yum/system/superhost" --output /etc/yum.repos.d/cobbler-config.repo


# Begin cobbler registration
# skipping for system-based installation
# End cobbler registration


chvt 3
(  # log custom post output
# CoC post-install
PUPPETENV=production
PUPPETSERVER=puppet
install -o root -g root -m 0755 -d /usr/local/bin/
wget -O /usr/local/bin/ccbp_sysinfo http://linux-install.foo.bar/scripts/ccbp_sysinfo
chown root:root /usr/local/bin/ccbp_sysinfo
chmod 755 /usr/local/bin/ccbp_sysinfo

PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin; export PATH
umask 022

cat<<EOF > /etc/ntp.conf
# skeleton conf until we get the real one
server ntp1.gatech.edu burst iburst
server ntp2.gatech.edu burst iburst
server ntp3.gatech.edu burst iburst
driftfile /var/lib/ntp/drift
restrict  default notrust nomodify
restrict 127.0.0.1
EOF

[ -x /sbin/pidof ] && if /sbin/pidof ntpd > /dev/null 2>&1; then
    [ -x /usr/bin/pkill ] && /usr/bin/pkill ntpd
fi
#/usr/sbin/ntpd -gqxd
/usr/sbin/ntpdate ntp1.gatech.edu ntp2.gatech.edu ntp3.gatech.edu
date

chkconfig ntpd on

# I think this is commented out because VMs really don't these commands
#/sbin/hwclock --show
if ! `/sbin/hwclock --systohc --utc`; then echo "hwclock failed with exit code $?"; fi

#
# fix up hostname
#
echo "fixing hostname in /etc/sysconfig/network, if necessary"
sed -i -e 's/^HOSTNAME=\([^.]*\).*/HOSTNAME=\1/' /etc/sysconfig/network
source /etc/sysconfig/network
hostname $HOSTNAME
IPADDR=`hostname --ip-address`
HOSTLONG=`host $HOSTNAME | tail -n 1 | awk '{ print $1; }'`

#
# fixup /etc/hosts
#
echo "building /etc/hosts"
echo "127.0.0.1        localhost  localhost.localdomain" > /etc/hosts
echo "$IPADDR        $HOSTLONG $HOSTNAME" >> /etc/hosts

yum -y install puppet-2.7.19 facter-1.6.12 mcollective

PM=`host $PUPPETSERVER | tail -n 1 | awk '{ print $1; }'`
echo "PUPPET_SERVER=$PM" > /etc/sysconfig/puppet
cat<<EOF > /etc/puppet/puppet.conf
    [main]
    vardir=/var/lib/puppet
    ssldir=\$vardir/ssl
    pluginsync = true
    environment = $PUPPETENV
EOF
chkconfig puppet on

#
# bootstrap puppet
#

# clean up any old certs locally or on the master
#wget -O /dev/null http://cobbler.foo.bar/cgi-bin/cleanmycert.sh

# this loops until the puppet cert is signed (or a bug is fixed :))
while ! puppet agent --onetime --verbose --no-daemonize --debug --trace --server $PM # --tags bootstrap
do
  date
  sleep 300
done


# some nics take a little while to get a link



)  2>&1 | tee /root/ks-cc-post.log > /dev/console
chvt 1


curl "http://cobbler.foo.bar/cblr/svc/op/ks/system/killerbee1" -o /root/cobbler.ks
curl "http://cobbler.foo.bar/cblr/svc/op/trig/mode/post/system/killerbee1" -o /dev/null
```


## Sample preseed

And here is a sample preseed file:

```
#### Contents of the preconfiguration file (for wheezy)
### Localization - these are specified on kernel command line
#d-i debian-installer/locale string en_US.UTF-8
#d-i console-keymaps-at/keymap select American English
#d-i debian-installer/keymap string us
#d-i keymap select us

### Network configuration
d-i netcfg/choose_interface select auto
# Any hostname and domain names assigned from dhcp take precedence over
# values set here. However, setting the values still prevents the questions
# from being shown, even if values come from dhcp.
d-i netcfg/get_hostname string unassigned-hostname
d-i netcfg/get_domain string unassigned-domain


### Mirror settings
d-i mirror/protocol string http
d-i mirror/country string US
d-i mirror/http/hostname string debian.gtisc.gatech.edu
d-i mirror/http/directory string /debian
d-i mirror/suite string wheezy
d-i mirror/http/proxy string

### Account setup
d-i passwd/make-user boolean false

### Clock and time zone setup
d-i clock-setup/utc boolean true
d-i time/zone string GMT
d-i clock-setup/ntp boolean true

d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-pc/install_devices multiselect /dev/sda

### Package selection
tasksel tasksel/first multiselect minimal
d-i pkgsel/include string openssh-server \
                puppet \
                build-essential \
                vim \
                less \
                firmware-linux-free \
                ntp
d-i pkgsel/upgrade select none
popularity-contest popularity-contest/participate boolean false

### Misc options
# Disable that annoying WEP key dialog.
d-i netcfg/wireless_wep string
# Allow non-free firmware
d-i hw-detect/load_firmware boolean true
# Avoid that last message about the install being complete.
d-i finish-install/reboot_in_progress note





d-i partman-auto/method string lvm
d-i partman/confirm boolean true
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/confirm_write_new_label boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-md/confirm_nochanges boolean true
d-i partman-lvm/confirm boolean true
d-i partman/choose_partition select finish
d-i partman/confirm_nooverwrite boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-lvm/device_remove_lvm_span boolean true
d-i partman-auto-lvm/new_vg_name string vg0
d-i partman/alignment string cylinder
d-i partman-partitioning/choose_label select msdos
d-i partman-ext3/no_mount_point boolean false

d-i partman-auto/disk string /dev/sda



d-i partman-auto/expert_recipe string boot-root :: 200 200 200 ext3 $primary{ } $bootable{ } method{ format } format{ } use_filesystem{ } filesystem{ ext3 } mountpoint{ /boot } . 29000 29000 1000000000 ext3 $defaultignore{ } $primary{ } method{ lvm } vg_name{ vg0 } . 1000 4000 15000 ext4 method{ format } format{ } use_filesystem{ } filesystem{ ext4 } $lvmok{ } in_vg{ vg0 } mountpoint{ / } . 200 1000 2000 ext4 method{ format } format{ } use_filesystem{ } filesystem{ ext4 } $lvmok{ } in_vg{ vg0 } mountpoint{ /tmp } . 500 1000 5000 ext4 method{ format } format{ } use_filesystem{ } filesystem{ ext4 } $lvmok{ } in_vg{ vg0 } mountpoint{ /var } . 2048 4096 2000 linux-swap method{ swap } format{ } $lvmok{ } in_vg{ vg0 }  . 1 1 1000000000  ext4 method{ format } format{ } use_filesystem{ } filesystem{ ext4 } $lvmok{ } in_vg{ vg0 } mountpoint{ /scratch } .



d-i preseed/early_command string wget "http://cobbler.foo.bar/cblr/svc/op/trig/mode/pre/system/rhelvagrantbox" -O /dev/null
d-i preseed/late_command string wget -O /target/tmp/post.sh http://linux-install.foo.bar/bootstrap.sh && in-target /bin/bash -x /tmp/post.sh agent puppet.foo.bar research; wget "http://cobbler.foo.bar/cblr/svc/op/trig/mode/post/system/rhelvagrantbox" -O /dev/null
```
