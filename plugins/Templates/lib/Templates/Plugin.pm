package Templates::Plugin;

use strict;

sub _hdlr_templates {
    my ( $ctx, $args, $cond ) = @_;
    my %terms;
    my %params;
    unless ( $args->{ blog_id } || $args->{ include_blogs } || $args->{ exclude_blogs } ) {
        $args->{ include_blogs } = $ctx->stash( 'include_blogs' );
        $args->{ exclude_blogs } = $ctx->stash( 'exclude_blogs' );
        $args->{ blog_ids } = $ctx->stash( 'blog_ids' );
    }
    my $incl = $args->{ include_blogs };
    if ( $incl && $incl eq 'all' ) {} else {
        my ( %blog_terms, %blog_args );
        $ctx->set_blog_load_context( $args, \%blog_terms, \%blog_args ) or return $ctx->error( $ctx->errstr );
        my @blog_ids = $blog_terms{ blog_id };
        return '' if ! @blog_ids;
        $terms{ blog_id } = \@blog_ids;
    }
    my $type = $args->{ type };
    my $build_type = $args->{ build_type };
    my $include_backup = $args->{ include_backup };
    my $not_template_id = $args->{ not_template_id };
    if ( $type ) {
        $terms{ type } = $type;
    } else {
        if (! $include_backup ) {
            $terms{ type } = { 'not' => 'backup' };
        }
    }
    if ( $build_type ) {
        $terms{ build_type } = $build_type;
    }
    if ( $not_template_id ) {
        $terms{ id } = { 'not' => $not_template_id };
    }
    $params{ 'sort' } = 'type';
    $params{ direction } = 'ascend';
    if ( $type && $type eq 'index' ) {
        if ( $args->{ html } ) {
            $terms{ outfile } = { 'like' => '%html' };
        }
    }
    my @templates = MT->model( 'template' )->load( \%terms, \%params );
    my $tokens = $ctx->stash( 'tokens' );
    my $builder = $ctx->stash( 'builder' );
    my $i = 0;
    my $res = '';
    my $odd = 1;
    my $even = 0;
    for my $template ( @templates ) {
        my $column = $template->column_names;
        for my $col ( @$column ) {
            $ctx->{ __stash }->{ vars }->{ 'template_' . $col } = $template->$col;
        }
        local $ctx->{ __stash }->{ vars }->{ template_name } = $template->name;
        local $ctx->{ __stash }->{ vars }->{ __first__ } = 1 if ( $i == 0 );
        local $ctx->{ __stash }->{ vars }->{ __counter__ } = $i + 1;
        local $ctx->{ __stash }->{ vars }->{ __odd__ } = $odd;
        local $ctx->{ __stash }->{ vars }->{ __even__ } = $even;
        local $ctx->{ __stash }->{ vars }->{ __last__ } = 1 if ( !defined( $templates[ $i + 1 ] ) );
        my $out = $builder->build( $ctx, $tokens, {
            %$cond,
            'templatesheader' => $i == 0,
            'templatesfooter' => !defined( $templates[ $i + 1 ] ),
        } );
        if ( !defined( $out ) ) { return $ctx->error( $builder->errstr ) };
        $res .= $out;
        if ( $odd == 1 ) { $odd = 0 } else { $odd = 1 };
        if ( $even == 1 ) { $even = 0 } else { $even = 1 };
        $i++;
    }
    $res;
}

sub _hdlr_pass_tokens {
    my ( $ctx, $args, $cond ) = @_;
    $ctx->stash( 'builder' )->build( $ctx, $ctx->stash( 'tokens' ), $cond );
}

1;