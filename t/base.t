#!/usr/bin/perl -w

use strict;
use lib ('../blib','./blib','../lib','./lib');
use Tie::DB_File::SplitHash;

my @do_tests = (1);
my $filename = "test-hash.$$";

local $| = 1;

my $test_subs = { 1 => { -code => \&test1, -desc => 'open/write/close/open/read/close database.....' },
                 };

print $do_tests[0],'..',$do_tests[$#do_tests],"\n";
print STDERR "\n";
my $n_failures = 0;
foreach my $test (@do_tests) {
    my $sub  = $test_subs->{$test}->{-code};
    my $desc = $test_subs->{$test}->{-desc};
    my $failure = '';
    eval { $failure = &$sub($filename); };
    if ($@) {
        $failure = $@;
    }
    if ($failure ne '') {
        chomp $failure;
        print "not ok $test\n";
        print STDERR "    $desc - $failure\n";
        $n_failures++;
    } else {
        print "ok $test\n";
        print STDERR "    $desc - ok\n";

    }
}
print "END\n";
exit;

# Test Open database and Set locks.
sub test1 {
    my ($filename) = @_;
   
    my $multi_n = 4;
    my $flags   = &O_RDWR() | &O_CREAT();
    my $mode    = 0666;

    my %hash;
    my $database = tie %hash,  'Tie::DB_File::SplitHash', $filename, $flags, $mode, $DB_HASH, $multi_n;
    if (not defined $database) {
        return "Failed to tie database: $!";
    }    
    $hash{'test'} = 'yes';
    undef $database;
    untie %hash;
    
    $database = tie %hash,  'Tie::DB_File::SplitHash', $filename, $flags, $mode, $DB_HASH, $multi_n;
    if (not defined $database) {
        return "Failed to re-tie database: $!";
    }
    if ($hash{'test'} ne 'yes') {
        return "Failed to read written value. Wrote 'yes', read '$hash{test}'";
    }

    undef $database;
    untie %hash;
   
    foreach my $count (0..$multi_n) {
        if (-e "$filename/index_$count.db") {
	        unlink "$filename/index_$count.db";
        }    
    }    
	rmdir ($filename) or return ("Failed to unlink test dir: $!");

	'';
}
