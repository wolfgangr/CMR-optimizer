#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper qw(Dumper);
use List::Util qw(min max sum zip);

use Geo::LibProj::cs2cs;
use Geo::LibProj::FFI;

# see https://metacpan.org/pod/PDL::Fit::Levmar#example-1
# use PDL::LiteF;
use PDL::Lite;
use PDL::Fit::Levmar;
use PDL::NiceSlice;
use constant PI    => 4 * atan2(1, 1);

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
my @rownums = (0 .. $#data);

# arrange data in hash by row# and column label
my %d_hash;
foreach my $ri (@rownums) {
  my @dr = @{$data[$ri]};
  foreach my $ci (0 .. $#labels) {
    $d_hash{$ri}{$labels[$ci]}=$dr[$ci];
    $d_hash{$ri}{IDX} = $ri;
  }
}

# ---------- restore lat/lon ----------

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
# goto EODEBUG_WKT;
print "\n";
print $WKT;

goto EODEBUG_WKT;
print "\n";
print Data::Dumper->Dump([\@labels, \@data, \%d_hash], 
                        [qw(\@labels \@data \%d_hash)]);
EODEBUG_WKT:

# ---- prepare for estimators and defaults ---------
# requires List::Util

# my @lat_list = map { $_->{lat} } values %d_hash;
my @d_sorted = map { $d_hash{$_} } @rownums;

my @lat_list = map { $_->{lat} } @d_sorted; #  map { $d_hash{$_} } @rownums;
my @lon_list = map { $_->{lon} } @d_sorted; # map { $d_hash{$_} } @rownums; #  values %d_hash;

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

# ---------- give it a try with lambert azimutal equal area  -----------

my $proj_laea_template = '+proj=laea +lat_0=%f +lon_0=%f +ellps=WGS84 +units=m +no_defs +type=crs';

# 

my $est_lon_0 = ($lon_min + $lon_max) / 2 ;    #  central meridian in the middle
# if lat_0 is where our Y is 0, this is collinear to helmert shift y?
my $est_lat_0 =  ($lat_min + $lat_max) / 2; 	 
# my $est_lat_1 = ($lat_min + $lat_avg) / 2 ;     #  1st parallel at 1st quartile
# my $est_lat_2 = ($lat_max + $lat_avg) / 2 ;     #  2nd parallel at 3rd quartile
my @estimates = ($est_lat_0, $est_lon_0);

my $proj_laea_1st_est = sprintf $proj_laea_template, @estimates;
print $proj_laea_1st_est, "\n";

my $cs_1st_est = Geo::LibProj::cs2cs->new($CRS_lat_lon => $proj_laea_1st_est);

# die "~~~~ DEBUG ~~~~";

# add 1st estimations to d_hash
foreach my $dhv (values %d_hash) {
  my $r = $cs_1st_est->transform([($dhv->{lat}, $dhv->{lon}  ) ]);
  $dhv->{est1X} = $r->[0];
  $dhv->{est1Y} = $r->[1];
}

# --- collect statistics of 1st estimated value set
#
my @est1X_list = map { $_->{est1X} } @d_sorted; # values %d_hash;
my @est1Y_list = map { $_->{est1Y} } @d_sorted; # values %d_hash;

die "no est points found" unless @est1X_list && @est1Y_list;
die "est point number inconsistent" unless $#est1X_list == $#est1Y_list;

my $est1X_min = min @est1X_list;
my $est1X_max = max @est1X_list;
my $est1X_avg = (sum @est1X_list) / (scalar @est1X_list);

my $est1Y_min = min @est1Y_list;
my $est1Y_max = max @est1Y_list;
my $est1Y_avg = (sum @est1Y_list) / (scalar @est1Y_list);

print "\n";
printf "extent ( \tmin \tavg \tmax \tnum) \n";
printf "est1X:    %f | %f | %f | %d \n",  $est1X_min, $est1X_avg, $est1X_max , scalar @est1X_list;
printf "est1Y:    %f | %f | %f | %d \n",  $est1Y_min, $est1Y_avg, $est1Y_max , scalar @est1Y_list;
print "\n";

# --- collect statistics of match points in source raster
#
my @sourceX_list = map { $_->{sourceX} } @d_sorted; # values %d_hash;
my @sourceY_list = map { $_->{sourceY} } @d_sorted; # values %d_hash;

die "no source points found" unless @sourceX_list && @sourceY_list;
die "source point number inconsistent" unless $#sourceX_list == $#sourceY_list;

my $sourceX_min = min @sourceX_list;
my $sourceX_max = max @sourceX_list;
my $sourceX_avg = (sum @sourceX_list) / (scalar @sourceX_list);

my $sourceY_min = min @sourceY_list;
my $sourceY_max = max @sourceY_list;
my $sourceY_avg = (sum @sourceY_list) / (scalar @sourceY_list);

print "\n";
printf "extent ( \tmin \tavg \tmax \tnum) \n";
printf "sourceX:    %f | %f | %f | %d \n",  $sourceX_min, $sourceX_avg, $sourceX_max , scalar @sourceX_list;
printf "sourceY:    %f | %f | %f | %d \n",  $sourceY_min, $sourceY_avg, $sourceY_max , scalar @sourceY_list;
print "\n";

# 1st estimates for Helmert Raster -> 1st est CRS
my $scaleX = ($est1X_max - $est1X_min) /  ($sourceX_max - $sourceX_min) ;
my $scaleY = ($est1X_max - $est1X_min) /  ($sourceX_max - $sourceX_min) ;
my $scale2D = ($scaleX + $scaleY) / 2;
my $shiftX = $est1X_avg - $scaleX * $sourceX_avg;
my $shiftY = $est1Y_avg - $scaleY * $sourceY_avg;
my $rot =0;  # keep this for possible extension
my @est_helmert = ($shiftX, $shiftY, $scale2D, $rot ); # for building param PDL
# my @est_helmert = ($shiftX, $shiftY, $scale2D); # ... not built with lapack

printf "\$scaleX: %f ; \$scaleY: %f ; \$scale2D: %f ; \$shiftX: %f ;  \$shiftY: %f ; \n",
	$scaleX, $scaleY, $scale2D, $shiftX,  $shiftY;

# die "### DEBUG ===";
# ========= debug of start value finding
#

goto EODEBUG1;
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
EODEBUG1:

# ======== prepare PDLs for levmar ==============================

# my $par_est = pdl [ 1,2,3 ]; # [( @est_helmert, @estimates )] ;
my $par_est = pdl [  (@est_helmert, @estimates) ] ;
# my $FIX = pdl  qw(0 0 0 1 0 0 0 0) ; # keep helmert rotation fixed
my $PDL_lon_lat  =  pdl ( zip (\@lon_list,     \@lat_list ) );
my $PDL_lon_lat_flat = $PDL_lon_lat->clump(2);
my $PDL_sourceXY =  pdl ( zip (\@sourceX_list, \@sourceY_list ));
my $PDL_sourceXY_flat = $PDL_sourceXY->clump(2);

print $par_est, "\n";
# print $FIX, "\n";
print $PDL_lon_lat, "\n";
print $PDL_lon_lat_flat, "\n";
print $PDL_sourceXY, "\n";
print $PDL_sourceXY_flat, "\n";

# build levmar
# my $proj_pipline_rev = '';
# $proj_pipline_rev .= '+proj=eqdc +lat_0=%f +lon_0=%f +lat_1=%f +lat_2=%f';
# $proj_pipline_rev .= ' +ellps=intl +units=m +no_defs';

my $proj_pipeline = $proj_laea_template;

print $proj_pipeline, "\n";
# die " #### DEBUG ###";

sub proj_laea_sub {  
  my ($p,$x,$t) = @_;
  # print "===============debug in sub dummy =========\n";
  print 'P: ', $p, "\n";
  my ($dx, $dy, $scale, $rot, $lat0, $lon0) = list $p;
  # $rot +=3; # ### TBD --- remove ... testin gonyl !!!!!!!!!!
  my $phi =  $rot * PI / 180; 
 
  my $ps = sprintf $proj_pipeline, 
    $lat0, $lon0 ; # , $lat1, $lat2; 
  print $ps, "\n";

  my $cs_src = Geo::LibProj::cs2cs->new($CRS_lat_lon => $ps);
  my @inp = List::Util::pairmap { [$b , $a  ] }  $t->list;  # $T is lon_lat ! 
  # print scalar @inp;
  # print ' | @inp: ', Dumper(\@inp);
  # my @r = $cs_src-> transform( @inp );
  my $r_pdl = pdl ( $cs_src-> transform( @inp ) );
  my @r =(); # dummy to be removed
  # my $r_pdl = pdl @r;
  $r_pdl = $r_pdl(0:1); # 
  print $r_pdl;

  # do inverse helmert in PDL
  my $rot_pdl =  pdl [[ cos($phi), sin($phi) ],[ -sin($phi), cos($phi)]] ;
  $rot_pdl *= $scale;
  print $rot_pdl;

  my $shift_pdl = pdl [ $dx, $dy ];
  print $shift_pdl;
  $r_pdl -= $shift_pdl;
  print $r_pdl;

  $r_pdl .= $r_pdl x $rot_pdl->inv ;
  print $r_pdl;

  # apply my own reverse helmert and flatten list
  my @rr = map { (
    ($$_[0] - $dx) / $scale,
    ($$_[1] - $dy) / $scale 
         ) } @r;
  # $x .= [ @rr ];
  if (0) {
    print 't: ', $t, "\n";
    print 'x: ', $x, "\n";
    print '@r: ', Dumper(\@r);
    print '@rr: ', Dumper(\@rr);
  }

}  

my $levmar_result = levmar(
	P => $par_est, 
	X => $PDL_sourceXY_flat,
	T => $PDL_lon_lat_flat,
	FUNC =>  \&proj_laea_sub 
  );

print levmar_report($levmar_result);
