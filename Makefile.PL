use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'           => 'Tie::DB_File::SplitHash',
    'VERSION_FROM'   => 'lib/Tie/DB_File/SplitHash.pm',
    'PREREQ_PM'      => { 'Digest::SHA1' => 0,
	                      'DB_File'      => 0,
						  'Fcntl'        => 0,
						  'File::Path'   => 0,
						  'Carp'         => 0,
						  'Tie::Hash'    => 0,
						  'Exporter'     => 0,
						 },
    'linkext'        => { LINKTYPE=>'' },    # no link needed
    'dist'           => {'COMPRESS'=>'gzip -9f', 'SUFFIX' => 'gz',
    'ZIP'            => '/usr/bin/zip','ZIPFLAGS'=>'-rl'}
);
