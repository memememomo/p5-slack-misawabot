use Mojolicious::Lite;
use Mojo::UserAgent;

app->plugin(config => {
    file => app->home->rel_file('config.pl'),
    stash_key => 'config',
});

get '/' => sub {
    my $self = shift;
    my $url = $self->req->url->to_abs;
    $self->stash->{base_url} = $url->scheme . '://' . $url->host . ':' . $url->port;
    $self->render();
} => 'index';

post '/post' => sub {
    my $self = shift;

    my $image_id = $self->param('image_id');
    my $url = 'http://jigokuno.com/?eid='.$image_id;
    if (!post_misawa($url, $self->config->{Slack})) {
        $self->flash('message' => '投稿に失敗しました。');
    }

    $self->redirect_to('index');
} => 'post';

get '/bookmarklet' => sub {
    my $self = shift;

    my $url = $self->param('url');
    $self->stash->{message} = 'done.';
    if (!post_misawa($url)) {
        $self->stash->{message} = '投稿に失敗しました。';
    }

    $self->render();
} => 'bookmarklet';


sub post_misawa {
    my ($url, $slack) = @_;

    my $src = fetch_misawa($url);
    if ($src) {
        return submit_to_slack($url, $src, $slack)
    }

    return 0;
}

sub _build_ua {
    return Mojo::UserAgent->new->max_redirects(5);
}

sub fetch_misawa {
    my ($url) = @_;

    my $ua = _build_ua();

    my $tx = $ua->get($url);
    if (my $res = $tx->success) {
        my $src;
        $res->dom('.entry img.pict')->each(sub {
            my ($e) = @_;
            $src = $e->attrs('src');
        });
        return $src;
    }

    return undef;
}

sub submit_to_slack {
    my ($url, $src, $slack) = @_;

    my $api = 'https://slack.com/api/chat.postMessage';

    $slack->{text} = "from:$url\n" . $src;

    my $ua = _build_ua();

    my $tx = $ua->post($api, form => $slack);
    if (my $res = $tx->success) {
        return 1;
    }
    else {
        warn $res->error;
    }
    return 0;
}

app->start;
__DATA__

@@ index.html.ep
<html>
<head>
<meta charset="utf8">
<title>Slack Misawa</title>
</head>
<body>
<h1>Misawa Bot</h1>

<a href="http://jigokuno.com/" target="_blank">地獄のミサワの「女に惚れさす名言集」</a>

<h2>フォーム版</h2>
画像IDを入力して下さい。
<form action="<%= url_for('post') %>" method="post">
http://jigokuno.com/?eid=<input type="text" name="image_id" placeholder="1000">
<input type="submit" value="投稿">
</form>

<h2>Bookmarklet</h2>
<a href="javascript:(function(){var url = location.href; var redirect_url = '<%= $base_url %>/bookmarklet?url=' + encodeURIComponent(url); window.open(redirect_url,'_blank'); })();">misawa</a>

</body>
</html>

@@ bookmarklet.html.ep
<html>
<head>
<meta charset="utf8">
</head>
<script type="text/javascript">
setTimeout(function() { window.close(); }, 1000);
</script>
<body>
<%= $message %><br>
<input type="button" onclick="window.close()" value="閉じる">
</body>
</html>
