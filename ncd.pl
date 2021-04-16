#!/usr/bin/env perl
use 5.020;
use experimental qw( signatures );
use warnings qw( all );
no warnings qw( experimental::signatures );

use Getopt::Long qw( GetOptions );
use List::Util qw( max );

sub ncd ( $x, $y, $C = 'gzip', $x_key = undef, $y_key = undef ) {
    state $cache = {};
    state $compressors = {
        bzip2 => sub ( $data ) {
            require IO::Compress::Bzip2;
            IO::Compress::Bzip2::bzip2( \$data, \my $tmp, BlockSize100K => 9 );
            # a .bz2 stream consists of a 4-byte header
            return length( $tmp ) - 4;
        },
        gzip => sub ( $data ) {
            require Compress::Zlib;
            # minimum possible gzip header is exactly 10 bytes
            return length( Compress::Zlib::memGzip( $data ) ) - 10;
        },
        zlib => sub ( $data ) {
            require Compress::Zlib;
            # XXX: double-check RFC-1950
            return length( Compress::Zlib::compress( $data, 9 ) ) - 2;
        },
        xz => sub ( $data ) {
            require IO::Compress::Xz;
            IO::Compress::Xz::xz( \$data, \my $tmp, Preset => 9, Extreme => 1 );
            # XZ Stream Header (12 bytes)
            return length( $tmp ) - 12;
        },
        zstd => sub ( $data ) {
            require Compress::Stream::Zstd;
            # XXX: header size is variable (from 6 to 18 bytes)
            return length( Compress::Stream::Zstd::compress( $data, 19 ) ) - 6;
        },
    };

    local $" = ', ';
    my $compressor = $compressors->{ fc $C }
        or die "Unknown compressor '$C'. Pick one from: @{[ sort keys %$compressors ]}\n";

    # https://complearn.org/ncd.html
    my ( $Cx, $Cy );
    if ( $x_key && $y_key ) {
        $Cx = $cache->{ $x_key } //= $compressor->( $x );
        $Cy = $cache->{ $y_key } //= $compressor->( $y );
    } else {
        $Cx = $compressor->( $x );
        $Cy = $compressor->( $y );
    }
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
        'compressor=s'  => \my $compressor,
        'tsv'           => \my $tsv,
    );
    $compressor ||= 'gzip';

    if ( @ARGV == 2 ) {
        # compare 2 files
        say ncd(
            read_file( $ARGV[0] ),
            read_file( $ARGV[1] ),
            $compressor
        );
    } elsif ( @ARGV > 2 ) {
        # compare all files pairwise and print the matrix
        local $| = 1;
        my $filename_length = max map { length } @ARGV;
        for my $i ( 0 .. $#ARGV ) {
            my $file_x = $ARGV[$i];
            printf "%-${filename_length}s ", $file_x;
            for my $j ( 0 .. $#ARGV ) {
                next if $i <= $j;
                my $file_y = $ARGV[$j];
                my $similarity = ncd(
                    read_file( $file_x ),
                    read_file( $file_y ),
                    $compressor,
                    $file_x,
                    $file_y
                );
                if ( $tsv ) {
                    say join "\t", $similarity, $file_x, $file_y;
                } else {
                    printf '%.03f ', $similarity;
                }
            }
            print "\n" unless $tsv;
        }
    } else {
        die "Usage: $0 [--compressor=...] FILES\n";
    }

    return 0;
}

exit main();
