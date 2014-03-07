package Treex::Block::SemevalABSA::Adverb;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_atree {
    my ( $self, $atree ) = @_;
    my @advs = grep { $_->afun =~ m/^Adv/ && $self->is_subjective( $_ ) } $atree->get_descendants;

    for my $adv (@advs) {
        my $pred = $self->find_predicate( $adv );
        next if ! $pred;
        my $polarity = $self->get_polarity( $adv );
        my @to_mark = grep { $_->afun =~ m/^Obj/ } $self->get_clause_descendants( $pred );
        if (! @to_mark) {
            @to_mark = grep { $_->afun =~ m/^Sb/ } $self->get_clause_descendants( $pred );
        }
        map { $self->mark_node( $_, "adv_" . $polarity ) } @to_mark;
    }

    return 1;
}

1;

# polaritu adverbia prevezme PAT, existuje-li, jinak ACT
