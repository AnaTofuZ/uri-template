package URI::Template;

use strict;
use warnings;

our $VERSION = '0.10';

use URI;
use URI::Escape ();
use overload '""' => \&as_string;

my $unsafe = q(^A-Za-z0-9\-_.~!\$\&'()*+,;=:/?\[\]#@);

=head1 NAME

URI::Template - Object for handling URI templates

=head1 SYNOPSIS

    use URI::Template;
    my $template = URI::Template->new( 'http://example.com/{x}' );
    my $uri      = $template->process( x => 'y' );
    # uri is a URI object with value 'http://example.com/y'

    my %result = $template->deparse( $uri );
    # %result is ( x => 'y' )

=head1 DESCRIPTION

This is an initial attempt to provide a wrapper around URI templates
as described at http://www.ietf.org/internet-drafts/draft-gregorio-uritemplate-01.txt

=head1 INSTALLATION

    perl Makefile.PL
    make
    make test
    make install

=head1 METHODS

=head2 new( $template )

Creates a new L<URI::Template> instance with the template passed in
as the first parameter.

=cut

sub new {
    my $class = shift;
    my $templ = shift || die 'No template provided';
    my $self  = bless { template => $templ }, $class;

    return $self;
}

=head2 as_string( )

Returns the original template string. Also used when the object is
stringified.

=cut

sub as_string {
    return $_[ 0 ]->{ template };
}

=head2 variables( )

Returns an array of unique variable names found in the template.
NB: they are returned in random order.

=cut

sub variables {
    my $self = shift;
    my %vars = map { $_ => 1 } $self->all_variables;
    return keys %vars;
}

=head2 all_variables( )

Returns an array of variable names found as they appear in template --
in order, duplicates included.

=cut

sub all_variables {
    my $self = shift;
    my @vars = $self->as_string =~ /{(.+?)}/g;
    return @vars;
}

=head2 process( %vars|\@values )

Given a list of key-value pairs or an array ref of values (for
positional substitution), it will URI escape the values and
substitute them in to the template. Returns a URI object.

=cut

sub process {
    my $self = shift;
    return URI->new( $self->process_to_string( @_ ) );
}

=head2 process_to_string( %vars|\@values )

Processes input like the C<process> method, but doesn't
inflate the result to a URI object.

=cut

sub process_to_string {
    my $self = shift;

    if( ref $_[ 0 ] ) {
        return $self->_process_by_position( @_ );
    }
    else {
        return $self->_process_by_key( @_ );
    }
}

sub _process_by_key {
    my $self   = shift;
    my @vars   = $self->variables;
    my %params = @_;
    my $uri    = $self->as_string;

    # fix undef vals
    for my $var ( @vars ) {
        $params{ $var } = defined $params{ $var }
            ? URI::Escape::uri_escape( $params{ $var }, $unsafe )
            : '';
    }

    my $regex = '\{(' . join( '|', map quotemeta, @vars ) . ')\}';
    $uri =~ s/$regex/$params{$1}/eg;

    return $uri;
}

sub _process_by_position {
    my $self   = shift;
    my @params = @{ $_[ 0 ] };

    my $uri = $self->as_string;

    $uri =~ s/{(.+?)}/@params
        ? defined $params[ 0 ]
            ? URI::Escape::uri_escape( shift @params, $unsafe )
            : ''
        : ''/eg;

    return $uri;
}

=head2 deparse( $uri )

Does some rudimentary deparsing of a uri based on the current template.
Returns a hash with the extracted values.

=cut

sub deparse {
    my $self = shift;
    my $uri  = shift;

    if( !$self->{ deparse_re } ) {
       my $templ = $self->as_string;
       $self->{ vars_list } = [ $templ =~ /{(.+?)}/g ];
       $templ =~ s/{.+?}/(.+?)/g;
       $self->{ deparse_re } = qr/$templ/;
    }

    my @matches = $uri =~ $self->{ deparse_re };

    my %results;
    @results{ @{ $self->{ vars_list } } } = @matches;
    return %results;
}

=head1 AUTHOR

Brian Cassidy E<lt>bricas@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Brian Cassidy

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

1;
