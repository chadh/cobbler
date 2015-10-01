install
key --skip
text
auth  --useshadow  --enablemd5
rootpw --iscrypted $default_password_crypted
zerombr
bootloader --location=mbr
clearpart --all --initlabel
firewall --disabled
firstboot --disable
selinux --disabled
keyboard us
lang en_US
timezone --utc America/New_York
url --url=$tree
skipx
reboot

# cobbler repos added to profile
$yum_repo_stanza
$SNIPPET('rhnchannels')

$SNIPPET('network_config')
$SNIPPET('main_partition_select')

%pre
$SNIPPET('log_ks_pre')
$kickstart_start
$SNIPPET('pre_install_network_config')
$SNIPPET('cc_pre_partition')

%packages
$SNIPPET('base_packages')
$SNIPPET('virt_packages')

%post
$SNIPPET('log_ks_post')

$yum_config_stanza

$SNIPPET('cobbler_register')

chvt 3
(  # log custom post output
#raw
# get the end of the last partition
partedline=`/sbin/parted -s /dev/sda print | /bin/grep -v '^$' | /usr/bin/tail -n 1`
lastpart=`echo "$partedline" | /usr/bin/awk '{ print $1; }'`
end=`echo "$partedline" | /usr/bin/awk '{ print $3; }'`
next=`expr $lastpart + 1`
/sbin/parted -s /dev/sda mkpart primary ext2 $end 100%
/sbin/parted -s /dev/sda set $next lvm on
/sbin/lvm pvcreate -v -y /dev/sda$next
/sbin/lvm vgcreate -v vmvg /dev/sda$next
#end raw

$SNIPPET('cc_post')
$SNIPPET('localfirstboot')
)  2>&1 | tee /root/ks-cc-post.log > /dev/console
chvt 1


$kickstart_done
