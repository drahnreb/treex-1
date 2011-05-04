package Treex::Block::W2A::EN::ParseCharniak;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);
use Treex::Tools::Parser::Charniak::Charniak;
use Treex::Tools::Parser::Charniak::Node;
use TectoMT::Node::P;
use Clone;


my $parser;
my $string_to_parse;
my @sentences=();
my @results;
my @final_tree;
my $self;
my $document;
my $fsfile;
my $node;
my $parent;
my @processing_nodes=();
my @structure_nodes=();
my $current_node;
sub process_document {  
  ($self,$document) = @_;
  
    my $bundleno = 0;
    foreach my $bundle ($document->get_bundles())
    	{
   	 @processing_nodes=();
 	 @structure_nodes=();
	 @final_tree=();
	#Get Each Sentence Bundle
        my $m_root  = $bundle->get_tree('SEnglishM');
	#Get each child in Bundle... in this case we are looking for each word that was tokenized
        my @m_nodes = $m_root->get_children;
	
	#Check for EMpty sentences        
	if ( @m_nodes == 0 ) {
            Report::fatal "Impossible to parse an empty sentence. Bundle id=" . $bundle->get_attr('id');
        }
	
	#Get all the words per sentence with corrisponding ids
        my @words            = map { $_->get_attr('form') } @m_nodes;
        my @ids              = map { $_->get_attr('id') } @m_nodes;
	
	
	#create sentence to parse surrounded by <s> sentence </s>	
	$string_to_parse="<s> ";
	$string_to_parse.= join(" ", @words);
	$string_to_parse.=" </s> ";

		$parser =Parser::Charniak::Charniak->new();
	

my $tree_root =	$parser->parse(@words);

my @root_children = @{$tree_root->children};
$tree_root=$root_children[0];

  
	   my $p_root = $bundle->create_tree('SEnglishP' );
		push(@structure_nodes,$p_root);
		push(@processing_nodes,$tree_root);
		write_branch();

	 
	
   	$bundleno++;
	}

}

sub write_branch{
 

 while(scalar(@processing_nodes>0)){
 my Parser::Charniak::Node($node) = shift(@processing_nodes);
 $current_node=shift(@structure_nodes);

 my @node_children = @{$node->children};
 push (@processing_nodes,@node_children);


 foreach my $n (@node_children) { 
 my @node_grandchildren = @{$n->children};	


	if(scalar(@node_grandchildren)>0 ){		
                my $nonterminal = $current_node->create_child;
              
		
                $nonterminal->set_attr( 'phrase',   $n->term ); 
		
                $nonterminal->get_tied_fsnode->{'#name'} = 'nonterminal';
	

	push (@structure_nodes,$nonterminal);
	}
	else{
 		$current_node->set_attr( 'form',  $n->term );
                $current_node->set_attr( 'tag',   $node->term ); 
		$current_node->get_tied_fsnode->{'#name'} = 'terminal';
           	push (@structure_nodes,$current_node);

	}


}
	


}#end while
}


1;
=over




