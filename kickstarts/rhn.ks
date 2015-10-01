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

%post
$SNIPPET('log_ks_post')

$yum_config_stanza

$SNIPPET('cobbler_register')

chvt 3
(  # log custom post output
$SNIPPET('cc_post')
)  2>&1 | tee /root/ks-cc-post.log > /dev/console
chvt 1

$kickstart_done
