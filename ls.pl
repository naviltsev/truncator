#!/usr/bin/env perl

use Mojolicious::Lite;
use MongoDB;
use MongoDB::OID;
use Data::Dumper;

my $mode = app->mode || 'development';
my $config = plugin json_config => {
    file => "config." . $mode . ".json",
};

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
            created_at => time(),
        });
    }
    
    $self->stash( shortened_url => $short );
} => 'index';

get '/last' => sub {
    my $self = shift;
    
    my $count = $self->param('count');
    my $cursor = $mongo_coll->query->sort( { created_at => -1 } )->limit( 10 );

    $self->stash( mongo_cursor => $cursor );
    $self->render();
    
    return;
} => 'last';

get '/:href' => sub {
    my $self = shift;
    my $href = $self->param('href');
    my $full;
    
    return if $href eq 'favicon';

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
<div class="navigation">
    <span class="links">
        <a href="<%= url_for 'last' %>">Last 10 truncates</a>
    </span>
</div>

<div class="link-div">    
    <form method="POST">
        <span class="name">
            <input class="link" type="text" name="href" id="href" />
        </span>
        <span class="submit">
            <input type="submit" value="Truncate!" name="submit" id="submit" />
        </span>
    </form>
    
    <% if (my $error = stash 'error') { %>
        <p class="error"><%= $error %></p>
    <% } %>
    <% if (my $url = stash 'shortened_url') { %>
        <p class="shortened-url"><b>http://<%= $config->{hostname} %>/<%= $url %></b></p>
    <% } %>
    
    <script type="text/javascript">
        document.getElementById("href").focus();
    </script>
</div>

@@ last.html.ep
% layout 'default';
<div class="navigation">
    <span class="links">
        <a href="<%= url_for '/' %>">Back</a>
    </span>
</div>

<div class="last-added">
    <% my $cursor = stash 'mongo_cursor'; %>
    <% my $counter = 1; %>
    <table class="last-added">
        <tr><td class="header" colspan="2">10 recent truncated URLs</td></tr>
        <% while( my $current = $cursor->next ) { %>
            <% my $class = $counter % 2 ? "odd" : "even"; %>
            <tr>
                <td class="<%= $class %>">
                    <a href="<%= $current->{full} %>"><%= $current->{full} %></a>
                </td>
                <td class="<%= $class %>">
                    <a href="http://<%= $config->{hostname} %>/<%= $current->{short} %>">http://<%= $config->{hostname} %>/<%= $current->{short} %></a>
                </td> 
            </tr>
            <% $counter++; %>
        <% } %>
    </table>
</div>

@@ layouts/default.html.ep
<style type="text/css">
    body {
        font: normal 13px/100% Verdana, Tahoma, sans-serif;
    }
    input {
        margin: auto;
        padding: 9px;
        border: solid 1px #a1a1a1;
        outline: 0;
        width: 680px;
        font: normal 13px/100% Verdana, Tahoma, sans-serif;
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
        font-weight: bold;
        color: red;
        text-align: center;
    }
    
    .shortened-url {
        text-align: center;
        color: #617798;
    }
    
    div.link-div {
        width: 800px;
        height: 50px;
        position: absolute;
        left: 50%;
        top: 50%;
        margin: -25px 0 0 -400px;
    }
    
    table.last-added {
        background: 0;
        width: 800px;
        height:300px;
        position: absolute;
        left: 50%;
        top: 50%;
        margin: -150px 0 0 -450px;
    }
    
    .last-added a {
        color: #617798;
        text-decoration: none;
    }
    
    td.header {
        font-weight: bold;
        text-align: center;
        padding: 10px;
        background: #ccc;
        color: #617798;
    }
        
    td.odd {
        background: #eee;
        vertical-align: top;
    }
    
    td.even {
        background: #ddd;
        vertical-align: top;
    }
    
    .links a {
        color: #617798;
        text-decoration: none;
    }
    
</style>

<!doctype html>
<html>
    <head><title>Truncator!</title></head>
    <body><%== content %></body>
</html>
