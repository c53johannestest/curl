#!/usr/bin/env perl
use strict;
use warnings;
use IO::Socket::INET;
use IO::Socket::SSL;
use URI;

# Usage message
if (@ARGV < 1) {
    die <<"USAGE";
Usage:
  $0 <url> [data] [header1:value1] [header2:value2] ...

Examples:
  $0 https://example.com/
  $0 https://httpbin.org/post '{"name":"alice"}' 'Content-Type:application/json' 'Authorization:Bearer token'
USAGE
}

# Parse args
my $url   = shift @ARGV;
my $data  = '';
my @headers;

# If next arg looks like JSON or has '=', assume it's POST data
if (@ARGV && $ARGV[0] !~ /^[A-Za-z0-9_-]+:/) {
    $data = shift @ARGV;
}

@headers = @ARGV;  # remaining args as headers

# Parse URL
my $uri    = URI->new($url);
my $scheme = $uri->scheme // 'http';
my $host   = $uri->host   or die "Invalid URL\n";
my $port   = $uri->port || ($scheme eq 'https' ? 443 : 80);
my $path   = $uri->path_query || '/';

# Determine method
my $method = $data ? 'POST' : 'GET';

# Open socket
my $sock;
if ($scheme eq 'https') {
    $sock = IO::Socket::SSL->new(
        PeerHost        => $host,
        PeerPort        => $port,
        SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(),
        Timeout         => 10,
    ) or die "SSL connection failed: $SSL_ERROR\n";
} else {
    $sock = IO::Socket::INET->new(
        PeerHost => $host,
        PeerPort => $port,
        Timeout  => 10,
    ) or die "Connection failed: $!\n";
}

# Send request
print $sock "$method $path HTTP/1.0\r\n";
print $sock "Host: $host\r\n";
print $sock "User-Agent: simple-perl/1.0\r\n";

# Apply custom headers
for my $h (@headers) {
    $h =~ s/^\s+|\s+$//g;
    next unless $h =~ /^([\w-]+):(.*)$/;
    my ($key, $val) = ($1, $2);
    $val =~ s/^\s+//;
    print $sock "$key: $val\r\n";
}

# Add Content-Length automatically for POST
if ($method eq 'POST') {
    my $len = length($data);
    # Add default Content-Type if user didn't specify one
    my $has_ct = grep { /^content-type:/i } @headers;
    print $sock "Content-Type: application/x-www-form-urlencoded\r\n" unless $has_ct;
    print $sock "Content-Length: $len\r\n";
}

print $sock "Connection: close\r\n\r\n";

# Send body
print $sock $data if $method eq 'POST';

# Print response
while (my $line = <$sock>) {
    print $line;
}

close $sock;
