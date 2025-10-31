#!/usr/bin/env perl
use strict;
use warnings;
use IO::Socket::INET;
use IO::Socket::SSL;
use URI;

# Usage check
my $url = shift or die "Usage: $0 <http[s]://host/path>\n";

# Parse URL
my $uri = URI->new($url);
my $scheme = $uri->scheme // 'http';
my $host   = $uri->host   or die "Invalid URL\n";
my $port   = $uri->port || ($scheme eq 'https' ? 443 : 80);
my $path   = $uri->path_query || '/';

# Connect (SSL for https)
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
print $sock "GET $path HTTP/1.0\r\n";
print $sock "Host: $host\r\n";
print $sock "User-Agent: simple-perl/1.0\r\n";
print $sock "Connection: close\r\n\r\n";

# Print response
while (my $line = <$sock>) {
    print $line;
}

close $sock;
