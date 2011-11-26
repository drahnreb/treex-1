package Treex::Tool::Parallel::Replicator;

use Moose;
use Treex::Core::Common;
use File::Temp qw(tempdir);
use Cwd 'abs_path';
use Storable;
use Treex::Tool::Parallel::MessageBoard;

has path => (
    is => 'rw',
    isa => 'Str',
    default => '.',
    documentation => 'directory in which working directory structure will be created',
);

has workdir => (
    is => 'rw',
    isa => 'Str',
    documentation => 'working directory created for storing messages',
);

has jobs => (
    is => 'rw',
    isa => 'Int',
    default => sub {10},
    documentation => 'total number of replicant jobs (not counting the hub)',
);

has rid => (
    is => 'rw',
    isa => 'Int',
    documentation => 'Replicant ID, number between zero (for hub) and the number of jobs',
);

has message_board => (
    is => 'rw',
    documentation => 'message board shared by the hub and all replicants',
);

sub BUILD {
    my ( $self ) = @_;


    if ( $ENV{REPLICATOR_WORKDIR} ) {
        $self->_initialize_replicant();
    }

    else {
        $self->_initialize_hub();
    }
}


sub _initialize_hub {
    my ( $self ) = @_;

    $self->set_rid(0);

    # STEP 1 - create working directory for the replicator
    if ( not $self->workdir ) {
        my $counter;
        my $directory_prefix;
        my @existing_dirs;

        # search for the first unoccupied directory prefix
        do {
            $counter++;
            $directory_prefix = sprintf $self->path."/%03d_replicator_", $counter;
            @existing_dirs = glob "$directory_prefix*";
        }
            while (@existing_dirs);

        my $directory = tempdir "${directory_prefix}XXXXX" or log_fatal($!);
        $self->set_workdir($directory);
        log_info "Working directory $directory created";
    }

    # STEP 2 - create message board
    $self->set_message_board(
        Treex::Tool::Parallel::MessageBoard->new(
            current => 1,
            path => $self->workdir,
            sharers => $self->jobs + 1,
        )
      );

    # STEP 3 - create bash script for jobs
    mkdir $self->workdir."/scripts" or log_fatal $!;
    foreach my $jobnumber (1..$self->jobs) {


    }

    # STEP 4 - send the jobs to the cluster



}


sub _initialize_replicant {
    my $self = shift;

    # STEP 1 - detect working directory
    $self->set_workdir($ENV{REPLICATOR_WORKDIR});

    # STEP 2 - create message board contact
    my ($message_board_dir) = glob $self->workdir/."*_message_board_*";

    $self->set_message_board(
        Treex::Tool::Parallel::MessageBoard->new(
            current => $self->rid+1,
            workdir => $message_board_dir,
            sharers => $self->jobs + 1,
        )
      );

}


sub synchronize {
    my $self = shift;

}

sub is_hub {
    my $self = shift;
    return $self->rid == 0;
}




1;
