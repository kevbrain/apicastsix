# Issue Reporting
When filing a new Issue:

- Please make clear in the subject what the issue is about.
- Include all the necessary information to be able to reproduce the issues, including Operating System and version, NGINX and OpenResty version, etc.
- Please do not include any confidential information (ids, keys, application secrets). If this is needed to reproduce and fix an issue then you may be contacted by email.


To fix any issue, we first need to reproduce it.
We also would like to write a test case to prevent the issue from reappearing in the future. Contributing failing a test case is also much appreciated.

For us to sucessfuly reproduce issue we need either

* failing test case using Test::Nginx (see folder [t/](../t)) 
* or minimal configuration and curl commands describing the http requests as steps to reproduce it.

## Minimal configuration

The whole configuration can be pretty big, but most of it can be ignored as will use some defaults. The minimal reasonable configuration is described as JSON schema in [schema.json](../schema.json). Examples of those configurations are in [examples/configuration/](../examples/configuration). You can download your configuration from the Admin Portal: `https://ACCOUNT-admin.3scale.net/admin/api/nginx/spec.json`. Then remove everything that does not concern your use case and remove all private information. Removing the `services.proxy.backend` (like in [multiservice.json example](../examples/configuration/multiservice.json)) entry will make it to to authorize every request for sake of testing.

## Running with custom configuration

When you download the configuration from your portal and customize it, you need to run the API gateway with that configuration. That is done via environment variable and mounting a file.

You'll need to run the API gateway locally, either in docker or by compiling Openresty yourself.

Run the docker container with custom configuration:

```shell
docker run --rm --publish-all --env THREESCALE_CONFIG_FILE=/config.json --volume $(pwd)/examples/configuration/multiservice.json:/config.json --name test-gateway-config quay.io/3scale/apicast:master
```

And send to that docker image against that configuration:

```shell
curl -v "http://$(docker port test-gateway-config 8080)/?user_key=value" -H 'Host: monitoring'
```

Locally you can start openresty by:

```shell
THREESCALE_CONFIG_FILE=examples/configuration/multiservice.json nginx -p . -c conf/nginx.conf -g 'daemon off;'
```

And send a request to it:

```shell
curl -v "http://127.0.0.1:8080/?user_key=value" -H "Host: your-service"
```

It is important to send proper Host header, as that is used to route between different services. It has to match `hosts` key in the configuration.

# Development
We will also consider contributions in the form of pull requests. Please follow the guidelines here to help your work get accepted.

These guideline is inspired by and based on the Kubernetes guide "[How to get faster PR Reviews](https://github.com/kubernetes/community/blob/master/contributors/devel/pull-requests.md#best-practices-for-faster-reviews)".

## Pull requests

### Process Summary
To submit a pull request :

1. Fork this repo, and clone that repo
2. Create a branch (`git checkout -b feature_x`)
3. Commit your changes with meaningful messages (`git add my/awesome/file.rb; git commit -m "Feature-X"`)
4. Push your changes to your fork (`git push origin feature_x`)
5. Open a Pull Request and provide a description of the contents of it

### Guideline Summary

1. Seek feedback early
2. Smaller PRs are better
3. Multiple small PRs are often better than multiple commits
4. Don't rename, reformat, comment, etc in the same PR
5. Comments matter
6. Tests are almost always required
7. Look for opportunities to generify
8. Fix feedback in a new commit

## Pull Request Guidelines
### 1. Seek feedback early

If you have any doubt at all about the usefulness of your feature or the design - make a proposal doc (in
docs) or a sketch PR (e.g. just skeleton code) or both. Write or code up just enough to express the idea and the design and why you made those choices, then
get feedback on this. Please include [proposal] in the PR title. Be clear about what type of feedback you are asking for. Now, if we ask you to change a bunch of facets of the design, you won't have to re-write it all.

### 2. Smaller PRs are better
A common problem that will delay PR review and merge is that your PR is too big. You've touched 39 files and have 8657 insertions. When your would-be reviewers pull up the diffs they run away - this PR is going to
take 4 hours to review and they don't have 4 hours right now.

Small PRs get reviewed faster and are more likely to be correct than big ones.
Let's face it - attention wanes over time. If your PR takes 60 minutes to review, I almost guarantee that the reviewer's eye for detail is not as keen in the last 30 minutes as it was in the first. This leads to multiple rounds of review when one might have sufficed. In some cases the review is delayed in its entirety by the need for a large contiguous block of time to sit and read your code.

Whenever possible, break up your PRs into multiple commits. Making a series of discrete commits is a powerful way to express the evolution of an idea or the
different ideas that make up a single feature. There's a balance to be struck, obviously. If your commits are too small they become more cumbersome to deal with. Strive to group logically distinct ideas into separate commits.

For example, if you found that Feature-X needed some "prefactoring" to fit in, make a commit that JUST does that prefactoring. Then make a new commit for Feature-X. Don't lump unrelated things together just because you didn't think about prefactoring. If you need to, fork a new branch, do the prefactoring there and send a PR for that. If you can explain why you are doing seemingly no-op work ("it makes the Feature-X change easier, I promise") we'll probably be OK with it.

Obviously, a PR with 25 commits is still very cumbersome to review, so use common sense.

### 3. Multiple small PRs are often better than multiple commits

If you can extract whole ideas from your PR and send those as PRs of their own, you can avoid the painful problem of continually rebasing.

Obviously, we want every PR to be useful on its own, so you'll have to use common sense in deciding what can be a PR vs. what should be a commit in a larger PR. Rule of thumb - if this commit or set of commits is directly related to Feature-X and nothing else, it should probably be part of the Feature-X PR. If you can plausibly imagine someone finding value in this commit outside of Feature-X, try it as a PR.

### 4. Don't rename, reformat, comment, etc in the same PR

Often, as you are implementing Feature-X, you find things that are just wrong.
Bad comments, poorly named functions, bad structure, weak type-safety. You should absolutely fix those things (or at least file issues, please) - but not
in this PR. See the above points - break unrelated changes out into different PRs or commits. Otherwise your diff will have WAY too many changes, and your
reviewer won't see the forest because of all the trees.

### 5. Comments matter

If you're writing code and you think there is any possible chance that someone might not understand why you did something (or that you won't remember what you yourself did), comment it. If you think there's something pretty obvious that we could follow up on, add a TODO. Many code-review comments are about this exact issue.

### 6. Tests are almost always required

Nothing is more frustrating than doing a review, only to find that the tests are inadequate or even entirely absent. Very few PRs can touch code and NOT touch
tests. If you don't know how to test Feature-X - ask!

### 7. Look for opportunities to generify

If you find yourself writing something that touches a lot of modules, think hard about the dependencies you are introducing between packages. Can some of what you're doing be made more generic and moved up and out of the Feature-X package?

Likewise if Feature-X is similar in form to Feature-W which was checked in last month and it happens to exactly duplicate some tricky stuff from Feature-W,
consider prefactoring core logic out and using it in both Feature-W and Feature-X. But do that in a different commit or PR, please.

### 8. Fix feedback in a new commit

Your reviewer has finally sent you some feedback on Feature-X. You make a bunch of changes and ... what?  You could patch those into your commits with git
"squash" or "fixup" logic.  But that makes your changes hard to verify. Unless your whole PR is pretty trivial, you should instead put your fixups into a new commit and re-push. Your reviewer can then look at that commit on its own - so much faster to review than starting over.

We might still ask you to clean up your commits at the very end, for the sake of a more readable history, but don't do this until asked, typically at the point where the PR would otherwise be tagged LGTM.

General squashing guidelines:

* Sausage => squash

  When there are several commits to fix bugs in the original commit(s), address reviewer feedback, etc. Really we only want to see the end state and commit
message for the whole PR.

* Layers => don't squash

  When there are independent changes layered upon each other to achieve a single goal.

A commit, as much as possible, should be a single logical change. Each commit should always have a good title line (<70 characters) and include an additional
description paragraph describing in more detail the change intended. Do not link pull requests by `#` in a commit description, because GitHub creates lots of
spam. Instead, reference other PRs via the PR your commit is in.
