use File::Slurp qw(read_file);

[
    [ "server.crt" => CORE::join('', read_file('t/fixtures/CA/server.crt')) ],
    [ "server.key" => CORE::join('', read_file('t/fixtures/CA/server.key')) ],
    [ "client.crt" => CORE::join('', read_file('t/fixtures/CA/client.crt')) ],
    [ "client.key" => CORE::join('', read_file('t/fixtures/CA/client.key')) ],
]
