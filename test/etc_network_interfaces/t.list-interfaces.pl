# Assuming eth0..3 and eth100
# eth0 is part of vmbr0, eth100 is part of the OVS bridge vmbr1
# vmbr0 has ipv4 and ipv6, OVS only ipv4
#
# eth1..3 are completely un-configured as if the cards had just been physically
# plugged in.
# The expected behavior is to notice their existance and treat them as manually
# configured interfaces.
# Saving the file after reading would add the corresponding 'manual' lines.
save('proc_net_dev', <<'/proc/net/dev');
eth0:
eth1:
eth2:
eth3:
eth100:
/proc/net/dev

my %wanted = (
    vmbr0 => { address => '192.168.1.2',
	       netmask => '255.255.255.0',
	       gateway => '192.168.1.1',
	       address6 => 'fc05::1:1',
	       netmask6 => '112' },
    vmbr1 => { address => '10.0.0.5',
	       netmask => '255.255.255.0' }
);

save('interfaces', <<"/etc/network/interfaces");
auto lo
iface lo inet loopback

source-directory interfaces.d

iface eth0 inet manual

allow-vmbr1 eth100
iface eth100 inet manual
	ovs_type OVSPort
	ovs_bridge vmbr1

auto vmbr0
iface vmbr0 inet static
	address  $wanted{vmbr0}->{address}
	netmask  $wanted{vmbr0}->{netmask}
	gateway  $wanted{vmbr0}->{gateway}
	bridge_ports eth0
	bridge_stp off
	bridge_fd 0

iface vmbr0 inet6 static
	address  $wanted{vmbr0}->{address6}
	netmask  $wanted{vmbr0}->{netmask6}

source-directory before-ovs.d

auto vmbr1
iface vmbr1 inet static
	address  $wanted{vmbr1}->{address}
	netmask  $wanted{vmbr1}->{netmask}
	ovs_type OVSBridge
	ovs_ports eth100

source after-ovs

/etc/network/interfaces

r(load('interfaces'));
save('2', w());

my $ifaces = $config->{ifaces};

# check defined interfaces
defined($ifaces->{"eth$_"})
    or die "missing interface: eth$_\n" foreach (0, 1, 2, 3, 100);

# check configuration
foreach my $ifname (keys %wanted) {
    my $if = $wanted{$ifname};
    $ifaces->{$ifname}->{$_} eq $if->{$_}
	or die "unexpected $_ for interface $ifname: \""
	     . $ifaces->{$ifname}->{$_}
	     . "\", expected: \"$if->{$_}\"\n"
	foreach (keys %$if);
}

my $ck = sub {
    my ($i, $v, $e) = @_;
    $ifaces->{$i}->{$v} eq $e
	or die "$i variable $v: got \"$ifaces->{$i}->{$v}\", expected: $e\n";
};
$ck->('vmbr0', type => 'bridge');
$ck->('vmbr1', type => 'OVSBridge');
$ck->('vmbr1', ovs_type => 'OVSBridge');
$ck->('vmbr1', ovs_ports => 'eth100');
$ck->("eth$_", type => 'eth') foreach (0, 1, 2, 3);
$ck->('eth100', type => 'OVSPort');
$ck->('eth100', ovs_type => 'OVSPort');
$ck->('eth100', ovs_bridge => 'vmbr1');

my @f100 = sort @{$ifaces->{vmbr0}->{families}};

die "invalid families defined for vmbr0"
    if (scalar(@f100) != 2) || ($f100[0] ne 'inet') || ($f100[1] ne 'inet6');
 
# idempotency
r(w());
expect load('2');

1;
