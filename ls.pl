#!/usr/bin/env perl
package d;
use Data::Dumper;

sub log {
    my $message = shift;
    print STDERR "[DEBUG] $message\n";
    return;
}
1;

# =============================

package main;
use Mojolicious::Lite;
use MongoDB;
use MongoDB::OID;
use Data::Dumper;

# Prepare CouchDB
my $mongo_conn = MongoDB::Connection->new;
my $mongo_db = $mongo_conn->ls_project;
my $mongo_coll = $mongo_db->links;

sub generate {
    my @chars = ( "A" .. "Z", "a" .. "z", 0 .. 9 ); 
    return join("", @chars[ map { rand @chars } ( 1..8 ) ]);
}

# Routes
get '/' => 'index';

post '/' => sub {
    my $self = shift;
    my $href = $self->param('href');
    my $short;
    
    # $href =~ s/http\:\/\///g;

    # Check href is correct
    if( $href eq '' || $href !~ 'https?' ) {
        $self->stash( error => "Please enter correct URL");
        return;
    }
    
    my $cursor = $mongo_coll->find( { full => $href } );
    if( $cursor->count > 0 ) {
        my $link = $cursor->next;
        $short = $link->{short};
    } else {
        $short = generate;
        $mongo_coll->insert({
            full => $href,
            short => $short,
        });
    }
    
    $self->stash( shortened_url => $short );
} => 'index';


get '/:href' => sub {
    my $self = shift;
    my $href = $self->param('href');
    my $full;
    
    return if $href eq 'favicon';

    d::log( $href );
    my $cursor = $mongo_coll->find( { short => $href } );
    if( $cursor->count > 0 ) {
        my $link = $cursor->next;
        $full = $link->{full};
    }
    
    $self->redirect_to( "$full ");
};

app->start;




__DATA__

@@ index.html.ep
% layout 'default';
<div class="link-div">
    <% if (my $error = stash 'error') { %>
        <p class="error"><%= $error %></p>
    <% } %>
    <% if (my $url = stash 'shortened_url') { %>
        <p class="shortened-url"> Shortened URL is 
        <b>http://192.168.0.196:3000/<%= $url %></b></p>
    <% } %>

    <form method="POST">
        <span class="name">
            <input class="link" type="text" name="href" />
        </span>
        <span class="submit">
            <input type="submit" value="Truncate!" />
        </span>
    </form>
</div>

@@ layouts/default.html.ep
<style type="text/css">
    input {
        margin: auto;
        padding: 9px;
        border: solid 1px #e5e5e5;
        outline: 0;
        font: normal 13px/100% Verdana, Tahoma, sans-serif;
        width: 680px;
        background: #ffffff
    }
    
    input:hover {
        border-color: #c9c9c9;
    }
    
    .submit input {
        margin: auto;
        width: auto;
        padding: 9px 15px;
        background: #617798;
        border: 0;
        font-size: 14px;
        color: #ffffff;
    }
    
    .error {
        color: red;
        text-align: center;
    }
    
    .shortened-url {
        text-align: center;
    }
    
    div.link-div {
        width: 800px;
        height: 50px;
        position: absolute;
        left: 50%;
        top: 50%;
        margin: -25px 0 0 -400px;
    }
</style>
<!doctype html><html>
    <head><title>Link Shortener</title></head>
    <body><%== content %></body>
</html>
