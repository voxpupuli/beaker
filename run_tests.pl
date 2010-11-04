#!/usr/bin/env perl

use strict;
use warnings;

use IPC::Run3 'run3';
use Time::HiRes qw( gettimeofday tv_interval );

my %report_test =
(
    # EXIT_OK
     0 => \&report_success,

    # EXIT_FAILURE
    10 => \&report_failure,

    # EXIT_NOT_APPLICABLE
    11 => \&report_not_applicable,
);

main(@ARGV);
exit;

sub main
{
    my @tests = find_tests();
    run_tests( @tests );
}

sub find_tests
{
    return grep { -x } <spec/*_spec.sh>;
}

sub run_tests
{
    for my $test (@_)
    {
        my $xml = run_one_test( $test );
        write_xml( $test, $xml );
    }
}

sub run_one_test
{
    my $test     = shift;
    my $cur_time = [ gettimeofday ];

    run3( "./$test", undef, \my $out, \my $err );
    my $time     = tv_interval( $cur_time );
    my $status   = $? >> 8;

    return $report_test{ $status }->( $test, $out, $err, $time )
        if exists $report_test{ $status };

    return report_unknown_status( $test, $out, $err, $time );
}

sub report_success
{
    return report_ok( @_ );
}

sub report_ok
{
    my ($test, $out, $err, $time, %args) = @_;

    my $xml = create_xml_header(
        name  => $test,
        time  => $time,
        %args
    );

    my $name = filename_to_test_name( $test );

    $xml .=<<"TESTCASE";
  <testcase name="$name" time="$time">
  </testcase>
TESTCASE
    $xml .= create_xml_footer( stdout => $out, stderr => $err );
    return $xml;
}

sub report_failure
{
    my ($test, $out, $err, $time) = @_;

    my $xml = create_xml_header(
        failures => 1,
        name     => $test,
        time     => $time
    );

    my $name = filename_to_test_name( $test );

    my ($first_line)   = $out =~ /^(.+)$/m;

    $xml .=<<"TESTCASE";
  <testcase name="$name" time="$time">
    <failure type="acceptanceFailure" message="$first_line">
    $out
    </failure>
  </testcase>
TESTCASE
    $xml .= create_xml_footer( stdout => $out, stderr => $err );
    return $xml;
}

sub report_not_applicable
{
    return report_ok( @_, skipped => 1 );
}

sub report_unknown_status
{
    return report_ok( @_, errors => 1 );
}

sub create_xml_header
{
    my %args = 
    (
        errors   => 0,
        failures => 0,
        name     => 'unknown',
        tests    => 1,
        skipped  => 0,
        time     => '0.00',
        @_;
    )

return <<"XML";
<?xml version="1.0" encoding="UTF-8"?>
<testsuite errors="$args{errors}" failures="$args{failures}" name="$args{name}" tests="$args{tests}" skipped="$args{skipped}" time="$args{time}">
XML
}

sub create_xml_footer
{
    my %args = @_;
return <<"XML";
  <system-out>
  $args{stdout}
  </system-out>
  <system-err>
  $args{stderr}
  </system-err>
</testsuite>
XML
}

sub write_xml
{
    my ($test, $xml) = @_;

    $test =~ s/spec/results/;
    $test =~ s/.sh/.xml/;

    open my $out, '>', $test or die "Cannot write '$test': $!\n";
    print {$out} $xml;
    close $out;
}

sub filename_to_test_name
{
    my $filename = shift;

    $filename =~ s/^spec.(\w+)_spec.sh$/$1/;
    $filename =~ tr/_/ /g;

    return $filename;
}
