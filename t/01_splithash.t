#!/usr/bin/perl -w

use strict;
use lib ('../blib','./blib','../lib','./lib');

use Tie::DB_File::SplitHash;
use File::Spec;

my @do_tests = (1);
my $filename = "test-hash.$$";

local $| = 1;

my $test_subs = { 1 => { -code => \&test1, -desc => 'open/write/close/open/read/close database.....' },
                 };

print $do_tests[0],'..',$do_tests[$#do_tests],"\n";
#print STDERR "\n";
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
        print STDERR "\n    $desc - $failure\n";
        $n_failures++;
    } else {
        print "ok $test\n";
#        print STDERR "    $desc - ok\n";

    }
}
print "END\n";
exit;

# Test Open database
sub test1 {
    my ($filename) = @_;
   
    my $multi_n = 4;
    my $flags   = &O_RDWR() | &O_CREAT();
    my $mode    = 0666;

    my %hash;

    my $result = eval {
        my $extra_dir = File::Spec->catdir($filename,'extra');
        my $db = tie %hash, 'Tie::DB_File::SplitHash', $extra_dir, $flags, $mode, $DB_HASH, $multi_n;
        if (defined $db) {
            return "did not detect failure to tie database";
        }
    };
    unless ($@) {
        return "Failed: $result";
    }

    $result = eval {
        my $extra_dir = File::Spec->catdir($filename,'extra');
        mkdir($filename, 0000) || return "could not create scratch directory $filename: $!";
        my $db = tie %hash, 'Tie::DB_File::SplitHash', $extra_dir, $flags, $mode, $DB_HASH, $multi_n;
        if (defined $db) {
            return "did not detect failure to tie database";
        }
    };
    unless ($@) {
        return "Failed: $result";
    }
    my $rm_failed = rm_db_dir ($filename, $multi_n);
    if ($rm_failed) { return $rm_failed; }

    $result = eval {
        mkdir($filename, 0000) || return "could not create scratch directory $filename: $!";
        my $db = tie %hash, 'Tie::DB_File::SplitHash', $filename, $flags, $mode, $DB_HASH, $multi_n;
        if (defined $db) {
            return "did not detect failure to tie database due to bad filesystem permissions";
        }
    };
    unless ($@) {
        return "Failed: $result";
    }
    $rm_failed = rm_db_dir ($filename, $multi_n);
    if ($rm_failed) { return $rm_failed; }

    $result = eval {
        my $db = tie %hash, 'Tie::DB_File::SplitHash', $filename, $flags, $mode, $DB_HASH, $multi_n,1;
        if (defined $db) {
            return "did not detect incorrect number of parameters to tie";
        }
    };
    unless ($@) {
        return "Failed: $result";
    }
    $rm_failed = rm_db_dir ($filename, $multi_n);
    if ($rm_failed) { return $rm_failed; }

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
   
    $rm_failed = rm_db_dir ($filename, $multi_n);
    if ($rm_failed) { return $rm_failed; }

	return '';
}

sub rm_db_dir {
    my ($dir, $multi_n) = @_;
    return '' unless (-e $dir);

    foreach my $count (0..$multi_n) {
        my $db_file = File::Spec->catfile($dir, "index_$count.db");
        if (-e $db_file) {
	        unlink $db_file;
        }    
    }    
	rmdir ($dir) or return ("Failed to unlink test dir: $!");
    return ''
}
