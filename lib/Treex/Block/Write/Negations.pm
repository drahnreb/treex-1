package Treex::Block::Write::Negations;

use Moose;
use Treex::Core::Common;
use List::Uniq "uniq";
extends 'Treex::Block::Write::BaseTextWriter';

my %neg_tlemmas = (
    ne => 1,
    nikoli => 1,
    nikoliv => 1,
    '#Neg' => 1,
);

sub process_ttree {
    my ( $self, $troot ) = @_;
    
    print { $self->_file_handle } $troot->get_zone->sentence, "\n";

    my @neg_tnodes = grep {
        (defined $_->gram_negation && $_->gram_negation eq 'neg1')
        || defined $neg_tlemmas{$_->t_lemma}
    } $troot->get_descendants({ordered => 1});
    
    foreach my $neg_tnode (@neg_tnodes) {
        # TODO: now string, future structured
        my $info;
        my $cue;
        my $scope;
        
        my $neg_anode = $neg_tnode->get_lex_anode;
        if (defined $neg_tnode->gram_negation && $neg_tnode->gram_negation eq 'neg1') {
            # type A
            $cue = (substr $neg_anode->form, 0, 2) . "-";
            $scope = "-" . (substr $neg_anode->form, 2);
            $info = "[A on " . $neg_anode->ord . " " . $neg_anode->form . "]";
        } else {
            # type B or C
            # cue
            if ($neg_tnode->t_lemma eq '#Neg') {
                # TODO type C: have to find the negated verb
                $cue = "ne-";
                $info = "[C on SOME VERB";
            } else {
                $cue = $neg_tnode->get_lex_anode->form;
                $cue = $neg_anode->form;
                $info = "[B on " . $neg_anode->ord . " " . $neg_anode->form;
            }

            # scope
            my @right_parents = $neg_tnode->get_eparents({following_only => 1});
            my @right_sisters = $neg_tnode->get_siblings({following_only => 1});
            my @potential_scope_tnodes = (@right_parents, @right_sisters); # TODO undefs?
            @potential_scope_tnodes = sort {$a->ord <=> $b->ord} @potential_scope_tnodes;
            my $tfa = $potential_scope_tnodes[0]->tfa;
            # TFA
            my $tfa;
            if (@right_parents) {
                if (@right_sisters) {
                    if ($right_parents[0]->precedes($right_sisters[0])) {
                        # type 1
                        $tfa = $right_parents[0]->tfa;
                        $info .= " TYPE 1]";
                    } else {
                        # type 2
                        $tfa = $right_sisters[0]->tfa;
                        $info .= " TYPE 2]";
                    }
                } else {
                    # type 1
                    $tfa = $right_parents[0]->tfa;
                    $info .= " TYPE 1]";
                }
            } elsif (@right_sisters) {
                # type 2
                $tfa = $right_sisters[0]->tfa;
                $info .= " TYPE 2]";
            }
            # else type 3

            # SCOPE TNODES
            if (!defined $tfa) {
                # type 3
                $scope = $cue;
                $info .= " TYPE 3]";
            } else {
                my @scope_tnodes;
                if ($tfa eq 't') {
                    @scope_tnodes = grep {
                        defined $_->tfa
                        && ($_->tfa eq 't' || $_->tfa eq 'c')
                        } @potential_scope_tnodes;
                } else {
                    @scope_tnodes = grep {
                        defined $_->tfa
                        && ($_->tfa eq $tfa)
                        } @potential_scope_tnodes;
                }
                @scope_tnodes = map { $_->get_descendants({add_self=>1}) } @scope_tnodes;
                @scope_tnodes = sort {$a->ord <=> $b->ord} @scope_tnodes;


            }
        }

#        my $right_sister = $neg_tnode->get_next_node();
#        if (defined $right_sister && defined $right_sister->tfa) {
#                # type 1 or 2
#                my @scope_tnodes;
#                if ($right_sister->tfa eq 'f') {
#                    while (defined $right_sister && defined $right_sister->tfa && $right_sister->tfa eq 'f') {
#                        # TODO add only children (but with subtrees)?
#                        push @scope_tnodes, $right_sister->get_descendants({add_self=>1});
#                        $right_sister = $right_sister->get_next_node();
#                    }
#                } elsif ($right_sister->tfa eq 'c') {
#                    # TODO add only children (but with subtrees)?
#                    push @scope_tnodes, $right_sister->get_descendants({add_self=>1});
#                } elsif ($right_sister->tfa eq 't') {
#                    my %ft = ( f => 1, t => 1 );
#                    while (defined $right_sister && defined $right_sister->tfa && defined $ft{$right_sister->tfa}) {
#                        # TODO add only children (but with subtrees)?
#                        push @scope_tnodes, $right_sister->get_descendants({add_self=>1});
#                        $right_sister = $right_sister->get_next_node();
#                    }
#                } else {
#                    log_warn $neg_tnode->id . ": right sister is missing TFA!";
#                    @scope_tnodes = $right_sister;
#                }
#
#                # TODO scope may be discontiguous, is that OK?
#
#                $scope = join ' ',
#                    map { $_->form  }
#                    sort {$a->ord <=> $b->ord}
#                    map {$_->get_anodes}
#                    uniq
#                    @scope_tnodes;
#                $info .= " TYPE 1/2]";
#            }
        }

        print { $self->_file_handle } $info, " CUE: ", $cue, "  SCOPE: ", $scope, "\n";
    }

    print { $self->_file_handle } "\n";

    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::Write::Negations

=head1 DESCRIPTION

Prints out sentences together with their negation cues and their scopes.

TODO: it seems punctuation does not have TFA, but add it anyway?

TODO: ensure only subordinates are added into the scope, i.e. not a superordinate clause as in:
Pokud se nad svým přesyceným systémem organizování a hodnocení vědy včas vážně nezamyslíme, může se stát, že toho k hodnocení bude stále méně a méně. 
[C on SOME VERB TYPE 1/2] CUE: ne-  SCOPE: Pokud se nad svým přesyceným systémem organizování a hodnocení vědy včas vážně nezamyslíme může se stát že toho k hodnocení bude stále méně a méně


=head1 AUTHOR

Rudolf Rosa

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
