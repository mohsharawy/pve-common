#!/usr/bin/perl

use lib '../src';
use strict;
use warnings;
use POSIX ();
use Data::Dumper;
use Time::Local;
use Test::More;

use PVE::CalendarEvent;

# Time tests should run in a controlled setting
$ENV{TZ} = 'UTC';
POSIX::tzset();

my $alldays = [0,1,2,3,4,5,6];
my $tests = [
    [
     '*',
     { h => '*', m => '*', dow => $alldays },
     [
      [0, 60],
      [30, 60],
      [59, 60],
      [60, 120],
     ]
    ],
    [
     '*/10',
     { h => '*', m => [0, 10, 20, 30, 40, 50], dow => $alldays },
     [
      [0, 600],
      [599, 600],
      [600, 1200],
      [50*60, 60*60]
     ]
    ],
    [
     '*/12:0' ,
     { h => [0, 12], m => [0], dow => $alldays },
     [
      [ 10, 43200],
      [ 13*3600, 24*3600],
     ]
    ],
    [
     '1/12:0/15' ,
     { h => [1, 13], m => [0, 15, 30, 45], dow => $alldays },
     [
      [0, 3600],
      [3600, 3600+15*60],
      [3600+16*60, 3600+30*60 ],
      [3600+30*60, 3600+45*60 ],
      [3600+45*60, 3600+12*3600],
      [13*3600 + 1, 13*3600+15*60],
      [13*3600 + 15*60, 13*3600+30*60],
      [13*3600 + 30*60, 13*3600+45*60],
      [13*3600 + 45*60, 25*3600],
     ],
    ],
    [
     '1,4,6',
     { h => '*', m => [1, 4, 6], dow => $alldays},
     [
      [0, 60],
      [60, 4*60],
      [4*60+60, 6*60],
      [6*60, 3600+60],
     ]
    ],
    [
     '0..3',
     { h => '*', m => [ 0, 1, 2, 3 ], dow => $alldays },
    ],
    [
     '23..23:0..3',
     { h => [ 23 ], m => [ 0, 1, 2, 3 ], dow => $alldays },
    ],
    [
     'Mon',
     { h => [0], m => [0], dow => [1] },
     [
      [0, 4*86400], # Note: Epoch 0 is Thursday, 1. January 1970
      [4*86400, 11*86400],
      [11*86400, 18*86400],
     ],
    ],
    [
     'sat..sun',
     { h => [0], m => [0], dow => [0, 6] },
     [
      [0, 2*86400],
      [2*86400, 3*86400],
      [3*86400, 9*86400],
     ]
    ],
    [
     'sun..sat',
     { h => [0], m => [0], dow => $alldays },
    ],
    [
     'Fri..Mon',
     { error => "wrong order in range 'Fri..Mon'" },
    ],
    [
     'wed,mon..tue,fri',
     { h => [0], m => [0], dow => [ 1, 2, 3, 5] },
    ],
    [
     'mon */15',
     { h => '*', m =>  [0, 15, 30, 45], dow => [1]},
    ],
    [
    '22/1:0',
     { h => [22, 23], m => [0], dow => $alldays },
     [
	[0, 22*60*60],
	[22*60*60, 23*60*60],
	[22*60*60 + 59*60, 23*60*60]
     ],
    ],
    [
     '*/2:*',
     { h => [0,2,4,6,8,10,12,14,16,18,20,22], m => '*', dow => $alldays },
     [
	[0, 60],
	[60*60, 2*60*60],
	[2*60*60, 2*60*60 + 60]
     ]
    ],
    [
     '20..22:*/30',
     { h => [20,21,22], m => [0,30], dow => $alldays },
     [
	[0, 20*60*60],
	[20*60*60, 20*60*60 + 30*60],
	[22*60*60 + 30*60, 44*60*60]
     ]
    ],
    [
     '61',
     { error => "value '61' out of range" },
    ],
    [
     '*/61',
     { error => "repetition '61' out of range" },
    ],
    [
     '0..80',
     { error => "range end '80' out of range" },
    ],
    [
     ' mon 0 0 0',
     { error => "unable to parse calendar event - unused parts" },
    ],
    [
     '',
     { error => "unable to parse calendar event - event is empty" },
    ],
    [
     ' mon 0 0',
     { error => "unable to parse calendar event - unused parts" },
    ],
    [
     '0,1,3..5',
     { h => '*', m => [0,1,3,4,5], dow => $alldays },
     [
	[0, 60],
	[60, 3*60],
	[5*60, 60*60]
     ]
    ],
    [
     '2,4:0,1,3..5',
     { h => [2,4], m => [0,1,3,4,5], dow => $alldays },
     [
	[0, 2*60*60],
	[2*60*60 + 60, 2*60*60 + 3*60],
	[2*60*60 + 5*60, 4*60*60]
     ]
    ],
];

foreach my $test (@$tests) {
    my ($t, $expect, $nextsync) = @$test;

    my $timespec;
    eval { $timespec = PVE::CalendarEvent::parse_calendar_event($t); };
    my $err = $@;
    delete $timespec->{utc};

    if ($expect->{error}) {
	chomp $err if $err;
	$timespec = { error => $err } if $err;
	is_deeply($timespec, $expect, "expect parse error on '$t' - $expect->{error}");
	die "unable to execute nextsync tests" if $nextsync;
    } else {
	is_deeply($timespec, $expect, "parse '$t'");
    }

    next if !$nextsync;

    foreach my $nt (@$nextsync) {
	my ($last, $expect_next) = @$nt;
	my $msg = "next event '$t' $last => ${expect_next}";
	$timespec->{utc} = 1;
	my $next = PVE::CalendarEvent::compute_next_event($timespec, $last);
	is($next, $expect_next, $msg);
    }
};

sub tztest {
    my ($calspec, $last) = @_;
    my $spec = PVE::CalendarEvent::parse_calendar_event($calspec);
    return PVE::CalendarEvent::compute_next_event($spec, $last);
}

# Test loop termination at CEST/CET switch (cannot happen here in UTC)
is(tztest('mon..fri', timelocal(0, 0, 0, 28, 9, 2018)),
                      timelocal(0, 0, 0, 29, 9, 2018));
is(tztest('mon..fri UTC', timelocal(0, 0, 0, 28, 9, 2018)),
                          timelocal(0, 0, 0, 29, 9, 2018));

# Now in the affected time zone
$ENV{TZ} = ':Europe/Vienna';
POSIX::tzset();
is(tztest('mon..fri', timelocal(0, 0, 0, 28, 9, 2018)),
                      timelocal(0, 0, 0, 29, 9, 2018));
# Specifically requesting UTC in the calendar spec means the resulting output
# time as seen locally (timelocal() as opposed to timegm()) is shifted by 1
# hour.
is(tztest('mon..fri UTC', timelocal(0, 0, 0, 28, 9, 2018)),
                          timelocal(0, 0, 1, 29, 9, 2018));
$ENV{TZ} = 'UTC';
POSIX::tzset();

done_testing();
