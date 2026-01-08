#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper qw(Dumper);
use List::Util qw(min max sum);

use Geo::LibProj::cs2cs;
use Geo::LibProj::FFI;
use PDL::Fit::Levmar;

my $CRS_lat_lon = "WGS 84";

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
my $cs2cs = Geo::LibProj::cs2cs->new($crs_wkt => $CRS_lat_lon);

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

# ---- prepare for estimators and defaults ---------
# requires List::Util

my @lat_list = map { $_->{lat} } values %d_hash;
my @lon_list = map { $_->{lon} } values %d_hash;

die "no points processed" unless @lat_list && @lon_list;
die "point number inconsistent" unless $#lat_list == $#lon_list; 

my $lat_min = min @lat_list;
my $lat_max = max @lat_list;
my $lat_avg = (sum @lat_list) / (scalar @lat_list);

my $lon_min = min @lon_list;
my $lon_max = max @lon_list;
my $lon_avg = (sum @lon_list) / (scalar @lon_list);


print "\n";
printf "extent ( \tmin \tavg \tmax \tnum) \n";
printf "lat:    %f | %f | %f | %d \n",  $lat_min, $lat_avg, $lat_max , scalar @lat_list;
printf "lon:    %f | %f | %f | %d \n",  $lon_min, $lon_avg, $lon_max , scalar @lon_list;
print "\n";

# ---------- giv it a try with equidistant conic projection -----------
# +proj=eqdc +lat_0=30 +lon_0=10 +lat_1=43 +lat_2=62 +x_0=0 +y_0=0 +ellps=intl +units=m +no_defs +type=crs

my $proj_eqdc_template = '+proj=eqdc +lat_0=%f +lon_0=%f +lat_1=%f +lat_2=%f +ellps=intl +units=m +no_defs +type=crs';

my $proj_eqdc_1st_est = sprintf $proj_eqdc_template, 
   $lat_min, 
   ($lon_min + $lon_max) / 2 , 
   ($lat_min + $lat_avg) / 2,
   ($lat_max + $lat_avg) / 2;

print $proj_eqdc_1st_est, "\n";

my $cs_1st_est = Geo::LibProj::cs2cs->new($CRS_lat_lon => $proj_eqdc_1st_est);

foreach my $dhv (values %d_hash) {
  my $r = $cs_1st_est->transform([($dhv->{lat}, $dhv->{lon}  ) ]);
  $dhv->{est1X} = $r->[0];
  $dhv->{est1Y} = $r->[1];
}

print Data::Dumper->Dump([\%d_hash], [qw(\%d_hash)]);

# IDX lat lon sourceX sourceY mapX mapY est1X est1Y
my @printfields = qw (IDX lat lon sourceX sourceY mapX mapY est1X est1Y);
print join '|',  @printfields;
print "\n";

foreach my $k ( sort { $a <=> $b } keys %d_hash) {
  my $dhv = $d_hash{$k};
  foreach my $f (@printfields) {
    print $dhv->{$f}, ' | '    ;
  }
  print "\n";
}

