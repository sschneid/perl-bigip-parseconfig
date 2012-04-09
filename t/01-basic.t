#/usr/bin/env perl
use Test::More 0.96;
use Test::Exception;
use File::Temp;
use File::Compare;
use Text::Diff ();
BEGIN{
    use_ok('BigIP::ParseConfig');
}

my $config_file = "./t/data/9.4.7.conf";

test_object_count($config_file);
test_dump_restore($config_file);
test_modify($config_file);


sub test_object_count {
    my ($file) = @_;
    my $bip = BigIP::ParseConfig->new($file);
    my $config_text;
    { local $/ = undef; local *FILE; open FILE, '<', $file or die "$! : $file"; $config_text = <FILE>; close FILE }
    foreach my $type (qw(monitor node partition pool profile route rule user virtual snat)) {
        my @cnt = ($config_text =~ /^$type\s/gmsx);
        my $method = $type . 's';
        is($bip->$method, scalar @cnt, "test: $method");
    }
}

sub test_dump_restore {
    my ($file) = @_;
    my $bip = BigIP::ParseConfig->new($file);
    $bip->virtuals;
    $bip->modify(
        type => 'partition',
        key  => 'Common',
        description => '"test test"',
    );
    my ($fh, $fname) = File::Temp::tempfile(UNLINK => 1);
    $bip->write($fname);
    ok(compare($file, $fname) == 0, 'compare written file')
        or diag Text::Diff::diff($file, $fname, {STYLE => 'Unified'});
}

sub test_modify {
    my ($file) = @_;
    my $bip = BigIP::ParseConfig->new($file);
    $bip->virtuals;
    my ($fh, $fname) = File::Temp::tempfile(UNLINK => 1);
    $bip->modify(
        type => 'partition',
        key  => 'Modify Test ',
        description => '"test test"',
    );
    dies_ok{$bip->write($fname)} 'if no modification, die';
    ok(-z $fname, "Don't modify unless key exists");

}

done_testing;
