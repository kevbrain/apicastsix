use lib 't';
use Test::APIcast::Blackbox 'no_plan';

BEGIN {
    $ENV{TEST_NGINX_MANAGEMENT_SERVER_NAME} = 'management';
}

env_to_apicast(
    'APICAST_CONFIGURATION_LOADER' => 'test',
    'APICAST_POLICY_LOAD_PATH' => "$ENV{PWD}/t/fixtures/policies_endpoint_test/policies"
);

# Converts what's in the 'expected_json' block and the body to JSON and
# compares them. Raises and error when they do not match.
add_response_body_check(sub {
    my ($block, $body) = @_;

    use JSON;
    use Data::Compare;

    my $h1 = JSON->new->utf8->decode($body);
    my $h2 = JSON->new->utf8->decode($block->expected_json);
    my $c = Data::Compare->new($h1, $h2);
    if (!$c->Cmp) {
        bail_out "JSON returned does not match the expected one.";
    }

});

run_tests();

__DATA__

=== TEST 1: GET /policies
Check that the endpoint returns the manifests of all the built-in policies plus
the one in paths specified via config.
We have a directory with policies in 't/fixtures'. There are 2 policies there,
a valid one (example1), and one where the version specified in the manifest and
the one in the policy directory do not match (example2). We need to check that
the later is not returned.
--- request
GET /policies
--- more_headers
Host: management
--- response_headers
Content-Type: application/json; charset=utf-8
--- expected_json eval
use Cwd;
my $dir = getcwd();
my $cmd = "script/get_built_in_policy_manifests.sh $dir/t/fixtures/policies_endpoint_test/policies/example1";
`$cmd`
--- error_code: 200
--- no_error_log
[error]
