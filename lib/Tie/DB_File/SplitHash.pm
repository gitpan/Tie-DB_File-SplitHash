#!/usr/bin/perl -w
# $RCSfile: SplitHash.pm,v $ $Revision: 1.1 $ $Date: 1999/06/15 16:45:31 $ $Author: snowhare $
package Tie::DB_File::SplitHash;

use strict;
use Exporter;
use Carp;
use Tie::Hash;
use DB_File;
use File::Path;
use Digest::SHA1 qw (sha1_hex);
use Fcntl qw (:flock);
use vars qw ($VERSION @ISA @EXPORT $DB_HASH);

$VERSION = "1.00";
@ISA     = qw (Tie::Hash Exporter);
@EXPORT  = qw(
        $DB_HASH 

        DB_LOCK
        DB_SHMEM
        DB_TXN
        HASHMAGIC
        HASHVERSION
        MAX_PAGE_NUMBER
        MAX_PAGE_OFFSET
        MAX_REC_NUMBER
        RET_ERROR
        RET_SPECIAL
        RET_SUCCESS
        R_CURSOR
        R_DUP
        R_FIRST
        R_FIXEDLEN
        R_IAFTER
        R_IBEFORE
        R_LAST
        R_NEXT
        R_NOKEY
        R_NOOVERWRITE
        R_PREV
        R_RECNOSYNC
        R_SETCURSOR
        R_SNAPSHOT
        __R_UNUSED
);

eval {
    # Make all Fcntl O_XXX constants available for importing
    require Fcntl;
    my @O = grep /^O_/, @Fcntl::EXPORT;
    Fcntl->import(@O);  # first we import what we want to export
    push(@EXPORT, @O);
};

=head1 NAME

Tie::DB_File::SplitHash - A wrapper around the DB_File Berkeley database system

=head1 SYNOPSIS

   use Tie::DB_File::SplitHash;

   [$X =] tie %hash,  'Tie::DB_File::SplitHash', $filename, $flags, $mode, $DB_HASH, $multi_n;

   $status = $X->del($key [, $flags]) ;
   $status = $X->put($key, $value [, $flags]) ;
   $status = $X->get($key, $value [, $flags]) ;
   $status = $X->seq($key, $value, $flags) ;
   $status = $X->sync([$flags]) ;
   $status = $X->fd ;

   untie %hash ;

$multi_n determines the 'spread out' or number of files the hash will be
split between. The larger the number, the larger the final hash can be.

=head1 DESCRIPTION

Transparently splits a Berkeley database (DB_File) into
multiple files to allow the exceeding of file system
limits on file size. From the outside, it behaves identically
with Berkeley DB hash support in general. This has the potential 
to greatly expand the amount of data that can be stored on a file 
size limitted file system.

It does so by taking a SHA1 hash of the key to be stored, folding
the resulting hash into a value from 0 to X and storing the data
to a db file selected by the value 0 to X. The randomizing behavior
of the SHA1 and subsequent fold down distribute the records essentially
randomly between the X+1 database files, raising the capacity of the
database to (X+1) times the capacity of a single file database on
the average.

NOTE: Using an 'in-memory' database is not supported by this.
Use DB_File directly if you want to do that. Additionally,
BTREE and RECNO DBs are not supported.

=cut

###############################################################################

sub TIEHASH {
    my $something = shift;
    my ($class)   = ref ($something) || $something;
    my $self      = bless {},$class;
    my $parms     = [];
    @$parms       = @_;

    $self->{-init_parms} = $parms;
    my $n_parms = $#$parms + 1;
    if ($n_parms != 5) {
		croak(__PACKAGE__ . "::init_hash() - incorrect number of calling parameters\n");
    }
	my $multi_n = pop @$parms;
	$self->{-multi_n} = $multi_n;
    $self->{-dirname} = $parms->[0];
    if (not ((-e $self->{-dirname}) or (mkdir ($self->{-dirname},0777)))) {
        croak(__PACKAGE__ . "::TIEHASH - datafiles directory '$self->{-dirname}' does not exist and cannot be created.\n$!");
    }
    my $main_index_file  = "$self->{-dirname}/index";
    shift @$parms;
	$multi_n--;
	my $errors=0;
	my $error_message = '';
	foreach my $f_part (0..$multi_n) {
    	my $tied_hash = {};
    	my $db_object = tie %$tied_hash,'DB_File',"${main_index_file}_${f_part}.db",@$parms;
    	if (not defined $db_object) {
			$errors = $f_part + 1;
			$error_message = $!;
			last;
		}
		$self->{-database}->[$f_part]->{-object} = $db_object;
	}
	if ($errors) {
		delete $self->{-database};
		croak ("Failed to open database: $error_message\n");
	}

    $self;
}

#######################################################################

sub STORE {
    my $self = shift;

    my ($key,$value) = @_;
	my ($section) = $self->section_hash($key);
	my ($db_object) = $self->{-database}->[$section]->{-object};
	$db_object->STORE(@_);
}

#######################################################################

sub FETCH {
    my ($self) = shift;

	my ($key)  = @_;

	my ($section)   = $self->section_hash($key);
	my ($db_object) = $self->{-database}->[$section]->{-object};
    $db_object->FETCH(@_);
}

#######################################################################

sub DELETE {
    my ($self) = shift;
	
	my ($key) = @_;

	my ($section)   = $self->section_hash($key);
	my ($db_object) = $self->{-database}->[$section]->{-object};
    $db_object->DELETE(@_);
}

#######################################################################

sub CLEAR {
    my $self = shift;

	foreach my $database (@{$self->{-database}}) {
    	my ($db_object) = $database->{-object};
    	$db_object->CLEAR(@_);
	}
}

#######################################################################

sub EXISTS {
    my ($self) = shift;
	
	my ($key) = @_;

	my $section     = $self->section_hash($key);
    my ($db_object) = $self->{-database}->[$section]->{-object};
    $db_object->EXISTS(@_);
}

#######################################################################

=over 4

=item C<DESTROY;>

Called when the tied object is being destroyed. 

=back

=cut

sub DESTROY {
    my $self = shift;

	delete $self->{-database};
}

#######################################################################

sub FIRSTKEY {
    my $self = shift;

    my ($db_object) = $self->{-database}->[0]->{-object};
	$self->{-iteration_section} = 0;
    $db_object->FIRSTKEY(@_);
}

#######################################################################

sub NEXTKEY {
    my ($self) = shift;
	
	my ($key) = @_;

	my ($section)   = $self->{-iteration_section};
	my ($multi_n)   = $self->{-multi_n};
    my ($db_object) = $self->{-database}->[$section]->{-object};
	my $next_key    = undef;
	while (not defined $next_key) {
        $next_key = $db_object->NEXTKEY($key);
		if (not defined $next_key) {
			$section++;
			$self->{-iteration_section} = $section;
    		$db_object = $self->{-database}->[$section]->{-object};
			last if (not defined $db_object);
			$next_key = $db_object->FIRSTKEY;
		}
	}
	$next_key;
}

#######################################################################

sub section_hash {
	my ($self) = shift;
	
	my ($key) = @_;

	my $sections    = $self->{-multi_n};
	my ($digest)    = sha1_hex($key);
	my $section_n   = hex(substr($digest,0,2)) % $sections;
	$section_n;
}

#######################################################################

sub put {
    my $self = shift;

    my $parms = [];
    @$parms   = @_;
    my $key   = shift @$parms;
	my $section = $self->section_hash($key);
	my $db_object = $self->{-database}->[$section]->{-object};
    $db_object->put(@_);
}

#######################################################################

sub get {
    my $self = shift;

    my $parms     = [];
    @$parms       = @_;
    my $key       = shift @$parms;
	my $section   = $self->section_hash($key);
	my $db_object = $self->{-database}->[$section]->{-object};
    $db_object->get(@_);
}

#######################################################################

sub seq {
    my $self = shift;

    my $parms     = [];
    @$parms       = @_;
    my $key       = shift @$parms;
	my $section   = $self->section_hash($key);
	my $db_object = $self->{-database}->[$section]->{-object};
    $db_object->seq(@_);
}

#######################################################################

sub del {
    my $self = shift;

    my $parms     = [];
    @$parms       = @_;
    my $key       = shift @$parms;
	my $section   = $self->section_hash($key);
	my $db_object = $self->{-database}->[$section]->{-object};
    $db_object->del(@_);
}

#######################################################################

sub sync {
    my $self = shift;

	foreach my $db (@{$self->{-database}}) {
		my $db_object = $db->{-object};
    	$db_object->sync(@_);
	}
}

#######################################################################

sub fd {
    my $self = shift;

    my $db_object = $self->{-database}->[0]->{-object};
    my $result = $db_object->fd(@_);
}

#######################################################################

sub exists {
    my ($self) = shift;
	
    $self->EXISTS(@_);
}

#######################################################################

sub clear {
    my $self = shift;

	$self->CLEAR(@_);
}

#######################################################################

=head1 COPYRIGHT 

Copyright 1999, Benjamin Franz (<URL:http://www.nihongo.org/snowhare/>) and 
FreeRun Technologies, Inc. (<URL:http://www.freeruntech.com/>). All Rights Reserved.
This software may be copied or redistributed under the same terms as Perl itelf.

=head1 AUTHOR

Benjamin Franz

=head1 TODO

Testing.

=cut

1;
