package Treex::Block::Print::AlignmentStatistics;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has layer               => ( isa => 'Treex::Type::Layer', is => 'ro', default=> 'a' );
has source_language     => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1 );
has source_selector     => ( isa => 'Treex::Type::Selector', is => 'ro', default => q{} );
has alignment_type      => ( isa => 'Str', is => 'ro', default => '.*', documentation => 'Use only alignments whose type is matching this regex. Default is ".*".' );
has alignment_direction => (
    is=>'ro',
    isa=>enum( [qw(src2trg trg2src)] ),
    default=>'trg2src',
    documentation=>'Default trg2src means alignment from <language,selector> to <source_language,source_selector> tree. src2trg means the opposite direction.',
);
has _stats => ( is => 'ro', default => sub { {} } );

sub process_zone {
    my ( $self, $zone ) = @_;
    my $source_zone = $zone->get_bundle()->get_zone( $self->source_language, $self->source_selector);
    my ($tree, $source_tree) = map {$_->get_tree($self->layer)} ($zone, $source_zone);	
    $self->print_alignment_info($source_tree, $tree);
}

sub print_alignment_info {
	my ($self, $src_tree, $tgt_tree) = @_;
	my %local_stat = ();
	$local_stat{'src_unaligned'} = 0;
	$local_stat{'tgt_unaligned'} = 0;
	$local_stat{'one_to_one'} = 0;
	$local_stat{'one_to_many'} = 0;
	$local_stat{'many_to_one'} = 0;	
	$local_stat{'src_len'} = 0;
	$local_stat{'tgt_len'} = 0;	
	my @src_nodes = $src_tree->get_descendants({ordered=>1});
	my @tgt_nodes = $tgt_tree->get_descendants({ordered=>1});
	if ($self->alignment_direction eq 'src2trg') {
		foreach my $i (0..$#src_nodes) {
			my @aligned_nodes = $src_nodes[$i]->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->language, $self->selector);
			if (@aligned_nodes) {
				if (scalar(@aligned_nodes) > 1) {
					$local_stat{'one_to_many'}++;	
				}
				elsif (scalar(@aligned_nodes) == 1) {
					my @referring_nodes = grep {$_->is_aligned_to($aligned_nodes[0], '^' . $self->alignment_type . '$')} $aligned_nodes[0]->get_referencing_nodes('alignment', $self->source_language, $self->source_selector);
					if (scalar(@referring_nodes) == 1) {
						$local_stat{'one_to_one'}++;
					}
				}
			}	
			else {
				$local_stat{'src_unaligned'}++;
			}
		}		
		foreach my $j (0..$#tgt_nodes) {
			my @referring_nodes = grep {$_->is_aligned_to($tgt_nodes[$j], '^' . $self->alignment_type . '$')} $tgt_nodes[$j]->get_referencing_nodes('alignment', $self->source_language, $self->source_selector);
			if (!@referring_nodes) {
				$local_stat{'tgt_unaligned'}++;
			}
			if (@referring_nodes) {
				if ($#referring_nodes > 0) {
					my $is_m_to_1 = 1;
					foreach my $rn (@referring_nodes) {
						my @aligned_nodes = $rn->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->language, $self->selector);
						if (scalar(@aligned_nodes) != 1) {
							$is_m_to_1 = 0;
							last;
						}
					}
					if ($is_m_to_1) {
						$local_stat{'many_to_one'}++;
					}
				}
			}
		}
	}
	else {
		foreach my $i (0..$#src_nodes) {
			my @referring_nodes = grep {$_->is_aligned_to($src_nodes[$i], '^' . $self->alignment_type . '$')} $src_nodes[$i]->get_referencing_nodes('alignment', $self->language, $self->selector);
			if (@referring_nodes) {
				if (scalar(@referring_nodes) > 1) {
					$local_stat{'one_to_many'}++;
				}	
				elsif (scalar(@referring_nodes) == 1) {
					my @aligned_nodes = $referring_nodes[0]->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->source_language, $self->source_selector);
					if (scalar(@aligned_nodes) == 1) {
						$local_stat{'one_to_one'}++;
					}
				}			
			}
			else {
				$local_stat{'src_unaligned'}++;
			}
		}
		foreach my $j (0..$#tgt_nodes) {
			my @aligned_nodes = $tgt_nodes[$j]->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->source_language, $self->source_selector);
			if (!@aligned_nodes) {
				$local_stat{'tgt_unaligned'}++;
			}
			if (@aligned_nodes) {
				if ($#aligned_nodes > 0) {
					my $is_m_to_1 = 1;
					foreach my $an (@aligned_nodes) {
						my @referring_nodes = grep {$_->is_aligned_to($an, '^' . $self->alignment_type . '$')} $an->get_referencing_nodes('alignment', $self->language, $self->selector);
						if (scalar(@referring_nodes != 1)) {
							$is_m_to_1 = 0;
							last;							
						}						
					}
					if ($is_m_to_1) {
						$local_stat{'many_to_one'}++;
					}					
				}
			}
		}		
	}	
	my $out_string = sprintf("%20s %20s %4d %4d %4d %4d %4d %4d %4d", (substr $src_tree->id, 0, 20), (substr $tgt_tree->id, 0, 20), scalar(@src_nodes), scalar(@tgt_nodes), $src_unaligned, $tgt_unaligned, $one_to_one, $one_to_many, $many_to_one);
	print { $self->_file_handle } $out_string . "\n";
}

sub process_end {
	
}

1;


__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::AlignmentStatistics - prints useful information about the word alignment between two language data

=head TODO

some description

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


