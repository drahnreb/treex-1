package Treex::Block::Gazetteer::ExtractEntityVectors;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;

use Treex::Tool::Gazetteer::Engine;
use Treex::Tool::ML::VowpalWabbit::Util;

extends 'Treex::Block::Write::BaseTextWriter';

has 'src_list_path' => ( is => 'ro', isa => 'Str' );
has 'trg_list_path' => ( is => 'ro', isa => 'Str' );
has 'trg_lang' => (is => 'ro', isa => 'Str' );

has '_src_gazetteer_trie' => (is => 'ro', isa => 'Treex::Tool::Gazetteer::Engine', builder => '_build_src_gazetteer_tree', lazy => 1);
has '_trg_gazetteer_hash' => (is => 'ro', isa => 'Treex::Tool::Gazetteer::Engine', builder => '_build_trg_gazetteer_hash', lazy => 1);

sub BUILD {
    my ($self) = @_;
    $self->_src_gazetteer_trie;
    $self->_trg_gazetteer_hash;
}

sub _build_src_gazetteer_tree {
    my ($self) = @_;
    my $trie = Treex::Tool::Gazetteer::Engine->new({is_src => 1, path => $self->src_list_path });
    return $trie;
}

sub _build_trg_gazetteer_hash {
    my ($self) = @_;
    my $hash = Treex::Tool::Gazetteer::Engine->new({is_src => 0, path => $self->trg_list_path });
    return $hash;
}

sub process_bundle {
    my ($self, $bundle) = @_;

    my $src_zone = $bundle->get_zone($self->language, $self->selector);
    my $trg_zone = $bundle->get_zone($self->trg_lang, $self->selector);

    my $matches = $self->_src_gazetteer_trie->match_phrases_in_atree($src_zone->get_atree);

    foreach my $match (@$matches) {
        my $class = $self->_extract_class($match, $trg_zone->sentence);
        my $feats = $self->_extract_feats($match);
        my $comment = $match->[1] . "; " . $src_zone->sentence . "; ". $trg_zone->sentence;

        my $str = Treex::Tool::ML::VowpalWabbit::Util::format_singleline($feats, $class, $class, $comment);
        print {$self->_file_handle} $str;
    }
}

sub _extract_class {
    my ($self, $match, $trg_sent) = @_;
    my $id = $match->[0];
    my $trg_phrase = $self->_trg_gazetteer_hash->get_phrase_by_id($id);
    return ($trg_sent =~ /((^)|( ))\Q$trg_phrase\E[.,?!: ]/) ? 1 : 0;
}

sub _extract_feats {
    my ($self, $match) = @_;

    my @feats = ();

    my @anodes = @{$match->[2]};
    my @forms = map {$_->form} @anodes;

    my $full_str = join " ", @forms;
    
    my $full_str_eq = ($full_str eq $match->[1]) ? 1 : 0;
    push @feats, ['full_str_eq', $full_str_eq];

    my $non_alpha = ($full_str !~ /[a-zA-Z]/) ? 1 : 0;
    push @feats, ['full_str_non_alpha', $non_alpha];

    my $first_starts_capital = ($forms[0] =~ /^\p{IsUpper}/) ? 1 : 0;
    push @feats, ['first_starts_capital', $first_starts_capital];
    
    my $entity_starts_capital = ($match->[1] =~ /^\p{IsUpper}/) ? 1 : 0;
    push @feats, ['entity_starts_capital', $entity_starts_capital];

    my $all_start_capital = (all {$_ =~ /^\p{IsUpper}/} @forms) ? 1 : 0;
    push @feats, ['all_start_capital', $all_start_capital];
    
    my $no_first = (all {$_->ord > 1} @anodes) ? 1 : 0;
    push @feats, ['no_first', $no_first];

    my $last_menu = ($forms[$#forms] eq "menu") ? 1 : 0;
    push @feats, ['last_menu', $last_menu];

    return \@feats;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Gazetteer::ExtractEntityVectors - print vectors for gazetteer entity recognizer

=head1 DESCRIPTION

TODO

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
