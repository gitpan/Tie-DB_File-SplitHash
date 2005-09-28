use strict;

use lib ('./blib','../blib', './lib','../lib');

use Tie::DB_File::SplitHash;

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Text-FixEOL.t'

#########################
# change 'tests => 9' to 'tests => last_test_to_print';

eval {
    require File::Temp;
    File::Temp->import('tempdir');
};
if ($@) {
    $|++;
    print "1..0 # Skipped: File::Temp required for testing\n";
    exit;
}
eval {
    require Test::More;
    Test::More->import(tests => 3);
};
if ($@) {
    $|++;
    print "1..0 # Skipped: Test::More required for testing\n";
    exit;
}

my $TIE_CLASS = 'Tie::DB_File::SplitHash';

#########################
# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $TESTDIR = tempdir(CLEANUP => 1);

#########
# Test 1
ok (test_tie());

#########
# Test 2
ok (test_tied_hash());

#########
# Test 3
ok (test_obj_hash());

exit;

#####################################################################
#####################################################################

sub test_directory {
    return $TESTDIR;
}

#####################################################################
#####################################################################

sub test_tied_hash {

    my $multi_n = 4;
    my $flags   = &O_RDWR() | &O_CREAT();
    my $mode    = 0666;

    my $result = eval {
        my %hash = ();
        unless (tie (%hash, $TIE_CLASS, test_directory(), $flags, $mode, $DB_HASH, $multi_n)) {
                diag("Hash tie failed");
                return 0;
        }

    };
    if ($@ or (0 == $result)) {
        diag("Hash tie failed unexpectedly");
        return 0;
    }

    eval {
        my %hash = ();
        tie (%hash, $TIE_CLASS);
    };
    unless ($@) {
        diag("Hash tie failed to catch bad tie parameters");
        return 0;
    }

    $result = eval {
        my %hash = ();
        my $hash_obj;
        unless ($hash_obj = tie (%hash, $TIE_CLASS, test_directory(), $flags, $mode, $DB_HASH, $multi_n)) {
                diag("Hash tie failed");
                return 0;
        }

        {
            my $test_key   = 'test';
            my $test_value = 'value';
            $hash{$test_key} = $test_value;
            unless (exists ($hash{$test_key}) and ($hash{$test_key} eq $test_value)) {
                diag("Tied hash existance check for key $test_key failed unexpectedly");
                return 0;
            }
            delete $hash{$test_key};
            if (exists ($hash{$test_key})) {
                diag("Hash value was found after deletion");
                return 0;
            }
        }

        {
            my $test_key   = 'key';
            my $test_value = 'value';
            $hash{$test_key} = $test_value;
            unless (exists ($hash{$test_key}) and ($hash{$test_key} eq $test_value)) {
                diag("Tied hash existance check for non-scalar key failed unexpectedly");
                return 0;
            }
            delete $hash{$test_key};
            if (exists ($hash{$test_key})) {
                diag("Hash value was found after deletion");
                return 0;
            }
        }
        {
            my %test_items = qw ( a b    c d    e f
                                  g h    i j    k l
                                  m n
                                );

            my @item_keys = sort keys %test_items;
            my $n_item_keys = $#item_keys + 1;
            foreach my $item (@item_keys) {
                $hash{$item} = $test_items{$item};
            }
            my $match_counter = 0;
            foreach my $item (@item_keys) {
                my $item_value = $hash{$item};
                $match_counter++;
                unless ($item_value eq $test_items{$item}) {
                    diag("Hash value for item was incorrect");
                    return 0;
                }
            }
            while (my ($hash_key, $hash_value) = each %hash) {
                unless ($hash_value eq $test_items{$hash_key}) {
                    diag("Hash value for item was incorrect");
                    return 0;
                }
            }


            eval { %hash = (); };
            if ($@) {
                diag("hash clear threw an error: $@");
                return 0;
            }
            foreach my $item (@item_keys) {
                if (exists $hash{$item}) {
                    diag("Hash clear failed to completely clear tied hash");
                    return 0;
                }
            }
        }
        return 1;
    };
    if ($@) {
        diag("Tied test failed unexpectedly: $@");
        return 0;
    }
    if (0 == $result) {
        return 0;
    }

    return 1;
}

#####################################################################
#####################################################################

sub test_obj_hash {

    my $multi_n = 4;
    my $flags   = &O_RDWR() | &O_CREAT();
    my $mode    = 0666;

    my %hash = ();
    my $obj;
    unless ($obj = tie (%hash, $TIE_CLASS, test_directory(), $flags, $mode, $DB_HASH, $multi_n)) {
        diag("Hash tie failed");
        return 0;
    }

    {
        my $test_key   = 'test';
        my $test_value = 'value';

        my $check_value;
        unless (0 == $obj->put($test_key => $test_value)) {
            diag("put for key failed unexpectedly");

        }

        unless (0 == $obj->get($test_key, $check_value)) {
            diag("get for key failed unexpectedly");
            return 0;
        }
        unless ($check_value eq $test_value) {
            diag("get for key returned unexpected value (expected '$test_value', got '$check_value')");
            return 0;

        }

        unless (0 == $obj->del($test_key)) {
            diag("delete on key failed unexpectedly");
            return 0;
        }
        unless (1 == $obj->del($test_key)) {
            diag("delete on non-existent key returned unexpected value");
            return 0;
        }
        unless ($obj->fd) {
            diag("'fd' failed to return file descriptor");
            return 0;
        }
    }

    {
        my %test_items = qw ( a b    c d    e f
                              g h    i j    k l
                              m n
                            );

        my @item_keys = sort keys %test_items;
        foreach my $item (@item_keys) {
            $obj->put($item => $test_items{$item});
        }
        my $match_counter = 0;
        foreach my $item (@item_keys) {
            my $item_value;
            unless ($obj->exists($item)) {
                diag("existence test failed for key $item");
                return 0;
            }
            unless (0 == $obj->get($item, $item_value)) {
                diag("Failed to retrieve value for key $item");
                return 0;
            }
            $match_counter++;
            unless ($item_value eq $test_items{$item}) {
                diag("Hash value for item was incorrect");
                return 0;
            }
        }

        my ($key, $value, $status);
        for ($status = $obj->seq($key, $value, R_FIRST) ; $status == 0 ; $status = $obj->seq($key, $value, R_NEXT) ) {
            unless ($test_items{$key} eq $value) {
                diag("Hash value for $key was incorrect");
                return 0;
            }
        }

        eval {
            $obj->sync;
        };
        if ($@) {
            diag("'sync' failed: $@");
            return 0;
        }

        $obj->clear;
        foreach my $item (@item_keys) {
            my $item_value;
            unless (1 == $obj->get($item, $item_value)) {
                diag("Unexpectedly found value after clearing");
                return 0;
            }
        }
    }

    return 1;
}

#####################################################################
#####################################################################

sub test_tie {
    {
        my $multi_n = 4;
        my $flags   = &O_RDWR() | &O_CREAT();
        my $mode    = 0666;

        my $result = eval {
            my %hash;
            my $fixer = tie (%hash, $TIE_CLASS, test_directory(), $flags, $mode, $DB_HASH, $multi_n);
            return $fixer;
        };
        if ($@ or not $result) {
            diag("Direct mode constructor failed");
            return 0;
        }
    }

    return 1;
}
