package Treex::Core::Log;
use strict;
use warnings;

use utf8;
use English '-no_match_vars';

use Carp qw(cluck);

use IO::Handle;
use Readonly;

use Exporter;
use base 'Exporter';
our @EXPORT = qw(log_fatal log_warn log_info log_memory log_debug); ## no critic (ProhibitAutomaticExportation)


$Carp::CarpLevel = 1;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

# Autoflush after every Perl statement should enforce that INFO and FATALs are ordered correctly.
{

    #my $oldfh = select(STDERR);
    #$| = 1;
    #select($oldfh);
    *STDERR->autoflush();
}

Readonly my %ERROR_LEVEL_VALUE => (
    'ALL'   => 0,
    'DEBUG' => 1,
    'INFO'  => 2,
    'WARN'  => 3,
    'FATAL' => 4,
);

use Moose::Util::TypeConstraints;
enum 'ErrorLevel' => keys %ERROR_LEVEL_VALUE;

# how many characters of a string-eval are to be shown in the output
$Carp::MaxEvalLen = 100;

my $unfinished_line;

# By default report only messages with INFO or higher level
my $current_error_level_value = $ERROR_LEVEL_VALUE{'INFO'};

# allows to surpress messages with lower than given importance
sub set_error_level {
    my $new_error_level = uc(shift);
    if ( not defined $ERROR_LEVEL_VALUE{$new_error_level} ) {
        log_fatal("Unacceptable errorlevel: $new_error_level");
    }
    $current_error_level_value = $ERROR_LEVEL_VALUE{$new_error_level};
    return;
}

sub get_error_level {
    return $current_error_level_value;
}

# fatal error messages can't be surpressed
sub log_fatal {
    my $message = shift;
    if ($unfinished_line) {
        print STDERR "\n";
        $unfinished_line = 0;
    }
    my $line = "TREEX-FATAL:\t$message\n\n";
    if ($OS_ERROR) {
        $line .= "PERL ERROR MESSAGE: $OS_ERROR\n";
    }
    if ($EVAL_ERROR) {
        $line .= "PERL EVAL ERROR MESSAGE: $EVAL_ERROR\n";
    }
    $line .= "PERL STACK:";
    cluck $line;
    run_hooks('FATAL');
    die "\n";
}

sub short_fatal {    # !!! neodladene
    my $message = shift;
    if ($unfinished_line) {
        print STDERR "\n";
        $unfinished_line = 0;
    }
    my $line = "TREEX-FATAL(short):\t$message\n";
    print STDERR $line;
    run_hooks('FATAL');
    exit;

}

# TODO: redesign API - $carp, $no_print_stack

sub log_warn {
    my ( $message, $carp ) = @_;
    if ( $current_error_level_value <= $ERROR_LEVEL_VALUE{'WARN'} ) {
        my $line = "";
        if ($unfinished_line) {
            $line            = "\n";
            $unfinished_line = 0;
        }
        $line .= "TREEX-WARN:\t$message\n";

        if ($carp) {
            Carp::carp $line;
        }
        else {
            print STDERR $line;
        }
    }
    run_hooks('WARN');
    return;
}

sub log_debug {
    my ( $message, $no_print_stack ) = @_;
    if ( $current_error_level_value <= $ERROR_LEVEL_VALUE{'DEBUG'} ) {
        my $line = "";
        if ($unfinished_line) {
            $line            = "\n";
            $unfinished_line = 0;
        }
        $line .= "TREEX-DEBUG:\t$message\n";

        if ($no_print_stack) {
            print STDERR $line;
        }
        else {
            Carp::cluck $line;
        }
    }
    run_hooks('DEBUG');
    return;
}

sub data {
    my $message = shift;
    if ( $current_error_level_value <= $ERROR_LEVEL_VALUE{'INFO'} ) {
        my $line = "";
        if ($unfinished_line) {
            $line            = "\n";
            $unfinished_line = 0;
        }
        $line .= "TREEX-DATA:\t$message\n";
        print STDERR $line;
    }
    run_hooks('DATA');
    return;
}

sub log_info {
    my ( $message, $arg_ref ) = @_;
    if ( $current_error_level_value <= $ERROR_LEVEL_VALUE{'INFO'} ) {
        my $same_line = defined $arg_ref && $arg_ref->{same_line};
        my $line = "";
        if ( $unfinished_line && !$same_line ) {
            $line            = "\n";
            $unfinished_line = 0;
        }
        if ( !$same_line || !$unfinished_line ) {
            $line .= "TREEX-INFO:\t";
        }
        $line .= $message;

        if ($same_line) {
            $unfinished_line = 1;
        }
        else {
            $line .= "\n";
        }

        print STDERR $line;
        if ($same_line) {
            STDERR->flush;
        }
    }
    run_hooks('INFO');
    return;
}

sub progress {    # progress se pres ntred neposila, protoze by se stejne neflushoval
    return if $current_error_level_value > $ERROR_LEVEL_VALUE{'INFO'};
    if ( not $unfinished_line ) {
        print STDERR "TREEX-PROGRESS:\t";
    }
    print STDERR "*";
    STDERR->flush;
    $unfinished_line = 1;
    return;
}


# ---------- HOOKS -----------------

my %hooks;    # subroutines can be associated with reported events

sub add_hook {
    my ( $level, $subroutine ) = @_;
    $hooks{$level} ||= [];
    push @{ $hooks{$level} }, $subroutine;
    return;
}

sub run_hooks {
    my ($level) = @_;
    foreach my $subroutine ( @{ $hooks{$level} } ) {
        &$subroutine;
    }
    return;
}

1;

__END__


=head1 NAME

Treex::Core::Log - logger tailored for the needs of Treex

=head1 SYNOPSIS

 use Treex::Core::Log;
 
 Treex::Core::Log::set_error_level('DEBUG');
 
 sub epilog {
     print STDERR "I'm going to cease!";
 }
 Treex::Core::Log::add_hook('FATAL',&epilog());
 
 sub test_value {
     my $value = shift;
     log_fatal "Negative values are unacceptable" if $ARGV < 0;
     log_warn "Zero value is suspicious" if $ARGV == 0;
     log_debug "test: value=$value";
 }



=head1 DESCRIPTION

Treex::Core::Log is a logger developed with the Treex system.
It uses more or less standard leveled set of reporting functions,
printing the messages at STDERR.


Note that this module might be completely substituted
by more elaborate solutions such as Log::Log4perl in the
whole Treex in the future


=head2 Error levels


Specifying error level can be used for surpressing
reports with lower severity. This module supports four
ordered levels of report severity (plus a special value
comprising them all).

=over 4

=item FATAL

=item WARN

=item INFO - the default value

=item DEBUG

=item ALL

=back

The current error level can be accessed by the following functions:

=over 4

=item set_error_level($error_level)

=item get_error_level()

=back



=head2 Reporting functions

All the following reporting functions print the message at STDERR.
All are exported by default.

=over 4

=item log_fatal($message)

print the Perl stack too, and exit

=item log_warn($message)

=item log_info($message)

=item log_debug($message)

=back



=head2 Hooks

Another functions can be called prior to reporting events.

=over 4

=item add_hook($level, &hook_subroutine)

add the subroutine to the list of subroutines called prior
to reporting events with the given level

=item run_hooks($level)

run all subroutines for the given error level

=back



=head1 AUTHOR

Zdenek Zabokrtsky
