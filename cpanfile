#!/usr/bin/env perl

# $ cpan install Carton
# $ carton install
test_requires 'Test::Nginx', '>= 0.26';
test_requires 'JSON::WebToken', '>= 0.10';
# This will likely fail on OSX unless the OpenSSL is linked as system library.
# Just drop carton and install it yourself.
# $ export PERL_MM_OPT='CCFLAGS="-I/usr/local/opt/openssl/include -L/usr/local/opt/openssl/lib"'
# $ cpan Crypt::OpenSSL::RSA
test_requires 'Crypt::OpenSSL::RSA', '>= 0.28';
