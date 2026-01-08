#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper qw(Dumper);

use Geo::LibProj::cs2cs;
use Geo::LibProj::FFI;


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

my @labels = @{shift @data};

my %d_hash;

foreach my $ri (0 .. $#data) {
  my @dr = @{$data[$ri]};
  foreach my $ci (0 .. $#labels) {
    $d_hash{$ri}{$labels[$ci]}=$dr[$ci];
  }
}


print "\n";
print $WKT;
print "\n";

print Data::Dumper->Dump([\@labels, \@data, \%d_hash], 
                        [qw(\@labels \@data \%d_hash)]);
