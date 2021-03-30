#!/usr/bin/env perl
use 5.020;
use experimental qw( signatures );
use warnings qw( all );
no warnings qw( experimental::signatures );

use Digest::SHA qw( sha256 );
use Getopt::Long qw( GetOptions );

sub ncd ( $x, $y, $C = 'gzip' ) {
    state $cache = {};
    state $compressors = {
        bzip2 => sub ( $data ) {
            require IO::Compress::Bzip2;
            IO::Compress::Bzip2::bzip2( \$data, \my $tmp, BlockSize100K => 9 );
            return length $tmp;
        },
        gzip => sub ( $data ) {
            require Compress::Zlib;
            # minimum possible gzip header is exactly 10 bytes
            return length( Compress::Zlib::memGzip( $data ) ) - 10;
        },
        zlib => sub ( $data ) {
            require Compress::Zlib;
            return length Compress::Zlib::compress( $data, 9 );
        },
        xz => sub ( $data ) {
            require IO::Compress::Xz;
            IO::Compress::Xz::xz( \$data, \my $tmp, Preset => 9 );
            return length $tmp;
        },
        zstd => sub ( $data ) {
            require Compress::Stream::Zstd;
            return length Compress::Stream::Zstd::compress( $data, 19 );
        },
    };

    local $" = ', ';
    my $compressor = $compressors->{ fc $C }
        or die "Unknown compressor '$C'. Pick one from: @{[ sort keys %$compressors ]}\n";

    # https://complearn.org/ncd.html
    my $Cx  = $cache->{ sha256( $x ) } //= $compressor->( $x );
    my $Cy  = $cache->{ sha256( $y ) } //= $compressor->( $y );
    my $Cxy = $compressor->( $x . $y );
    my ( $min, $max ) = $Cx < $Cy
        ? ( $Cx, $Cy )
        : ( $Cy, $Cx );

    return ( $Cxy - $min ) / $max;
}

sub read_file ( $filename ) {
    local $/;
    open( my $fh, '<:raw', $filename )
        or die "Can't open '$filename': $!\n";
    my $data = <$fh>;
    close $fh;
    return $data;
}

sub main {
    GetOptions(
        'compressor=s' => \my $compressor,
    );

    if ( @ARGV == 2 ) {
        # compare 2 files
        my $data1 = read_file( $ARGV[0] );
        my $data2 = read_file( $ARGV[1] );
        say ncd( $data1, $data2, $compressor || () );
    } elsif ( @ARGV > 2 ) {
        # compare all files pairwise and print the matrix
        for my $i ( 1 .. $#ARGV ) {
            for my $j ( 0 .. $#ARGV ) {
                next if $i <= $j;
                my $data1 = read_file( $ARGV[$i] );
                my $data2 = read_file( $ARGV[$j] );
                printf "%.03f ", ncd( $data1, $data2, $compressor || () );
            }
            print "\n";
        }
    } else {
        die "Usage: $0 [--compressor=...] FILES\n";
    }

    return 0;
}

exit main();
