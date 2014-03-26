package Treex::Block::HamleDT::SL::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

#------------------------------------------------------------------------------
# Reads the Slovene tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    ###!!! DZ: Do we still need this when HamleDT::HarmonizePDT assigns AuxK from scratch?
    $self->change_ending_colon_to_AuxK($root);
    $self->change_wrong_puctuation_root($root);
    $self->change_quotation_predicate_into_obj($root);
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $afun   = $deprel;

        # combined afuns (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr)
        if ( $afun =~ m/^((Atr)|(Adv)|(Obj))((Atr)|(Adv)|(Obj))/ )
        {
            $afun = 'Atr';
        }

        $node->set_afun($afun);

        # Unlike the CoNLL conversion of the Czech PDT 2.0, the Slovenes don't mark coordination members.
        # I suspect (but I am not sure) that they always attach coordination modifiers to a member,
        # so there are no shared modifiers and all children of Coord are members. Let's start with this hypothesis.
        # We cannot query parent's afun because it may not have been copied from conll_deprel yet.
        my $pdeprel = $node->parent()->conll_deprel();
        $pdeprel = '' if ( !defined($pdeprel) );
        if ($pdeprel =~ m/^(Coord|Apos)$/
            &&
            $afun !~ m/^(Aux[GKXY])$/
            )
        {
            $node->set_is_member(1);
        }
    }
}

#------------------------------------------------------------------------------
# For some reason, punctuation right before coordinations are not dependent
# on the conjunction, but on the very root of the tree. I will make sure they
# are dependent correctly on the following word, which is the conjunction.
#------------------------------------------------------------------------------
sub change_wrong_puctuation_root
{
	my $self = shift;
	my $root = shift;
	my @children = $root->get_children();
	if (scalar @children>2)
    {
		#I am not taking the last one
		for my $child (@children[0..$#children-1])
        {
			if ($child->afun() =~ /^Aux[XG]$/)
            {
				my $conjunction = $child->get_next_node();
				if (scalar ($child->get_children())==0 and $conjunction->tag() =~ /^J/)
                {
					$child->set_parent($conjunction);
				}
			}
		}
	}
}

#------------------------------------------------------------------------------
# Quotations should have Obj as predicate, but here, they have Adj. I have to
# switch them.
#------------------------------------------------------------------------------
sub change_quotation_predicate_into_obj
{
	my $self = shift;
	my $root = shift;
	my @nodes = $root->get_descendants();
	for my $node (@nodes)
    {
		my @children = $node->get_children();
		my $has_quotation_dependent = 0;
		for my $child (@children)
        {
			if ($child->form eq q{"})
            {
				if ($node->afun() eq "Adv")
                {
					$node->set_afun("Obj");
				}
			}
		}
	}
}



1;

=over

=item Treex::Block::HamleDT::SL::Harmonize

Converts SDT (Slovene Dependency Treebank) trees from CoNLL to the style of
HamleDT (Prague). The structure of the trees should already
adhere to the PDT guidelines because SDT has been modeled after PDT. Some
minor adjustments to the analytical functions may be needed while porting
them from the conll/deprel attribute to afun. Morphological tags will be
decoded into Interset and converted to the 15-character positional tags
of PDT.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2012 Karel Bilek <kb@karelbilek.com>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
