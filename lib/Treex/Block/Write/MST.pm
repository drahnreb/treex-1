package Treex::Block::Write::MST;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language'                        => ( required => 1 );
has 'deprel_attribute'                 => ( is       => 'rw', isa => 'Str', default => 'afun');
has 'pos_attribute'                    => ( is       => 'rw', isa => 'Str', default => 'tag' );

sub process_atree {
    my ( $self, $atree ) = @_;

    my @forms;
    my @tags;
    my @afuns;
    my @parents;

    my @anodes = $atree->get_descendants( { ordered => 1 } );

    map{ push @forms, $_->form; push @parents, $_->get_parent->ord }@anodes;
    map{ push @tags, $_->get_attr($self->pos_attribute) }@anodes;
    map{ push @afuns, $_->get_attr($self->deprel_attribute) }@anodes;

    my $form_line = join("\t", @forms);
    my $tag_line = join("\t", @tags);
    my $afun_line = join("\t", @afuns);
    my $parents_line = join("\t", @parents);

	print { $self->_file_handle() } (join( "\n", $form_line, $tag_line, $afun_line, $parents_line) . "\n");
    print { $self->_file_handle() } ("\n");

    return;
}

1;

__END__

=head1 NAME

Treex::Block::Print::MST - Print a-trees in MST format

=head1 DESCRIPTION

Each a-tree is printed in MST format.  

=head1 PARAMETERS

=over 4

=item pos_attribute

Specifies the name of the node attribute which contains POS tag. The possible values for pos_attribute are "tag", "conll/cpos" and "conll/pos".

=item deprel_attribute

 Specifies the name of the node attribute which contains the dependency relation. The possible values for deprel_attribute are "afun" and "conll/deprel".
 
=back

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
 
