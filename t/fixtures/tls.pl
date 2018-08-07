use File::Slurp qw(read_file);

[
    [ "server.crt" => CORE::join('', read_file('t/fixtures/server.crt')) ],
    [ "server.key" => CORE::join('', read_file('t/fixtures/server.key')) ],
]
