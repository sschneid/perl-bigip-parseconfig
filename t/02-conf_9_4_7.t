#/usr/bin/env perl
use Test::More 0.96;
use Test::Deep;

BEGIN {
    use_ok('BigIP::ParseConfig');
}

my $config_file = "./t/data/9.4.7.conf";
my $bip         = BigIP::ParseConfig->new($config_file);

sub test_object {
    my ( $m, $n, $h ) = @_;
    $obj = $bip->$m($n);
    cmp_deeply( $obj, $h, "$m : $n" ) or diag explain $obj;
}

sub test_object_raw {
    my ( $m, $n, $raw ) = @_;
    $obj = $bip->{Raw}->{$m}->{$n};
    is( $obj, $raw, "$m : $n" ) or diag explain $obj;
}


my $obj = $bip->partition('Common');

test_object( 'partition', 'Common',         { description => '"test test"' } );
test_object( 'route',     '192.168.2.0/24', { gateway     => '192.168.1.2' } );
test_object( 'route',     'default inet',   { gateway     => '10.0.0.2' } );
test_object(
    'user', 'admin',
    {   password    => 'crypt "crypted_password"',
        description => '"Admin User"',
        id          => 0,
        group       => 500,
        home        => '"/home/admin"',
        shell       => '"/bin/false"',
        role        => 'administrator in all',
    }
);


test_object(
    'monitor',
    'DNS',
    {   defaults => 'from udp',
        dest     => '*:domain',
        debug    => '"no"',
    }
);

test_object(
    'profile',
    'clientssl ssl_a',
    {   defaults => 'from clientssl',
        key      => '"ssl_a.key"',
        cert     => '"ssl_a.crt"',
        chain    => '"ssl_a_chain.crt"',
    }
);

test_object(
    'node',
    '172.16.1.11',
    'node 172.16.1.11 {
}
',
);

test_object(
    'pool',
    'dns.pool',
    {
        lb => 'method member observed',
        min => 'active members 1',
        members => '172.16.1.13:dns',
        _xtra => {'dont insert empty fragments' => 'priority 10'},
    }
);

test_object(
    'pool',
    'http.pool',
    {
   '_xtra' => {
     '172.16.1.11:http' => 'priority 10',
     '172.16.1.12:http' => 'priority 5'
   },
   'ip' => 'tos to server 0',
   'lb' => 'method member observed',
   'link' => 'qos to server 0',
   'members' => [
     '172.16.1.11:http',
     '172.16.1.12:http'
   ],
   'min' => 'active members 1',
   'monitor' => 'all http'
    }
);

test_object (
   'rule',
   'rule_a',
   {
       when => 'HTTP_REQUEST {',
       log =>'local0. "rule_a"',
   }
);


test_object (
   'virtual', 'http_a',
   {
       pool => 'http.pool',
       destination => '10.0.0.12:https',
       ip => 'protocol tcp',
       vlans => 'vlan-10 enable',
       rules => [qw(rule_a rule_b)],
       'profiles' => [qw(http tcp ssl_a)],
       persist => 'cookie',
   }
);

test_object (
   'virtual', 'single',
   {
   pool => 'dns.pool',
   destination => '10.0.0.11:dns',
   ip => 'protocol udp',
},
);

SKIP: {
    skip 'not implemented yet', 4;
TODO: {
    local $TODO = "Support objects: nat, snat, shell";
    test_object( 'user', 'root', { password => 'crypt "crypted_password"' } );
}

TODO: {
    local $TODO = "Support option name with space";
    test_object(
        'profile',
        'clientssl ssl_b',
        {   'defaults from'                => 'clientssl',
            key                            => '"ssl_b.key"',
            cert                           => '"ssl_b.crt"',
            chain                          => '"ssl_b_chain.crt"',
            'ca file'                      => 'none',
            ciphers                        => '"DEFAULT"',
            options                        => [qw(dont insert empty fragments)],
            'modssl methods'               => 'disable',
            'cache size'                   => '20K',
            'cache timeout'                => 3600,
            'renegotiate period'           => 'indefinite',
            'renegotiate size'             => 'indefinite',
            'renegotiate max record delay' => 10,
            'handshake timeout'            => 60,
            'alert timeout'                => 60,
            'unclean shutdown'             => 'enable',
   'strict resume' => 'disable',
   'nonssl' => 'disable',
        }
    );
}
TODO:{
    local $TODO = 'Suuport no option object.';
test_object(
    'node',
    '172.16.1.12',
    {},
);
};
TODO: {
    local $TODO = 'Support rule object has always raw data.';
    test_object(
'rule','rule_a',
'rule rule_a {
   when HTTP_REQUEST {
   log local0. "rule_a"
}
}
');
};
};


test_object_raw ('profile', 'clientssl ssl_b',
'profile clientssl ssl_b {
   defaults from clientssl
   key "ssl_b.key"
   cert "ssl_b.crt"
   chain "ssl_b_chain.crt"
   ca file none
   ciphers "DEFAULT"
   options 
      dont insert empty fragments
   modssl methods disable
   cache size 20K
   cache timeout 3600
   renegotiate period indefinite
   renegotiate size indefinite
   renegotiate max record delay 10
   handshake timeout 60
   alert timeout 60
   unclean shutdown enable
   strict resume disable
   nonssl disable
}
configsync {
   password crypt "crypted_password"
}
');

cmp_deeply([$bip->members('http.pool')], [qw(172.16.1.11:http 172.16.1.12:http)], 'members : http.pool');


done_testing;
