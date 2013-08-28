package Treex::Block::Test::A::AuxXisComma;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode {
    my ($self, $anode) = @_;

    if ($anode->afun eq 'AuxX' && $anode->form ne ',') {
        $self->complain($anode);
    }
}

1;

=over

=item Treex::Block::Test::A::AuxXisComma

Only comma should be AuxX

=back

=cut

