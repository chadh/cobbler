#set $usegpt = $getVar('$usegpt', 'no')
install
text
auth  --useshadow  --enablemd5
rootpw --iscrypted $default_password_crypted
bootloader --location=mbr
#if $usegpt == 'no'
zerombr
clearpart --all --initlabel
#end if
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
$SNIPPET('kickstart_start')
$SNIPPET('pre_install_network_config')
$SNIPPET('cc_pre_partition')

%end

%packages --excludedocs --nobase
$SNIPPET('base_packages')

%end

%post
$SNIPPET('log_ks_post')

$yum_config_stanza

$SNIPPET('cobbler_register')

chvt 3
(  # log custom post output
$SNIPPET('cc_post')
# some nics take a little while to get a link
$SNIPPET('linkdelay')
$SNIPPET('localfirstboot')
)  2>&1 | tee /root/ks-cc-post.log > /dev/console
chvt 1

$SNIPPET('kickstart_done')

%end
