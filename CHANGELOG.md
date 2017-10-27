# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) 
and this project adheres to [Semantic Versioning](http://semver.org/).

## [3.1.0] - 2017-10-27
- 3.1.0-rc2 was considered final and became 3.1.0.

## [3.1.0-rc2] - 2017-09-29

### Fixed

- Request headers are not passed to the backend, preventing sending invalid Content-Type to the access token store endpoint [PR #433](https://github.com/3scale/apicast/pull/433)

## [3.1.0-rc1] - 2017-09-14

### Added

- Support for extending APIcast location block with snippets of nginx configuration [PR #407][https://github.com/3scale/apicast/pull/407]

### Fixed

- Crash on empty OIDC Issuer endpoint [PR #408](https://github.com/3scale/apicast/pull/408)
- Handle partial credentials [PR #409](https://github.com/3scale/apicast/pull/409)
- Crash when configuration endpoint was missing [PR #417](https://github.com/3scale/apicast/pull/417)
- Fix double queries to not fully qualified domains [PR #419](https://github.com/3scale/apicast/pull/419)
- Fix caching DNS queries with scope (like on OpenShift) [PR #420](https://github.com/3scale/apicast/pull/420)

### Changed

- `THREESCALE\_DEPLOYMENT\_ENV` defaults to `production` [PR #406](https://github.com/3scale/apicast/pull/406)
- OIDC is now used based on settings on the API Manager [PR #405](https://github.com/3scale/apicast/pull/405)
- No limit on body size from the client sent to the server [PR #410](https://github.com/3scale/apicast/pull/410)
- Print module loading errors only when it failed to load [PR #415](https://github.com/3scale/apicast/pull/415)
- `bin/busted` rewritten to support different working directories [PR #418](https://github.com/3scale/apicast/pull/418)
- dnsmasq started in docker will not forward queries without domain [PR #421](https://github.com/3scale/apicast/pull/421)

## [3.1.0-beta2] - 2017-08-21

### Added

- Ability to configure how to cache backend authorizations [PR #396](https://github.com/3scale/apicast/pull/396)

### Fixed

- [THREESCALE-281](https://issues.jboss.org/browse/THREESCALE-281) Not loading services when APICAST\_SERVICES is empty [PR #401](https://github.com/3scale/apicast/pull/401)

## [3.1.0-beta1] - 2017-07-21

### Fixed

- Fixed CVE-2017-7512 [PR #393](https://github.com/3scale/apicast/pull/392)

### Changed

- APIcast module `balancer` method now accepts optional balancer [PR #362](https://github.com/3scale/apicast/pull/362)
- Extracted lua-resty-url [PR #384](https://github.com/3scale/apicast/pull/384)
- Extracted lua-resty-env [PR #386](https://github.com/3scale/apicast/pull/386)
- Do not load all services when APICAST\_SERVICES is set [PR #388](https://github.com/3scale/apicast/pull/388)

### Added

- APIcast published to [luarocks.org](https://luarocks.org/modules/3scale/apicast) [PR #366](https://github.com/3scale/apicast/pull/366)
- Support for passing remote configuratio URL through the CLI [PR #389](https://github.com/3scale/apicast/pull/389)
- CLI flag -b to load configuration on boot [PR #389](https://github.com/3scale/apicast/pull/389)
- OIDC support [PR #382](https://github.com/3scale/apicast/pull/382)

### Removed

- Keycloak / RH SSO integration replaced with OIDC [PR #382](https://github.com/3scale/apicast/pull/382)

## [3.1.0-alpha1] - 2017-05-05

### Changed

- Bump OpenResty version to [1.11.2.3](https://github.com/3scale/s2i-openresty/releases/tag/1.11.2.3-1) [PR #359](https://github.com/3scale/apicast/pull/359) 
- Upgraded lua-resty-http and lua-resty-jwt [PR #361](https://github.com/3scale/apicast/pull/361)

### Added

- Experimental caching proxy to the http client [PR #357](https://github.com/3scale/apicast/pull/357)

### Changed

- Print better errors when module loading fails [PR #360](https://github.com/3scale/apicast/pull/360)

## [3.0.0] - 2017-04-04

### Added

- Support for loading configration from custom URL [PR #323](https://github.com/3scale/apicast/pull/323)
- Turn on SSL/TLS validation by `OPENSSL_VERIFY` environment variable [PR #332](https://github.com/3scale/apicast/pull/332)
- Load trusted CA chain certificates [PR #332](https://github.com/3scale/apicast/pull/332)
- Support HTTP Basic authentication for client credentials when authorizing with RH-SSO [PR #336](https://github.com/3scale/apicast/pull/336)
- Show more information about the error when the module load fails [PR #348](https://github.com/3scale/apicast/pull/348)

### Changed

- Use `RESOLVER` before falling back to `resolv.conf` [PR #324](https://github.com/3scale/apicast/pull/324)
- Improve error logging when failing to download configuration [PR #335](https://github.com/3scale/apicast/pull/325)
- Service hostnames are normalized to lower case [PR #336](https://github.com/3scale/apicast/pull/326)
- Don't attempt to perform post\_action when request was handled without authentication [PR #343](https://github.com/3scale/apicast/pull/343)
- Store authorization responses with a ttl, if sent [PR #341](https://github.com/3scale/apicast/pull/341)

### Fixed

- Do not return stale service configuration when new one is available [PR #333](https://github.com/3scale/apicast/pull/333)
- Memory leak in every request [PR #339](https://github.com/3scale/apicast/pull/339)
- Remove unnecessary code and comments [PR #344](https://github.com/3scale/apicast/pull/344)
- JWT expiry not taken into account in authorization response cache [PR #283](https://github.com/3scale/apicast/pull/283) / [Issue #309](https://github.com/3scale/apicast/issues/309) / Fixed by [PR #341](https://github.com/3scale/apicast/pull/341)
- Memory leak in round robin balancer [PR #345](https://github.com/3scale/apicast/pull/345)
- Error when trying to determine status of failed request when downloading configuration [PR #350](https://github.com/3scale/apicast/pull/350)

## [3.0.0-beta3] - 2017-03-20

### Changed

- Use per request configuration when cache is disabled [PR #289](https://github.com/3scale/apicast/pull/289)
- Automatically expose all environment variables starting with `APICAST_` or `THREESCALE_` to nginx [PR #292](https://github.com/3scale/apicast/pull/292)
- Error log to show why downloading configuration failed [PR #306](https://github.com/3scale/apicast/pull/306)

### Added

- Backend HTTP client that uses cosockets [PR #295](https://github.com/3scale/apicast/pull/295)
- Ability to customize main section of nginx configuration (and expose more env variables) [PR #292](https://github.com/3scale/apicast/pull/292)
- Ability to lock service to specific configuration version [PR #293](https://github.com/3scale/apicast/pull/292)
- Ability to use Redis DB and password via `REDIS_URL` [PR #303](https://github.com/3scale/apicast/pull/303)
- Ability to Authenticate against API using RHSSO and OpenID Connect [PR #283](https://github.com/3scale/apicast/pull/283)

### Fixed
- `http_ng` client supports auth passsed in the url, and default client options if the request options are missing for methods with body (POST, PUT, etc.) [PR #310](https://github.com/3scale/apicast/pull/310)
- Fixed lazy configuration loader to recover from failures [PR #313](https://github.com/3scale/apicast/pull/313)
- Fixed undefined variable `p` in post\_action [PR #316](https://github.com/3scale/apicast/pull/316)
- Fixed caching of negative ttl by dnsmasq [PR #318](https://github.com/3scale/apicast/pull/318)

### Removed

- Removed support for sending Request logs [PR #296](https://github.com/3scale/apicast/pull/296)
- Support for parallel DNS query [PR #311](https://github.com/3scale/apicast/pull/311)

### Known Issues

- JWT expiry not taken into account in authorization response cache [PR #283](https://github.com/3scale/apicast/pull/283) / [Issue #309](https://github.com/3scale/apicast/issues/309)

## [3.0.0-beta2] - 2017-03-08

### Fixed

- Reloading of configuration with every request when cache is disabled [PR #287](https://github.com/3scale/apicast/pull/287)
- Auth caching is not used when OAuth method is used [PR #304](https://github.com/3scale/apicast/pull/304)

## [3.0.0-beta1] - 2017-03-03

### Changed
- Lazy load DNS resolver to improve performance [PR #251](https://github.com/3scale/apicast/pull/251)
- Execute queries to all defined nameservers in parallel [PR #260](https://github.com/3scale/apicast/pull/260)
- `RESOLVER` ENV variable overrides all other nameservers detected from `/etc/resolv.conf` [PR #260](https://github.com/3scale/apicast/pull/260)
- Use stale DNS cache when there is a query in progress for that record [PR #260](https://github.com/3scale/apicast/pull/260)
- Bump s2i-openresty to 1.11.2.2-2 [PR #260](https://github.com/3scale/apicast/pull/260)
- Echo API on port 8081 listens accepts any Host [PR #268](https://github.com/3scale/apicast/pull/268)
- Always use DNS search scopes [PR #271](https://github.com/3scale/apicast/pull/271)
- Reduce use of global objects [PR #273](https://github.com/3scale/apicast/pull/273)
- Configuration is using LRU cache [PR #274](https://github.com/3scale/apicast/pull/274)
- Management API not opened by default [PR #276](https://github.com/3scale/apicast/pull/276)
- Management API returns ready status with no services [PR #]()

### Added

* Danger bot to check for consistency in Pull Requests [PR #265](https://github.com/3scale/apicast/pull/265)
* Start local caching DNS server in the container [PR #260](https://github.com/3scale/apicast/pull/260)
* Management API to show the DNS cache [PR #260](https://github.com/3scale/apicast/pull/260)
* Extract correct Host header from the backend endpoint when backend host not provided [PR #267](https://github.com/3scale/apicast/pull/267)
* `APICAST_CONFIGURATION_CACHE` environment variable [PR #270](https://github.com/3scale/apicast/pull/270)
* `APICAST_CONFIGURATION_LOADER` environment variable [PR #270](https://github.com/3scale/apicast/pull/270)

### Removed

* Support for downloading configuration via curl [PR #266](https://github.com/3scale/apicast/pull/266)
* `AUTO_UPDATE_INTERVAL` environment variable [PR #270](https://github.com/3scale/apicast/pull/270)
* `APICAST_RELOAD_CONFIG` environment variable [PR #270](https://github.com/3scale/apicast/pull/270)
* `APICAST_MISSING_CONFIGURATION` environment variable [PR #270](https://github.com/3scale/apicast/pull/270)

## [3.0.0-alpha2] - 2017-02-06

### Added
- A way to override backend endpoint [PR #248](https://github.com/3scale/apicast/pull/248)

### Changed
- Cache all calls to `os.getenv` via custom module [PR #231](https://github.com/3scale/apicast/pull/231)
- Bump s2i-openresty to 1.11.2.2-1 [PR #239](https://github.com/3scale/apicast/pull/239)
- Use resty-resolver over nginx resolver for HTTP [PR #237](https://github.com/3scale/apicast/pull/237)
- Use resty-resolver over nginx resolver for Redis [PR #237](https://github.com/3scale/apicast/pull/237)
- Internal change to reduce global state [PR #233](https://github.com/3scale/apicast/pull/233)

### Fixed
- [OAuth] Return correct state value back to client

### Removed
- Nginx resolver directive auto detection. Rely on internal DNS resolver [PR #237](https://github.com/3scale/apicast/pull/237)

## [3.0.0-alpha1] - 2017-01-16
### Added
- A CHANGELOG.md to track important changes
- User-Agent header with APIcast version and system information [PR #214](https://github.com/3scale/apicast/pull/214)
- Try to load configuration from V2 API [PR #193](https://github.com/3scale/apicast/pull/193)

### Changed
- Require openresty 1.11.2 [PR #194](https://github.com/3scale/apicast/pull/194)
- moved development from `v2` branch to `master` [PR #209](https://github.com/3scale/apicast/pull/209)
- `X-3scale-Debug` HTTP header now uses Service Token [PR #217](https://github.com/3scale/apicast/pull/217)

## [2.0.0] - 2016-11-29
### Changed
- Major rewrite using JSON configuration instead of code generation.

[Unreleased]: https://github.com/3scale/apicast/compare/v3.1.0-rc2...3.1-stable
[2.0.0]: https://github.com/3scale/apicast/compare/v0.2...v2.0.0
[3.0.0-alpha1]: https://github.com/3scale/apicast/compare/v2.0.0...v3.0.0-alpha1
[3.0.0-alpha2]: https://github.com/3scale/apicast/compare/v3.0.0-alpha1...v3.0.0-alpha2
[3.0.0-beta1]: https://github.com/3scale/apicast/compare/v3.0.0-alpha2...v3.0.0-beta1
[3.0.0-beta2]: https://github.com/3scale/apicast/compare/v3.0.0-beta1...v3.0.0-beta2
[3.0.0-beta3]: https://github.com/3scale/apicast/compare/v3.0.0-beta2...v3.0.0-beta3
[3.0.0]: https://github.com/3scale/apicast/compare/v3.0.0-beta3...v3.0.0
[3.1.0-alpha1]: https://github.com/3scale/apicast/compare/v3.0.0...v3.1.0-alpha1
[3.1.0-beta1]: https://github.com/3scale/apicast/compare/v3.1.0-alpha1...v3.1.0-beta1
[3.1.0-beta2]: https://github.com/3scale/apicast/compare/v3.1.0-beta1...v3.1.0-beta2
[3.1.0-rc1]: https://github.com/3scale/apicast/compare/v3.1.0-beta2...v3.1.0-rc1
[3.1.0-rc2]: https://github.com/3scale/apicast/compare/v3.1.0-rc1...v3.1.0-rc2
[3.1.0]: https://github.com/3scale/apicast/compare/v3.1.0-rc2...v3.1.0
