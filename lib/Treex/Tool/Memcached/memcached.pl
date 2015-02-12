#!/usr/bin/env perl
use strict;
use warnings;

use Treex::Core::Common;
use Treex::Core::Resource;
use Treex::Tool::Memcached::Memcached;

my $action = shift @ARGV;

print STDERR "Action: $action\n";

if ( $action eq "start" ) {
    Treex::Tool::Memcached::Memcached::start_memcached(@ARGV);
}
elsif ( $action eq "load" ) {
    Treex::Tool::Memcached::Memcached::load_model(@ARGV);
}
elsif ( $action eq "process" ) {
    process(@ARGV);
}
elsif ( $action eq "missing" ) {
    missing(@ARGV);
}
elsif ( $action eq "stats" ) {
    Treex::Tool::Memcached::Memcached::print_stats();
}
elsif ( $action eq "stop" ) {
    Treex::Tool::Memcached::Memcached::stop_memcached();
}
elsif ( $action eq "check" ){
    Treex::Tool::Memcached::Memcached::contains(@ARGV);
}
elsif ( $action eq "hostname" ){
    my $hostname = Treex::Tool::Memcached::Memcached::get_memcached_hostname();
    if ($hostname) {
        print "$hostname\n";
        exit 0;
    } else {
        exit 1;
    }
}
else {
    help();
}

sub process
{
    my ($file) = @_;

    if ( !Treex::Tool::Memcached::Memcached::get_memcached_hostname() ) {
        log_fatal "Memcached is not running";
    }

    open( my $fh, "<", $file ) or log_fatal $! . " ($file)";
    while (<$fh>) {
        chomp;
        my ($package, $model_file) = split(/\t/);
        if ( Treex::Tool::Memcached::Memcached::is_supported_package($package) ) {
            my $required_file = Treex::Core::Resource::require_file_from_share( $model_file, 'Memcached' );
            my ($class, $constr_params) = Treex::Tool::Memcached::Memcached::get_class_from_filename($required_file);
            if ( ! $class ) {
                log_warn "Unknown model file for $model_file\n";
                next;
            }
            Treex::Tool::Memcached::Memcached::load_model( $class, $constr_params, $required_file );
        }
    }
    close($fh);

    return;
}

sub missing
{
    my ($file) = @_;

    if ( !Treex::Tool::Memcached::Memcached::get_memcached_hostname() ) {
        log_fatal "Memcached is not running";
    }

    open( my $fh, "<", $file ) or log_fatal $! . " ($file)";
    while (<$fh>) {
        chomp;
        my ($package, $model_file) = split(/\t/);
        if ( Treex::Tool::Memcached::Memcached::is_supported_package($package) ) {
            my $required_file = Treex::Core::Resource::require_file_from_share( $model_file, 'Memcached' );;
            if ( !Treex::Tool::Memcached::Memcached::contains($required_file) ) {
                print $required_file, "\n";
            }
        }
    }
    close($fh);

    return;
}

sub help
{
    print <<'DOC';
USAGE
./memcached.pl command [options]

./memcached.pl start memory
    Executes memcached with XGB of memory. If more memory will be required
    memcached will be terminated.
    If server is already running, nothing happens.
    ./memcached.pl start 10

./memcached.pl stop
    Terminates memcached.

./memcached.pl stats
    Prints usage statistics.

./memcached.pl load package file
    Loads model [file] to memcached.
    If file is already loaded, it does nothing.
    ./memcached.pl load \
        Treex::Tool::TranslationModel::ML::Model 'model_type maxent' \
        ...../tlemma_czeng12.maxent.10000.100.2_1.pls.gz

./memcached.pl process file
    Processes file generated by treex --dump_required_files.
    In current implementation loads only translation models.

./memcached.pl missing file
    Prints path of models from file generated by treex --dump_required_files
    which are not loaded.
    Loads only translation models in the current implementation.

./memcached.pl check file key
    Returns whether the given key has been loaded from the given file/namespace.

./memcached.pl hostname
    Returns the hostname if running. Returns nothing and exits with status 1 if not.

DOC

    return;
}
__END__

=encoding utf-8

=head1 NAME

memcached.pl

=head1 SYNOPSIS

    ./memcached.pl start memory-size-in-gb
    ./memcached.pl load model-class model-class-params data-file
    ./memcached.pl process required-files-scenario-dump
    ./memcached.pl missing data-file
    ./memcached.pl check data-file key
    ./memcached.pl stats
    ./memcached.pl stop
    ./memcached.pl hostname

=head1 DESCRIPTION

A command-line interface to the L<Treex::Tool::Memcached::Memcached> wrapper to L<Cache::Memcached>.
Running the script with no parameters prints a more detailed help.

=head1 AUTHORS

Martin Majliš <majlis@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
