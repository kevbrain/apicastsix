our $dns = sub ($$$) {
  my ($host, $ip, $ttl) = @_;

  return sub {
    # Get DNS request ID from passed UDP datagram
    my $dns_id = unpack("n", shift);
    # Set name and encode it
    my $name = $host;
    $name =~ s/([^.]+)\.?/chr(length($1)) . $1/ge;
    $name .= "\0";
    my $s = '';
    $s .= pack("n", $dns_id);
    # DNS response flags, hardcoded
    # response, opcode, authoritative, truncated, recursion desired, recursion available, reserved
    my $flags = (1 << 15) + (0 << 11) + (1 << 10) + (0 << 9) + (1 << 8) + (1 << 7) + 0;
    $flags = pack("n", $flags);
    $s .= $flags;
    $s .= pack("nnnn", 1, 1, 0, 0);
    $s .= $name;
    $s .= pack("nn", 1, 1); # query class A

    # Set response address and pack it
    my @addr = split /\./, $ip;
    my $data = pack("CCCC", @addr);

    # pointer reference to the first name
    # $name = pack("n", 0b1100000000001100);

    # name + type A + class IN + TTL + length + data(ip)
    $s .= $name. pack("nnNn", 1, 1, $ttl || 0, 4) . $data;
    return $s;
  }
};
