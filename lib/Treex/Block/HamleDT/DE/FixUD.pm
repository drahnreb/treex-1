package Treex::Block::HamleDT::DE::FixUD;
use utf8;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::StanfordToUD;
extends 'Treex::Block::HamleDT::SplitFusedWords';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    # Fix relations before morphology. The fixes depend only on UPOS tags, not on morphology (e.g. NOUN should not be attached as det).
    # And with better relations we will be more able to disambiguate morphological case and gender.
    $self->convert_deprels($root);
    $self->fix_morphology($root);
    $self->regenerate_upos($root);
}



#------------------------------------------------------------------------------
# Converts dependency relations from UD v1 to v2.
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        my $deprel = $node->deprel();
        # Fix inherently reflexive verbs.
        if($node->is_reflexive() && $self->is_inherently_reflexive_verb($parent->lemma()))
        {
            $node->set_deprel('expl:pv');
        }
        $self->fix_genitive_noun_modifiers($node);
        # "um" is attached to an infinitive as 'aux' instead of 'mark'.
        if($node->is_adposition() && $parent->is_verb() && $deprel =~ m/^aux(:|$)/)
        {
            $node->set_deprel('mark');
        }
        # Error: advmod(Optiker, keinem) should be det.
        if($parent->is_noun() && $node->deprel() =~ m/^advmod(:|$)/ && !$node->is_adverb())
        {
            my $upos = $node->tag();
            if($upos =~ m/^(PRON|NOUN|PROPN)$/)
            {
                $node->set_deprel('nmod');
            }
            elsif($upos eq 'ADJ')
            {
                $node->set_deprel('amod');
            }
            elsif($upos eq 'NUM')
            {
                $node->set_deprel('nummod');
            }
            elsif($upos eq 'DET')
            {
                $node->set_deprel('det');
            }
        }
        # Sometimes "kein" is attached to an adjective instead of the following noun.
        elsif($node->lemma() eq 'kein' && $parent->deprel() eq 'amod' && $node->deprel() =~ m/^advmod(:|$)/)
        {
            $parent = $parent->parent();
            $node->set_parent($parent);
            $deprel = 'det';
            $node->set_deprel($deprel);
        }
        # In "auch wenn", "wenn" is 'mark' or 'cc' and "auch" is wrongly attached as 'advmod' to "wenn".
        if($node->deprel() =~ m/^advmod(:|$)/ && $parent->deprel() =~ m/^(cc|mark)(:|$)/)
        {
            $parent = $parent->parent();
            $node->set_parent($parent);
        }
        # Words like "Million" are tagged NOUN but attached as nummod. They have to be nmod.
        if($node->is_noun() && $node->deprel() eq 'nummod')
        {
            $deprel = 'nmod';
            $node->set_deprel($deprel);
        }
        # Adjectives cannot be attached as det. They have to be amod.
        if($node->is_adjective() && !$node->is_pronominal() && $node->deprel() eq 'det')
        {
            $deprel = 'amod';
            $node->set_deprel($deprel);
        }
        # Nouns attached as cop should in fact be nsubj (they are subjects of nonverbal predicates in sentences where copula is missing).
        if($node->is_noun() && !$node->is_pronominal() && $node->deprel() eq 'cop')
        {
            $deprel = 'nsubj';
            $node->set_deprel($deprel);
        }
        # Auxiliary verbs, adverbial modifiers and conjunctions are sometimes wrongly attached to the copula instead of the nominal predicate.
        $parent = $node->parent();
        if(defined($parent->deprel()) && $parent->deprel() =~ m/^(cop|aux)(:|$)/ && $deprel !~ m/^(conj|punct)$/)
        {
            $parent = $parent->parent();
            $node->set_parent($parent);
        }
        # Sometimes a prepositional phrase is still headed by the preposition.
        if($node->deprel() =~ m/^(obj|nmod|nsubj|xcomp)(:|$)/ && $parent->deprel() eq 'case')
        {
            if($parent->parent()->is_noun())
            {
                $deprel = 'nmod';
            }
            else
            {
                $deprel = 'obl';
            }
            my $preposition = $node->parent();
            $parent = $preposition->parent();
            $node->set_parent($parent);
            $node->set_deprel($deprel);
            $preposition->set_parent($node);
        }
        $self->fix_right_to_left_apposition($node);
        if($node->is_pronoun() && $node->deprel() eq 'advmod')
        {
            $deprel = 'obl';
            $node->set_deprel($deprel);
        }
        $self->fix_auxiliary_verb($node);
    }
}



#------------------------------------------------------------------------------
# Fix auxiliary verb that should not be auxiliary.
#------------------------------------------------------------------------------
sub fix_auxiliary_verb
{
    my $self = shift;
    my $node = shift;
    if($node->tag() eq 'AUX')
    {
        if($node->deprel() =~ m/^aux(:|$)/ && $node->lemma() =~ m/^(bleiben)$/)
        {
            # We assume that the "auxiliary" verb is attached to an infinitive
            # which in fact should depend on the "auxiliary" (as xcomp).
            # We further assume (although it is not guaranteed) that all other
            # aux dependents of that infinitive are real auxiliaries.
            # If there were other spuriious auxiliaries, it would matter
            # in which order we reattach them.
            my $infinitive = $node->parent();
            if($infinitive->is_infinitive())
            {
                my $parent = $infinitive->parent();
                my $deprel = $infinitive->deprel();
                $node->set_parent($parent);
                $node->set_deprel($deprel);
                $infinitive->set_parent($node);
                $infinitive->set_deprel('xcomp');
                # Subject, adjuncts and other auxiliaries go up.
                # Non-subject arguments remain with the infinitive.
                my @children = $infinitive->children();
                foreach my $child (@children)
                {
                    if($child->deprel() =~ m/^(([nc]subj|advmod|aux)(:|$)|obl$)/ ||
                       $child->deprel() =~ m/^obl:([a-z]+)$/ && $1 ne 'arg')
                    {
                        $child->set_parent($node);
                    }
                }
                # We also need to change the part-of-speech tag from AUX to VERB.
                $node->iset()->clear('verbtype');
                $node->set_tag('VERB');
            }
        }
        elsif($node->deprel() eq 'cop' && $node->lemma() =~ m/^(bleiben)$/)
        {
            my $pnom = $node->parent();
            my $parent = $pnom->parent();
            my $deprel = $pnom->deprel();
            $node->set_parent($parent);
            $node->set_deprel($deprel);
            $pnom->set_parent($node);
            $pnom->set_deprel('xcomp');
            # Subject, adjuncts and other auxiliaries go up.
            # Noun modifiers remain with the nominal predicate.
            my @children = $pnom->children();
            foreach my $child (@children)
            {
                if($child->deprel() =~ m/^(([nc]subj|advmod|aux)(:|$)|obl$)/ ||
                   $child->deprel() =~ m/^obl:([a-z]+)$/ && $1 ne 'arg')
                {
                    $child->set_parent($node);
                }
            }
            # We also need to change the part-of-speech tag from AUX to VERB.
            $node->iset()->clear('verbtype');
            $node->set_tag('VERB');
        }
    }
}



#------------------------------------------------------------------------------
# Right-to-left appositions occur when a short nonverbal phrase introduces the
# sentence: "Danke, die Blumen sind eingetroffen."
#------------------------------------------------------------------------------
sub fix_right_to_left_apposition
{
    my $self = shift;
    my $node = shift;
    if($node->deprel() eq 'appos' && $node->parent()->ord() > $node->ord() && $node->parent()->deprel() eq 'root')
    {
        my $current_root = $node->parent();
        $node->set_parent($current_root->parent());
        $node->set_deprel('root');
        $current_root->set_parent($node);
        $current_root->set_deprel('appos');
    }
}



#------------------------------------------------------------------------------
# Genitive nouns are sometimes attached as 'det' instead of 'nmod'. Fix it.
#------------------------------------------------------------------------------
sub fix_genitive_noun_modifiers
{
    my $self = shift;
    my $node = shift;
    if($node->is_noun() && !$node->is_pronominal() && $node->is_genitive() && $node->deprel() eq 'det')
    {
        $node->set_deprel('nmod');
    }
}



#------------------------------------------------------------------------------
# Identifies German inherently reflexive verbs (echte reflexive Verben). Note
# that there are very few verbs where we can automatically say that the they
# are reflexive. In some cases they are mostly reflexive, but the transitive
# usage cannot be excluded, although it is rare, obsolete or limited to some
# dialects. In other cases the reflexive use has a meaning significantly
# different from the transitive use, and it would deserve to be annotated using
# expl:pv, but we cannot tell the two usages apart automatically.
#------------------------------------------------------------------------------
sub is_inherently_reflexive_verb
{
    my $self = shift;
    my $lemma = shift;
    # The following examples are taken from Knaurs Grammatik der deutschen Sprache, 1989
    # (first line) + some additions (second line).
    # with accusative
    my @irva = qw(
        bedanken beeilen befinden begeben erholen nähern schämen sorgen verlieben
        anfreunden weigern
    );
    # with dative
    my @irvd = qw(
        aneignen anmaßen ausbitten einbilden getrauen gleichbleiben vornehmen
    );
    my $re = join('|', (@irva, @irvd));
    return $lemma =~ m/^($re)$/;
}



#------------------------------------------------------------------------------
# Fixes known issues in features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        $self->fix_mwt_capitalization($node);
        my $form = $node->form();
        my $lemma = $node->lemma();
        my $iset = $node->iset();
        if($lemma eq 'nicht')
        {
            $iset->set('polarity', 'neg');
        }
        # "ihres" is determiner, not adjective.
        if($node->tag() eq 'ADJ' && $node->conll_pos() =~ m/^P.+AT$/ && $lemma !~ m/^(nett|fein|genügend|direkt)$/i)
        {
            $node->iset()->set('prontype', 'prn');
        }
        # Getting lemmas of auxiliary verbs right is important because the
        # validator uses them to check that normal verbs are not tagged as
        # auxiliary.
        if($node->is_verb())
        {
            if($form =~ m/^ha(ben|be?s?t?|s?t)$/i)
            {
                $lemma = 'haben';
                $node->set_lemma($lemma);
            }
            # There is even one occurrence of "wir" meaning "wird".
            elsif($form =~ m/^((ge)?w[eio]rd|wir$)/i)
            {
                $lemma = 'werden';
                $node->set_lemma($lemma);
            }
            elsif($form =~ m/^kanns$/i)
            {
                $lemma = 'können';
                $node->set_lemma($lemma);
            }
        }
        # 'ein' can work as the indefinite article or as the number 'one' and the borderline is fuzzy.
        # In case of conflict, trust the dependency relation.
        if($lemma eq 'ein' && $node->deprel() =~ m/^nummod(:|$)/)
        {
            $node->iset()->set('pos', 'num');
            $node->iset()->set('numtype', 'card');
            $node->iset()->clear('prontype');
            $node->iset()->clear('definite');
        }
    }
    # It is possible that we changed the form of a multi-word token.
    # Therefore we must re-generate the sentence text.
    $root->get_zone()->set_sentence($root->collect_sentence_text());
}



#------------------------------------------------------------------------------
# Identifies and returns the subject of a verb or another predicate. If the
# verb is copula or auxiliary, finds the subject of its parent.
#------------------------------------------------------------------------------
sub get_subject
{
    my $self = shift;
    my $node = shift;
    my @subj = grep {$_->deprel() =~ m/subj/} $node->children();
    # There should not be more than one subject (coordination is annotated differently).
    # The caller expects at most one node, so we will not return more than that, even if present.
    return $subj[0] if(scalar(@subj)>0);
    return undef if($node->is_root());
    return $self->get_subject($node->parent()) if($node->deprel() =~ m/^(aux|cop)/);
    return undef;
}



#------------------------------------------------------------------------------
# After changes done to Interset (including part of speech) generates the
# universal part-of-speech tag anew.
#------------------------------------------------------------------------------
sub regenerate_upos
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        $node->set_tag($node->iset()->get_upos());
    }
}



#------------------------------------------------------------------------------
# Makes capitalization of muti-word tokens consistent with capitalization of
# their parts.
#------------------------------------------------------------------------------
sub fix_mwt_capitalization
{
    my $self = shift;
    my $node = shift;
    # Is this node part of a multi-word token?
    if($node->is_fused())
    {
        my $pform = $node->form();
        my $fform = $node->get_fusion();
        # It is not always clear whether we want to fix the mwt or the part.
        # In German however, the most frequent error seems to be that in the
        # beginning of a sentence, the mwt is not capitalized while its first
        # part is.
        if($node->get_fusion_start() == $node && $node->ord() == 1 && is_capitalized($pform) && is_lowercase($fform))
        {
            $fform =~ s/^(.)/\u$1/;
            $node->set_fused_form($fform);
        }
        # Occasionally the problem occurs also in the middle of the sentence, e.g. after punctuation that might terminate a sentence but does not here.
        # In such cases we want to lowercase the first part.
        elsif($node->get_fusion_start() == $node && is_capitalized($pform) && is_lowercase($fform))
        {
            $node->set_form(lc($pform));
        }
    }
}



#------------------------------------------------------------------------------
# Checks whether a string is all-uppercase.
#------------------------------------------------------------------------------
sub is_uppercase
{
    my $string = shift;
    return $string eq uc($string);
}



#------------------------------------------------------------------------------
# Checks whether a string is all-lowercase.
#------------------------------------------------------------------------------
sub is_lowercase
{
    my $string = shift;
    return $string eq lc($string);
}



#------------------------------------------------------------------------------
# Checks whether a string is capitalized.
#------------------------------------------------------------------------------
sub is_capitalized
{
    my $string = shift;
    return 0 if(length($string)==0);
    $string =~ m/^(.)(.*)$/;
    my $head = $1;
    my $tail = $2;
    return is_uppercase($head) && !is_uppercase($tail);
}



#------------------------------------------------------------------------------
# Collects all nodes in a subtree of a given node. Useful for fixing known
# annotation errors, see also get_node_spanstring(). Returns ordered list.
#------------------------------------------------------------------------------
sub get_node_subtree
{
    my $self = shift;
    my $node = shift;
    my @nodes = $node->get_descendants({'add_self' => 1, 'ordered' => 1});
    return @nodes;
}



#------------------------------------------------------------------------------
# Collects word forms of all nodes in a subtree of a given node. Useful to
# uniquely identify sentences or their parts that are known to contain
# annotation errors. (We do not want to use node IDs because they are not fixed
# enough in all treebanks.) Example usage:
# if($self->get_node_spanstring($node) =~ m/^peça a URV em a sua mesada$/)
#------------------------------------------------------------------------------
sub get_node_spanstring
{
    my $self = shift;
    my $node = shift;
    my @nodes = $self->get_node_subtree($node);
    return join(' ', map {$_->form() // ''} (@nodes));
}



1;

=over

=item Treex::Block::HamleDT::DE::FixUD

This is a temporary block that should fix selected known problems in the German UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016, 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
