#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper qw(Dumper);

use Geo::LibProj::cs2cs;
use Geo::LibProj::FFI;
use PDL::Fit::Levmar;

#============= read by <> ================

my @data;
my $WKT;

while (<>) {

  if (/^#/) {
    print '#';
    $WKT = $_;
  } else {
    print '.';
    my @datarow = split ',', $_;
    push @data, \@datarow;
  }
  # print "\n";
}

#========= process ===========

my @labels = @{shift @data};

# arrange data in hash by row# and column label
my %d_hash;
foreach my $ri (0 .. $#data) {
  my @dr = @{$data[$ri]};
  foreach my $ci (0 .. $#labels) {
    $d_hash{$ri}{$labels[$ci]}=$dr[$ci];
    $d_hash{$ri}{IDX} = $ri;
  }
}

# ---------- restore lat/lon ----------
# my $cs2cs = Geo::LibProj::cs2cs->new("EPSG:25833" => "EPSG:4326");
# my $cs2cs = Geo::LibProj::cs2cs->new("ESRI:54043" => "WGS 84");

# regain CRS spec from point file
my ($check_crs, $crs_wkt) = ( $WKT =~ /^(#CRS\: )(.*)$/  );
die "cannot find starter in \$WKT string" unless $check_crs;

# setup transfer machine 
my $cs2cs = Geo::LibProj::cs2cs->new($crs_wkt => "WGS 84");

# restore lat/lon in %d_hash
foreach my $dhv (values %d_hash) {
  my $point_in = [ $dhv->{mapX}, $dhv->{mapY} ];
  my $point_out = $cs2cs->transform( $point_in  ) ;
  $dhv->{lat} = $point_out->[0];
  $dhv->{lon} = $point_out->[1];
}

#======= debug out for restore lat/lon  ===========

print "\n";
print $WKT;
print "\n";

print Data::Dumper->Dump([\@labels, \@data, \%d_hash], 
                        [qw(\@labels \@data \%d_hash)]);

# 


