package Treex::Block::Filter::CzEng::DecisionTree;
use Moose;
use Storable;
use Treex::Core::Common;
use AI::DecisionTree;
with 'Treex::Block::Filter::CzEng::Classifier';

my $dtree;

sub init
{
    $dtree = Algorithm::DecisionTree->new();
}

sub see
{
    $dtree->add_instance( attributes => %{ _create_hash($_[0]) }, result => $_[1] );
}

sub learn
{
    $dtree->train();
}

sub predict
{
    return $dtree->get_result( attributes => %{ _create_hash($_[0]) } );
}

sub load
{
    $dtree = retrieve($_[0]) or log_fatal "Unable to load file $_[0]";
}

sub save
{
    $dtree->do_purge();
    store($dtree, $_[0]);
}

sub _create_hash
{
    my @array = @{ $_[0] };
    my %hash = map { split '=', $_ } @array;
    return \%hash;
}

1;

=over

=item Treex::Block::Filter::CzEng::DecisionTree

Implementation of 'Classifier' role for naive Bayes model.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
