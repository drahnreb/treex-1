package Treex::Block::A2A::CorefClusters;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



has last_cluster_id => (is => 'rw', default => 0);



sub process_anode
{
    my $self = shift;
    my $anode = shift;
    my $document = $anode->get_document();
    my $last_cluster_id = $self->last_cluster_id();
    # Only nodes linked to t-layer can have coreference annotation.
    if(exists($anode->wild()->{'tnode.rf'}))
    {
        my $tnode_rf = $anode->wild()->{'tnode.rf'};
        my $tnode = $anode->get_document()->get_node_by_id($tnode_rf);
        if(defined($tnode))
        {
            # Do we already have a cluster id?
            my $current_cluster_id = $anode->get_misc_attr('ClusterId');
            # Get coreference edges.
            my @gcoref = $tnode->get_coref_gram_nodes();
            my @tcoref = $tnode->get_coref_text_nodes();
            foreach my $ctnode (@gcoref, @tcoref)
            {
                # $ctnode is the target t-node of the coreference edge.
                # We need to access its corresponding lexical a-node.
                my $canode = $ctnode->get_lex_anode();
                if(defined($canode))
                {
                    # Does the target node already have a cluster id?
                    my $current_target_cluster_id = $canode->get_misc_attr('ClusterId');
                    if(defined($current_cluster_id) && defined($current_target_cluster_id))
                    {
                        # Are we merging two clusters that were created independently?
                        if($current_cluster_id ne $current_target_cluster_id)
                        {
                            # Merge the two clusters. Use the lower id. The higher id will remain unused.
                            my $id1 = $current_cluster_id;
                            my $id2 = $current_target_cluster_id;
                            $id1 =~ s/^c//;
                            $id2 =~ s/^c//;
                            my $merged_id = 'c'.($id1 < $id2 ? $id1 : $id2);
                            my @cluster_members = sort(@{$anode->wild()->{cluster_members}}, @{$canode->wild()->{cluster_members}});
                            foreach my $id (@cluster_members)
                            {
                                my $node = $document->get_node_by_id($id);
                                $node->set_misc_attr('ClusterId', $merged_id);
                                @{$node->wild()->{cluster_members}} = @cluster_members;
                            }
                        }
                    }
                    elsif(defined($current_cluster_id))
                    {
                        $canode->set_misc_attr('ClusterId', $current_cluster_id);
                        my @cluster_members = sort(@{$anode->wild()->{cluster_members}}, $canode->id());
                        foreach my $id (@cluster_members)
                        {
                            my $node = $document->get_node_by_id($id);
                            @{$node->wild()->{cluster_members}} = @cluster_members;
                        }
                        my ($mspan, $mtext) = $self->get_mention_span($canode);
                        $canode->set_misc_attr('MentionSpan', $mspan);
                        $canode->set_misc_attr('MentionText', $mtext);
                    }
                    elsif(defined($current_target_cluster_id))
                    {
                        $anode->set_misc_attr('ClusterId', $current_target_cluster_id);
                        my @cluster_members = sort(@{$canode->wild()->{cluster_members}}, $anode->id());
                        foreach my $id (@cluster_members)
                        {
                            my $node = $document->get_node_by_id($id);
                            @{$node->wild()->{cluster_members}} = @cluster_members;
                        }
                        my ($mspan, $mtext) = $self->get_mention_span($anode);
                        $anode->set_misc_attr('MentionSpan', $mspan);
                        $anode->set_misc_attr('MentionText', $mtext);
                    }
                    else
                    {
                        # We need a new cluster id.
                        $last_cluster_id++;
                        $self->set_last_cluster_id($last_cluster_id);
                        $current_cluster_id = 'c'.$last_cluster_id;
                        $anode->set_misc_attr('ClusterId', $current_cluster_id);
                        $canode->set_misc_attr('ClusterId', $current_cluster_id);
                        # Remember references to all cluster members from all cluster members.
                        # We may later need to revisit all cluster members and this will help
                        # us find them.
                        my @cluster_members = sort($anode->id(), $canode->id());
                        @{$anode->wild()->{cluster_members}} = @cluster_members;
                        @{$canode->wild()->{cluster_members}} = @cluster_members;
                        my ($mspan, $mtext) = $self->get_mention_span($anode);
                        $anode->set_misc_attr('MentionSpan', $mspan);
                        $anode->set_misc_attr('MentionText', $mtext);
                        ($mspan, $mtext) = $self->get_mention_span($canode);
                        $canode->set_misc_attr('MentionSpan', $mspan);
                        $canode->set_misc_attr('MentionText', $mtext);
                    }
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# For a given a-node, finds its corresponding t-node, gets the list of all
# t-nodes in its subtree (including the head), gets their corresponding lexical
# a-nodes (only those that are in the same sentence), returns the ordered list
# of ords of these a-nodes (surface span of a t-node). For generated t-nodes
# (which either don't have a lexical a-node, or share it with another t-node,
# possibly even in another sentence) the method tries to find their
# corresponding empty a-nodes, added by T2A::GenerateEmptyNodes.
#------------------------------------------------------------------------------
sub get_mention_span
{
    my $self = shift;
    my $anode = shift;
    my @result = ();
    my @snodes = ();
    my $document = $anode->get_document();
    if(exists($anode->wild()->{'tnode.rf'}))
    {
        my $tnode = $document->get_node_by_id($anode->wild()->{'tnode.rf'});
        if(defined($tnode))
        {
            my @tsubtree = $tnode->get_descendants({'ordered' => 1, 'add_self' => 1});
            foreach my $tsn (@tsubtree)
            {
                if($tsn->is_generated())
                {
                    # The lexical a-node may not exist and if it exists, we do not want it because it belongs to another mention.
                    # However, there should be an empty a-node generated for enhanced ud, corresponding to this node.
                    if(exists($tsn->wild()->{'anode.rf'}))
                    {
                        my $asn = $document->get_node_by_id($tsn->wild()->{'anode.rf'});
                        if(defined($asn) && $asn->deprel() eq 'dep:empty')
                        {
                            push(@result, $asn->wild()->{enord});
                            push(@snodes, $asn);
                        }
                    }
                }
                else
                {
                    my $asn = $tsn->get_lex_anode();
                    # For non-generated nodes, the lexical a-node should be in the same sentence, but to be on the safe side, check it.
                    if(defined($asn) && $asn->get_root() == $anode->get_root())
                    {
                        push(@result, $asn->ord());
                        push(@snodes, $asn);
                    }
                }
            }
        }
    }
    @result = $self->sort_node_ids(@result);
    @snodes = $self->sort_nodes_by_ids(@snodes);
    # If a contiguous sequence of two or more nodes is a part of the mention,
    # it should be represented using a hyphen (i.e., "8-9" instead of "8,9",
    # and "8-10" instead of "8,9,10"). We must be careful though. There may
    # be empty nodes that are not included, e.g., we may have to write "8,9"
    # because there is 8.1 and it is not a part of the mention.
    my @allids = $self->sort_node_ids(map {$_->deprel() eq 'dep:empty' ? $_->wild()->{enord} : $_->ord()} ($anode->get_root()->get_descendants()));
    my @result2 = ();
    my @current_segment = ();
    # Add -1 to enforce flushing of the current segment at the end.
    foreach my $id (@allids, -1)
    {
        if(scalar(@result) > 0 && $result[0] == $id)
        {
            # The current segment is uninterrupted (but it may also be a new segment that starts with this id).
            push(@current_segment, shift(@result));
        }
        else
        {
            # The current segment is interrupted (but it may be empty anyway).
            if(scalar(@current_segment) > 1)
            {
                push(@result2, "$current_segment[0]-$current_segment[-1]");
                @current_segment = ();
            }
            elsif(scalar(@current_segment) == 1)
            {
                push(@result2, $current_segment[0]);
                @current_segment = ();
            }
            last if(scalar(@result) == 0);
        }
    }
    # For debugging purposes it is useful to also see the word forms of the span, so we will provide them, too.
    return (join(',', @result2), join(' ', map {$_->form()} (@snodes)));
}



#------------------------------------------------------------------------------
# Sorts a sequence of node ids that may contain empty nodes.
#------------------------------------------------------------------------------
sub sort_node_ids
{
    my $self = shift;
    return sort {cmp_node_ids($a, $b)} (@_);
}



#------------------------------------------------------------------------------
# Sorts a sequence of nodes that may contain empty nodes by their ids.
#------------------------------------------------------------------------------
sub sort_nodes_by_ids
{
    my $self = shift;
    return sort
    {
        my $aid = $a->deprel() eq 'dep:empty' ? $a->wild()->{enord} : $a->ord();
        my $bid = $b->deprel() eq 'dep:empty' ? $b->wild()->{enord} : $b->ord();
        cmp_node_ids($aid, $bid)
    }
    (@_);
}



#------------------------------------------------------------------------------
# Compares two CoNLL-U node ids (there can be empty nodes with decimal ids).
#------------------------------------------------------------------------------
sub cmp_node_ids
{
    my $a = shift;
    my $b = shift;
    my $amaj = $a;
    my $amin = 0;
    my $bmaj = $b;
    my $bmin = 0;
    if($amaj =~ s/^(\d+)\.(\d+)$/$1/)
    {
        $amin = $2;
    }
    if($bmaj =~ s/^(\d+)\.(\d+)$/$1/)
    {
        $bmin = $2;
    }
    my $r = $amaj <=> $bmaj;
    unless($r)
    {
        $r = $amin <=> $bmin;
    }
    return $r;
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CorefClusters

=item DESCRIPTION

Processes UD a-nodes that are linked to t-nodes (some of the a-nodes model
empty nodes in enhanced UD and may be linked to generated t-nodes). Scans
coreference links and assigns a unique cluster id to all nodes participating
on one coreference cluster. Saves the cluster id as a MISC (wild) attribute.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
