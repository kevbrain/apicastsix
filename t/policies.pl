use File::Spec::Functions qw(catfile);
use Cwd qw(abs_path);
use File::Basename; qw(basename);
use File::Find ();
use File::Slurp qw(read_file);
use JSON qw(from_json);
use Test::Deep;

our $policies = sub ($) {
    my $path = shift;

    my %policies = ();

    my $add_policy = sub {
        my $policy_name = shift;
        my $policy_manifest_path = shift;

        my @versions = $policies{$policy_name} || ();
        my $manifest = read_file($policy_manifest_path);
        my $json = decode_json($manifest);
        push @versions, $json;

        $policies{$policy_name} = \@versions;
    };

    my $builtin_policies = sub {


        if (/^apicast-policy\.json\z/s) {
            my $policy_name = basename($File::Find::dir);

            $add_policy->($policy_name, $File::Find::name);
        }
    };

    my $custom_policies = sub {
        if (/^apicast-policy\.json\z/s) {
            my $policy_dir = dirname($File::Find::dir);
            my $policy_name = basename($policy_dir);

            $add_policy->($policy_name, $File::Find::name);
        }
    };

    File::Find::find({wanted => \&$builtin_policies, no_chdir=>0 }, catfile($ENV{APICAST_DIR}, "src/apicast/policy"));

    if ($path) {
        File::Find::find({wanted => \&$custom_policies, no_chdir=>0 }, abs_path($path));
    }

    my %json = ('policies' => \%policies);

    return \%json;
};

our $expect_json = sub ($) {
    my ($block, $body) = @_;

    use JSON;

    my $expected_json = $block->expected_json;

    my $got = from_json($body);
    my $expected = from_json($expected_json);

    cmp_deeply(
        $got,
        $expected,
        "the body matches the expected JSON structure"
    );
};

add_response_body_check($expect_json);
