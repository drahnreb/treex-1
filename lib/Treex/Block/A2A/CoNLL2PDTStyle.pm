package Treex::Block::A2A::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';
use tagset::common;
use tagset::cs::pdt;

#------------------------------------------------------------------------------
# Reads the a-tree, converts the original morphosyntactic tags to the PDT
# tagset, converts dependency relation tags to afuns and transforms the tree to
# adhere to the PDT guidelines. This method must be overriden in the subclasses
# that know about the differences between the style of their treebank and that
# of PDT. However, here is a sample of what to do. (Actually it's not just a
# sample. You can call it from the overriding method as
# $a_root = $self->SUPER::process_zone($zone);. Call this first and then do
# your specific stuff.)
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $tagset = shift;    # optional argument from the subclass->process_zone()
                           # Copy the original dependency structure before adjusting it.
    $self->backup_zone($zone);
    my $a_root = $zone->get_atree();

    # Convert CoNLL POS tags and features to Interset and PDT if possible.
    $self->convert_tags( $a_root, $tagset );

    # Conversion from dependency relation tags to afuns (analytical function tags) must be done always
    # and it is almost always treebank-specific (only a few treebanks use the same tagset as the PDT).
    $self->deprel_to_afun($a_root);

    # Adjust the tree structure. Some of the methods are general, some will be treebank-specific.
    # The decision whether to apply a method at all is always treebank-specific.
    #$self->attach_final_punctuation_to_root($a_root);
    #$self->process_auxiliary_particles($a_root);
    #$self->process_auxiliary_verbs($a_root);
    #$self->restructure_coordination($a_root);
    #$self->mark_deficient_clausal_coordination($a_root);
    #$self->check_afuns($a_root);
    # The return value can be used by the overriding methods of subclasses.
    return $a_root;
}

#------------------------------------------------------------------------------
# Copies the original zone so that the user can compare the original and the
# restructured tree in TTred.
#------------------------------------------------------------------------------
sub backup_zone
{
    my $self  = shift;
    my $zone0 = shift;
    return $zone0->copy('orig');
}

#------------------------------------------------------------------------------
# Converts tags of all nodes to Interset and PDT tagset.
#------------------------------------------------------------------------------
sub convert_tags
{
    my $self   = shift;
    my $root   = shift;
    my $tagset = shift;    # optional, see below
    foreach my $node ( $root->get_descendants() )
    {
        $self->convert_tag( $node, $tagset );
    }
}

#------------------------------------------------------------------------------
# Decodes the part-of-speech tag and features from a CoNLL treebank into
# Interset features. Stores the features with the node. Then sets the tag
# attribute to the closest match in the PDT tagset.
#------------------------------------------------------------------------------
sub convert_tag
{
    my $self   = shift;
    my $node   = shift;
    my $tagset = shift;    # optional tagset identifier (default = 'conll'; sometimes we need 'conll2007' etc.)
    $tagset = 'conll' unless ($tagset);

    # Note that the following hack will not work for all treebanks.
    # Some of them use tagsets not called '*::conll'.
    # Many others are not covered by DZ Interset yet.
    # tagset::common::find_drivers() could help but it would not be efficient to call it every time.
    # Instead, every subclass of this block must know whether to call convert_tag() or not.
    # List of CoNLL tagsets covered by 2011-07-05:
    my @known_drivers = qw(
        ar::conll ar::conll2007 bg::conll cs::conll cs::conll2009 da::conll de::conll de::conll2009
        en::conll en::conll2009
        es::conll2009 tr::conll
        hu::conll eu::conll  ta::tamiltb
        it::conll nl::conll pt::conll sv::conll zh::conll grc::conll
        ja::conll hi::conll te::conll bn::conll el::conll ru::syntagrus sl::conll
        ro::rdt);
    my $driver = $node->get_zone()->language() . '::' . $tagset;
    if ( !grep { $_ eq $driver } (@known_drivers) )
    {
        log_warn("Interset driver $driver not found");
        return;
	}
    # Current tag is probably just a copy of conll_pos.
    # We are about to replace it by a 15-character string fitting the PDT tagset.
    my $tag        = $node->tag();
    my $conll_cpos = $node->conll_cpos();
    my $conll_pos  = $node->conll_pos();
    my $conll_feat = $node->conll_feat();
    my $src_tag = $tagset eq 'conll2009' ? "$conll_pos\t$conll_feat" : $tagset =~ m/^(conll|tamiltb)/ ? "$conll_cpos\t$conll_pos\t$conll_feat" : $tag;
    my $f = tagset::common::decode($driver, $src_tag);
    my $pdt_tag = tagset::cs::pdt::encode($f, 1);
    $node->set_iset($f);
    $node->set_tag($pdt_tag);
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# This abstract class does not understand the source-dependent CoNLL deprels,
# so it only copies them to afuns. The method must be overriden in order to
# produce valid afuns.
#
# List and description of analytical functions in PDT 2.0:
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#
# We define the following pseudo-afuns that are not defined in PDT but are
# useful for the different structures of some treebanks. Note that these
# pseudo-afuns are expected in some methods.
#   PrepArg ... argument of a preposition (typically a noun)
#   SubArg .... argument of a subordinator (typically a verb)
#   NumArg .... argument of a number (counted noun)
#   DetArg .... argument of a determiner (typically a noun)
#   PossArg ... argument of a possessive (possessed noun)
#   AdjArg .... argument of an adjective (modified noun)
#   CoordArg .. coordination member (probably not
#               the first one, in treebanks with different coordinations)
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        $node->set_afun($deprel);
    }
}

#------------------------------------------------------------------------------
# After all transformations all nodes must have valid afuns (not our pseudo-
# afuns). Report cases breaching this rule so that we can easily find them in
# Ttred.
#------------------------------------------------------------------------------
sub check_afuns
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        if ( $afun !~ m/^(Pred|Sb|Obj|Pnom|Adv|Atr|Atv|AtvV|ExD|Coord|Apos|AuxA|AuxP|AuxC|AuxV|AuxT|AuxO|AuxY|AuxX|AuxZ|AuxG|AuxK)$/ )
        {
            $self->log_sentence($root);
            my $ord    = $node->ord();
            my $form   = $node->form();
            my $tag    = $node->tag();
            my $deprel = $node->conll_deprel();

            # This cannot be fatal if we want the trees to be saved and examined in Ttred.
            if ($afun)
            {
                log_warn("Node $ord:$form/$tag/$deprel still has the pseudo-afun $afun.");

                # Erase the pseudo-afun to avoid further complaints of Treex and Tred.
                log_info("Removing the pseudo-afun...");
                $node->set_afun('');
            }
            else
            {
                log_warn("Node $ord:$form/$tag/$deprel still has no afun.");
            }
        }
    }
}

#------------------------------------------------------------------------------
# Shifts afun from preposition to its argument and gives the preposition new
# afun 'AuxP'. Useful for treebanks where prepositions bear the deprel of the
# whole prepositional phrase. The subclass should not call this method before
# it assigns afuns or pseudo-afuns to all nodes. Arguments of prepositions must
# have the pseudo-afun 'PrepArg'.
#
# Call from the end of deprel_to_afun() like this:
# $self->process_prep_sub_arg($root);
#
# Tells the parent node whether the child node wants to take the parent's afun
# and return 'AuxP' or 'AuxC' instead. Called recursively. In some treebanks
# there may be chains of both AuxP and AuxC such as in this Danish example:
# parate/AA/pred til/RR/pobj at/TT/nobj gå/Vf/vobj => parate/AA/Pnom til/RR/AuxP at/TT/AuxC gå/Vf/Atr
#------------------------------------------------------------------------------
sub process_prep_sub_arg
{
    my $self                = shift;
    my $node                = shift;
    my $parent_current_afun = shift;
    my $parent_new_afun     = $parent_current_afun;
    my $current_afun        = $node->afun();

    # If I am currently a prep/sub argument, let's steal the parent's afun.
    if ( $current_afun eq 'PrepArg' )
    {
        $current_afun    = $parent_current_afun;
        $parent_new_afun = 'AuxP';
    }
    elsif ( $current_afun eq 'SubArg' )
    {
        $current_afun    = $parent_current_afun;
        $parent_new_afun = 'AuxC';
    }

    # Now let's see whether my children want my afun.
    my $new_afun = $current_afun;
    my @children = $node->children();
    foreach my $child (@children)
    {

        # Ask a child if it wants my afun and what afun it thinks I should get.
        # A preposition can have more than one child and some of the children may not be PrepArgs.
        # So only set $new_afun if it really differs from $current_afun (otherwise the first child could propose a change and the second could revert it).
        ###!!! We should check whether several children claim to be prep/sub arguments. Normally it should not happen.
        my $suggested_afun = $self->process_prep_sub_arg( $child, $current_afun );
        $new_afun = $suggested_afun unless ( $suggested_afun eq $current_afun );
    }
    ###!!! DEBUG
    if ( 0 && $node->get_bundle()->get_position() + 1 == 64 )
    {
        my $message;
        if ( $new_afun ne $node->afun() )
        {
            $message = sprintf( "%d:%s changing afun from %s to $new_afun", $node->ord(), $node->form(), $node->afun() );
        }
        else
        {
            $message = sprintf( "%d:%s keeping afun $current_afun", $node->ord(), $node->form() );
        }
        log_info($message);
    }
    ###!!! END OF DEBUG
    # Set the afun my children selected (it is either my current afun or 'AuxP' or 'AuxC').
    $node->set_afun($new_afun);

    # Let the parent know what I selected for him.
    return $parent_new_afun;
}

#------------------------------------------------------------------------------
# Returns the noun phrase attached directly to the preposition in a
# prepositional phrase. It is difficult to detect without understanding the
# treebank-specific dependency relation tags because the preposition may have
# more than one child (coordination members if the preposition governed
# a coordination; modifiers (intensifiers) of the whole PP if the guidelines
# rule to attach them to the preposition) and the main child need not be
# necessarily a noun (it could be an adjective, a numeral etc.)
#------------------------------------------------------------------------------
sub get_preposition_argument
{
    my $self     = shift;
    my $prepnode = shift;

    # The assumption is that the preposition governs the noun phrase and not vice versa.
    # If not, run the corresponding transformation prior to calling this method.
    # We cannot reliably assume that a preposition has only one child.
    # There may be rhematizers modifying the whole prepositional phrase.
    # We assume that the real argument of the preposition can only have one of selected parts of speech and afuns.
    # (Note that PrepArg is a pseudo-afun that is not defined in PDT but subclasses can use it to explicitly mark preposition arguments
    # whenever no other suitable afun is readily available.)
    my @prepchildren = grep { $_->afun() eq 'PrepArg' } ( $prepnode->children() );
    if (@prepchildren)
    {
        if ( scalar(@prepchildren) > 1 )
        {
            $self->log_sentence($prepnode);
            log_info( "Preposition " . $prepnode->ord() . ":" . $prepnode->form() );
            log_warn("More than one preposition argument.");
        }
        return $prepchildren[0];
    }
    else
    {
        @prepchildren = grep { $_->get_iset('pos') =~ m/^(noun|adj|num)$/ } ( $prepnode->children() );
        if (@prepchildren)
        {
            if ( scalar(@prepchildren) > 1 )
            {
                $self->log_sentence($prepnode);
                log_info( "Preposition " . $prepnode->ord() . ":" . $prepnode->form() );
                log_warn("More than one preposition argument.");
            }
            return $prepchildren[0];
        }
        else
        {
            @prepchildren = grep { $_->afun() =~ m/^(Sb|Obj|Pnom|Adv|Atv|Atr)$/ } ( $prepnode->children() );
            if (@prepchildren)
            {
                if ( scalar(@prepchildren) > 1 )
                {
                    $self->log_sentence($prepnode);
                    log_info( "Preposition " . $prepnode->ord() . ":" . $prepnode->form() );
                    log_warn("More than one preposition argument.");
                }
                return $prepchildren[0];
            }
        }
    }
    return undef;
}

#------------------------------------------------------------------------------
# Returns the clause attached directly to the subordinating conjunction. It is
# difficult to detect without understanding the treebank-specific dependency
# relation tags because the conjunction may have more than one child
# (coordination members if the conjunction governed a coordination).
#------------------------------------------------------------------------------
sub get_subordinator_argument
{
    my $self        = shift;
    my $subnode     = shift;
    my @subchildren = grep { $_->afun() eq 'SubArg' } ( $subnode->children() );
    if (@subchildren)
    {
        if ( scalar(@subchildren) > 1 )
        {
            $self->log_sentence($subnode);
            log_info( "Subordinator " . $subnode->ord() . ":" . $subnode->form() );
            log_warn("More than one subordinator argument.");
        }
        return $subchildren[0];
    }
    else
    {
        @subchildren = grep { $_->get_iset('pos') =~ m/^(verb)$/ } ( $subnode->children() );
        if (@subchildren)
        {
            if ( scalar(@subchildren) > 1 )
            {
                $self->log_sentence($subnode);
                log_info( "Subordinator " . $subnode->ord() . ":" . $subnode->form() );
                log_warn("More than one subordinator argument.");
            }
            return $subchildren[0];
        }
    }
    return undef;
}

#------------------------------------------------------------------------------
# Examines the last node of the sentence. If it is a punctuation, makes sure
# that it is attached to the artificial root node.
#------------------------------------------------------------------------------
sub attach_final_punctuation_to_root
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();

    # Exclude everything that looks like quotation marks and test the previous node instead.
    # PDT attaches final quote to the main verb and the previous full stop is attached nonprojectively to the root.
    my $fnode;
    for ( my $i = $#nodes; $i > 0; $i-- )
    {
        $fnode = $nodes[$i];

        # Consider previous node if this is a quotation mark. Consider this node otherwise.
        # Note: The quotation mark should be attached to the main verb but we do not care about it here.
        last unless ( $fnode->form() =~ m/[`'"\x{2018}-\x{201F}]/ );
    }

    # If the sentence contained only the artificial root, $fnode is not defined but we have no work anyway.
    return if ( !defined($fnode) );

    # Exclude some symbols.
    # For example, DDT contained a tree where the last token was '=', s-tagged as coordinator (with missing CoordArg).
    # Attaching such thing to the root prior to restructuring coordinations would make the root a coordination member!
    if ( $fnode->get_iset('pos') eq 'punc' && $fnode->form() !~ m/^(=)$/ )
    {

        # If the last token is a quotation mark and there is another punctuation before it (typically [.?!])
        # then the quotation mark is attached non-projectively to its predicate and the other punctuation is AuxK.
        if ( $#nodes > 1 && $nodes[ $#nodes - 1 ]->get_iset('pos') eq 'punc' && $fnode->form() eq '"' )
        {
            $fnode = $nodes[ $#nodes - 1 ];
        }
        $fnode->set_parent($root);
        $fnode->set_afun('AuxK');
    }
}

#------------------------------------------------------------------------------
# Restructures coordinations to the Prague style.
# Calls a treebank-specific method detect_coordination() that fills a list of
# arrays, each containing a hash with the following keys:
# - members: list of nodes that are members of coordination
# - delimiters: list of nodes with commas or conjunctions between the members
# - shared_modifiers: list of nodes that depend on the whole coordination
# - parent: the node the coordination modifies
# - afun: the analytical function of the whole coordination wrt. its parent
#------------------------------------------------------------------------------
sub restructure_coordination
{
    my $self  = shift;
    my $root  = shift;
    my $debug = 0;

    #my $debug = $self->sentence_contains($root, 'Spürst du das');
    log_info('DEBUG ON') if ($debug);

    # Switch between approaches to solving coordination.
    # The former reshapes coordination immediately upon finding it.
    # The latter and older approach first collects all coord structures then reshapes them.
    # It could theoretically suffer from things changing during reshaping.
    if (1)
    {
        $self->shape_coordination_recursively( $root, $debug );
    }
    else
    {
        my @coords;

        # Collect information about all coordination structures in the tree.
        $self->detect_coordination( $root, \@coords );

        # Loop over coordinations and restructure them.
        # Hopefully the order in which the coordinations are processed is not significant.
        foreach my $c (@coords)
        {
            $self->shape_coordination( $c, $debug );
        }
    }
}

#------------------------------------------------------------------------------
# A different approach: recursively search for coordinations and solve them
# immediately, i.e. don't collect all first.
#------------------------------------------------------------------------------
sub shape_coordination_recursively
{
    my $self  = shift;
    my $root  = shift;
    my $debug = shift;

    # Is the current subtree root a coordination root?
    # Look for coordination members.
    my @members;
    my @delimiters;
    my @sharedmod;
    my @privatemod;
    my %coord =
        (
        'members'           => \@members,
        'delimiters'        => \@delimiters,
        'shared_modifiers'  => \@sharedmod,
        'private_modifiers' => \@privatemod,    # for debugging purposes only
        'oldroot'           => $root
        );
    $self->collect_coordination_members( $root, \@members, \@delimiters, \@sharedmod, \@privatemod, $debug );
    if (@members)
    {
        log_info('COORDINATION FOUND') if ($debug);

        # We have found coordination! Solve it right away.
        $self->shape_coordination( \%coord, $debug );

        # Call recursively on all modifier subtrees.
        # Do not call it on all children because they include members and delimiters.
        # Non-first members cannot head nested coordination under this approach.
        ###!!! TO DO: Make this function independent on coord approach taken in the current treebank!
        ###!!! Possible solution: collect_coordination_members() also returns the list of nodes for recursive search.
        # All CoordArg children they may have are considered members of the current coordination.
        foreach my $node ( @sharedmod, @privatemod )
        {
            $self->shape_coordination_recursively( $node, $debug );
        }
    }

    # Call recursively on all children if no coordination detected now.
    else
    {
        foreach my $child ( $root->children() )
        {
            $self->shape_coordination_recursively( $child, $debug );
        }
    }
}

#------------------------------------------------------------------------------
# Restructures one coordination structure to the Prague style.
# Takes a description of the structure as a hash with the following keys:
# - members: list of nodes that are members of coordination
# - delimiters: list of nodes with commas or conjunctions between the members
# - shared_modifiers: list of nodes that depend on the whole coordination
# - private_modifiers: list of nodes that depend on individual members
#     for debugging purposes only
# - oldroot: the original root node of the coordination (e.g. the first member)
#     parent and afun of the whole structure is taken from oldroot
#------------------------------------------------------------------------------
sub shape_coordination
{
    my $self  = shift;
    my $c     = shift;    # reference to hash
    my $debug = shift;
    $debug = 0 if ( !defined($debug) );
    if ( $debug >= 1 )
    {
        $self->log_sentence( $c->{oldroot} );
        log_info( "Coordination members:    " . join( ' ', map { $_->ord() . ':' . $_->form() } ( @{ $c->{members} } ) ) );
        log_info( "Coordination delimiters: " . join( ' ', map { $_->ord() . ':' . $_->form() } ( @{ $c->{delimiters} } ) ) );
        log_info( "Coordination modifiers:  " . join( ' ', map { $_->ord() . ':' . $_->form() } ( @{ $c->{shared_modifiers} } ) ) );
        if ( exists( $c->{private_modifiers} ) )
        {
            log_info( "Member modifiers:        " . join( ' ', map { $_->ord() . ':' . $_->form() } ( @{ $c->{private_modifiers} } ) ) );
        }
        log_info( "Old root:                " . $c->{oldroot}->ord() . ':' . $c->{oldroot}->form() );
    }
    elsif ( $debug > 0 )
    {
        my @cnodes = sort { $a->ord() <=> $b->ord() } ( @{ $c->{members} }, @{ $c->{delimiters} } );
        log_info( join( ' ', map { $_->ord() . ':' . $_->form() } (@cnodes) ) );
    }

    # Get the parent and afun of the whole coordination, from the old root of the coordination.
    # Note that these may have changed since the coordination was detected,
    # as a result of processing other coordinations, if this is a nested coordination.
    my $parent = $c->{oldroot}->parent();
    if ( !defined($parent) )
    {
        $self->log_sentence( $c->{oldroot} );
        log_fatal('Coordination has no parent.');
    }

    # Select the last delimiter as the new root.
    if ( !@{ $c->{delimiters} } )
    {

        # It can happen, however rare, that there are no delimiters between the coordinated nodes.
        # Example: de:
        #   `` Spürst du das ? '' , fragt er , `` spürst du den Knüppel ?
        # Here, both direct speeches are coordinated and together attached to 'fragt'.
        # All punctuation is also attached to 'fragt', it is thus not available as coordination delimiters.
        # We have to be robust and to survive such cases.
        # Since there seems to be no better solution, the first member of the coordination will become the root.
        # It will no longer be recognizable as coordination member. The coordination may now be deficient and have only one member.
        # If it was already a deficient coordination, i.e. if it had no delimiters and only one member, then something went wrong
        # (probably it is no coordination at all).
        log_fatal('Coordination has fewer than two members and no delimiters.') if ( scalar( @{ $c->{members} } ) < 2 );
        push( @{ $c->{delimiters} }, shift( @{ $c->{members} } ) );
    }

    # If the last delimiter is punctuation and it occurs after the last member
    # and there is at least one delimiter before the last member, choose this other delimiter.
    # We try to avoid non-coordinating punctuation such as quotation marks after the sentence.
    # However, some non-punctuation delimiters can occur after the last member. Example: "etc".
    my @ordered_members  = sort { $a->ord() <=> $b->ord() } ( @{ $c->{members} } );
    my $first_member_ord = $ordered_members[0]->ord();
    my $last_member_ord  = $ordered_members[$#ordered_members]->ord();
    my @inner_delimiters = grep { $_->ord() > $first_member_ord && $_->ord() < $last_member_ord } ( @{ $c->{delimiters} } );
    my $croot            = scalar(@inner_delimiters) ? pop(@inner_delimiters) : pop( @{ $c->{delimiters} } );

    # Attach the new root to the parent of the coordination.
    $croot->set_parent($parent);

    # Attach all coordination members to the new root.
    foreach my $member ( @{ $c->{members} } )
    {
        $member->set_parent($croot);
        $member->set_is_member(1);
    }

    # Attach all remaining delimiters to the new root.
    foreach my $delimiter ( @{ $c->{delimiters} } )
    {

        # The $croot is not guaranteed to be removed from delimiters if it was an inner delimiter.
        next if ( $delimiter == $croot );
        $delimiter->set_parent($croot);
        if ( $delimiter->form() eq ',' )
        {
            $delimiter->set_afun('AuxX');
        }
        elsif ( $delimiter->get_iset('pos') =~ m/^(conj|adv|part)$/ )
        {
            $delimiter->set_afun('AuxY');
        }
        else
        {
            $delimiter->set_afun('AuxG');
        }
    }

    # Now that members and delimiters are restructured, set also the afuns of the members.
    # Do not ask the former root about its real afun earlier.
    # If it is a preposition and the coordination members still sit among its children, the preposition may not know where to find its real afun.
    my $afun = $c->{oldroot}->get_real_afun() || '';
    $croot->set_afun('Coord');
    foreach my $member ( @{ $c->{members} } )
    {

        # Assign the afun of the whole coordination to the member.
        # Prepositional members require special treatment: the afun goes to the argument of the preposition.
        # Some members are in fact orphan dependents of an ellided member.
        # Their current afun is ExD and they shall keep it, unlike the normal members.
        $member->set_real_afun($afun) unless ( $member->afun() eq 'ExD' );
    }

    # Attach all shared modifiers to the new root.
    foreach my $modifier ( @{ $c->{shared_modifiers} } )
    {
        $modifier->set_parent($croot);
    }
}

#------------------------------------------------------------------------------
# Several treebanks solve apposition so that the second member is attached to
# the first member and marked using a special dependency relation tag. Changing
# this tag to the Apos afun is not enough Praguish: in reality we want to find
# a suitable punctuation in between, make it the Apos root and attach both
# members to it. Before we implement this behavior we may want to apply the
# poor-man's solution (just to make sure that there are no invalid Apos
# structures): remove any Apos afuns and replace them by Atr.
#------------------------------------------------------------------------------
sub shape_apposition
{
    my $self = shift;
    my $node = shift;
    if($node->afun() eq 'Apos')
    {
        $node->set_afun('Atr');
    }
    foreach my $child ($node->children())
    {
        $self->shape_apposition($child);
    }
}

#------------------------------------------------------------------------------
# This method is called for coordination and apposition nodes whose members do
# not have the is_member attribute set (e.g. in Arabic and Slovene treebanks
# the information was lost in conversion to CoNLL). It estimates, based on
# afuns, which children are members and which are shared modifiers.
#------------------------------------------------------------------------------
sub identify_coap_members
{
    my $self = shift;
    my $coap = shift;
    return unless($coap->afun() =~ m/^(Coord|Apos)$/);
    # We should not estimate coap membership if it is already known!
    foreach my $child ($coap->children())
    {
        if($child->is_member())
        {
            log_warn('Trying to estimate CoAp membership of a node that is already marked as member.');
        }
    }
    # Get the list of nodes involved in the structure.
    my @involved = $coap->get_children({'ordered' => 1, 'add_self' => 1});
    # Get the list of potential members and modifiers, i.e. drop delimiters.
    # Note that there may be more than one Coord|Apos node involved if there are nested structures.
    # We simplify the task by assuming (wrongly) that nested structures are always members and never modifiers.
    # Delimiters can have the following afuns:
    # Coord|Apos ... the root of the structure, either conjunction or punctuation
    # AuxY ... other conjunction
    # AuxX ... comma
    # AuxG ... other punctuation
    my @memod = grep {$_->afun() !~ m/^Aux[GXY]$/ && $_!=$coap} (@involved);
    # If there are only two (or fewer) candidates, consider both members.
    if(scalar(@memod)<=2)
    {
        foreach my $m (@memod)
        {
            $m->set_is_member(1);
        }
    }
    else
    {
        # Hypothesis: all members typically have the same afun.
        # Find the most frequent afun among candidates.
        # For the case of ties, remember the first occurrence of each afun.
        # Do not count nested 'Coord' and 'Apos': these are jokers substituting any member afun.
        # Same for 'ExD': these are also considered members (in fact they are children of an ellided member).
        my %count;
        my %first;
        foreach my $m (@memod)
        {
            my $afun = defined($m->afun()) ? $m->afun() : '';
            next if($afun =~ m/^(Coord|Apos|ExD)$/);
            $count{$afun}++;
            $first{$afun} = $m->ord() if(!exists($first{$afun}));
        }
        # Get the winning afun.
        my @afuns = sort
        {
            my $result = $count{$b} <=> $count{$a};
            unless($result)
            {
                $result = $first{$a} <=> $first{$b};
            }
            return $result;
        }
        (keys(%count));
        # Note that there may be no specific winning afun if all candidate afuns were Coord|Apos|ExD.
        my $winner = @afuns ? $afuns[0] : '';
        ###!!! If the winning afun is 'Atr', it is possible that some Atr nodes are members and some are shared modifiers.
        ###!!! In such case we ought to check whether the nodes are delimited by a delimiter.
        ###!!! This has not yet been implemented.
        foreach my $m (@memod)
        {
            my $afun = defined($m->afun()) ? $m->afun() : '';
            if($afun eq $winner || $afun =~ m/^(Coord|Apos|ExD)$/)
            {
                $m->set_is_member(1);
            }
        }
    }
}

#------------------------------------------------------------------------------
# Conjunction (such as 'and', 'but') occurring as the first word of the
# sentence should be analyzed as deficient coordination whose only member is
# the main verb of the main clause.
#------------------------------------------------------------------------------
sub mark_deficient_clausal_coordination
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants( { ordered => 1 } );
    if ( $nodes[0]->afun() eq 'Coord' && scalar($nodes[0]->get_coap_members())==0 )
    {
        my $croot = $nodes[0];
        my @root_children = $root->children();
        # Do not reattach $croot earlier because it must not be one of @root_children.
        # Do not reattach it later because Treex might complain about cycles.
        $croot->set_parent($root);
        foreach my $rc (@root_children)
        {
            next if($rc==$croot);
            # The sentence-final punctuation must stay at the upper level.
            next if($rc->afun() eq 'AuxK');
            $rc->set_parent($croot);
            $rc->set_is_member(1) unless($rc->afun() =~ m/^Aux[GXY]$/);
        }
        # It is not guaranteed that $croot now has coordination members.
        # If we were not able to find nodes elligible as members, we must not tag $croot as Coord.
        if(scalar($croot->get_coap_members())==0)
        {
            $croot->set_afun('ExD');
        }
    }
}

#------------------------------------------------------------------------------
# Validates coordination/apposition structures.
# - A Coord/Apos node must have at least one member.
# - A node with is_member set must have a Coord/Apos parent.
# - Note that is_member is now set directly under the Coord/Apos node,
#   regardless of prepositions and subordinating conjunctions.
# - Members should not have afuns AuxX (comma), AuxG (other punctuation) and
#   AuxY (other words, e.g. parts of multi-word coordinating conjunction).
#------------------------------------------------------------------------------
sub validate_coap
{
    my $self = shift;
    my $node = shift;
    my $afun = $node->afun();
    my @children = $node->get_children();
    if($afun =~ m/^(Coord|Apos)$/ && !grep {$_->is_member()} (@children))
    {
        $self->log_sentence($node);
        log_warn("The $afun node #".$node->ord()." '".$node->form()."' is missing coap members.");
    }
    if($node->is_member())
    {
        if($node->parent()->afun() !~ m/^(Coord|Apos)$/)
        {
            $self->log_sentence($node);
            log_warn("The member node #".$node->ord()." '".$node->form()."' does not have a coap parent.");
        }
        if($afun =~ m/^Aux[GXY]$/)
        {
            $self->log_sentence($node);
            log_warn("The node #".$node->ord()." '".$node->form()."' should be either coap member or $afun but not both.");
        }
    }
    foreach my $child (@children)
    {
        $self->validate_coap($child);
    }
}

#------------------------------------------------------------------------------
# Swaps node with its parent. The original parent becomes a child of the node.
# All other children of the original parent become children of the node. The
# node also keeps its original children.
#
# The lifted node gets the afun of the original parent while the original
# parent gets a new afun. The conll_deprel attribute is changed, too, to
# prevent possible coordination destruction.
#------------------------------------------------------------------------------
sub lift_node
{
    my $self   = shift;
    my $node   = shift;
    my $afun   = shift;             # new afun for the old parent
    my $parent = $node->parent();
    confess('Cannot lift a child of the root') if ( $parent->is_root() );
    my $grandparent = $parent->parent();

    # Reattach myself to the grandparent.
    $node->set_parent($grandparent);
    $node->set_afun( $parent->afun() );
    $node->set_conll_deprel( $parent->conll_deprel() );

    # Reattach all previous siblings to myself.
    foreach my $sibling ( $parent->children() )
    {

        # No need to test whether $sibling==$node as we already reattached $node.
        $sibling->set_parent($node);
    }

    # Reattach the previous parent to myself.
    $parent->set_parent($node);
    $parent->set_afun($afun);
    $parent->set_conll_deprel('');
}

#------------------------------------------------------------------------------
# Writes the current sentence including the sentence number to the log. To be
# used together with warnings so that the problematic sentence can be localized
# and examined in Ttred.
#------------------------------------------------------------------------------
sub log_sentence
{
    my $self = shift;
    my $node = shift;
    my $root = $node->get_root();

    # get_position() returns numbers from 0 but Tred numbers sentences from 1.
    my $i = $root->get_bundle()->get_position() + 1;
    log_info( "\#$i " . $root->get_zone()->sentence() );
}

#------------------------------------------------------------------------------
# Returns 1 if the sentence of a given node contains a given substring (mind
# tokenization). Returns 0 otherwise. Can be used to easily focus debugging on
# a problematic sentence like this:
# $debug = $self->sentence_contains($node, 'sondern auch mit Instrumenten');
#------------------------------------------------------------------------------
sub sentence_contains
{
    my $self     = shift;
    my $node     = shift;
    my $query    = shift;
    my $sentence = $node->get_zone()->sentence();
    return $sentence =~ m/$query/;
}

#------------------------------------------------------------------------------
# Error handler: removes 'is_member' attribute if the node is not
# part of the coordination structure.
#------------------------------------------------------------------------------
sub remove_ismember_membership
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes) {
        if ($node->is_member) {
            my $parnode = $node->get_parent();
            if (defined $parnode) {
                my $parafun = $parnode->afun();
                if ($parafun !~ /^(Coord|Apos)$/) {# remove the 'is_member'
                    $node->set_is_member(0);
                }
            }
        }
    }
}
1;

=over

=item Treex::Block::A2A::CoNLL2PDTStyle

Common methods for language-dependent blocks that transform trees from the
various styles of the CoNLL treebanks to the style of the Prague Dependency
Treebank (PDT).

The analytical functions (afuns) need to be guessed from C<conll/deprel> and
other sources of information. The tree structure must be transformed at places
(e.g. there are various styles of capturing coordination).

Morphological tags should be decoded into Interset. Then the C<tag> attribute
should be set to the PDT 15-character positional tag matching the Interset
features.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
