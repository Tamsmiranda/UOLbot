#!/usr/bin/perl -w
use strict;
use UOLbot;

my $bot = new UOLbot;
my @rooms = ();
foreach my $subgrp (@ARGV) {
   foreach my $room ($bot->list_subgrp ($subgrp)) {
      push @rooms, $room;
   }
}

foreach my $room (sort { $a->{URL} cmp $b->{URL} } @rooms) {
   print $room->{URL}, "\t", $room->{Title}, "\n";
}

exit;
