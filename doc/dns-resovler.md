# DNS Resolver 

APIcast ships with own DNS resolver implemented in Lua.

## Motivation

Current nginx resolver has some issues like that it does not support multiple DNS servers properly.
For example on OpenShift there are two DNS servers and one search path. Nginx is not able to properly resolve internal DNS names.

Also we like to use nginx facilities for load balancing and proxying. That means we have to use `balancer_by_lua` directive which can set the load balancer. But it has to set it to the IP address, not the DNS name. So we have to resolve that DNS name into IP address and there is no API exposed in nginx to do that.

## Requirements

Our DNS resolver should meet following criteria:

* caching for duration of TTL
* resolve A and CNAME records
* using stale cache when TTL expires and cache can't be updated
* many parallel requests to one worker result in one query
* connect to multiple DNS servers in parallel
* working search scope

## Scenarios

### Low traffic

A request is made to APIcast and DNS cache is updated. Then there is no request for TTL of that record and another request is made after that record expires. First request after expired TTL is going to make new query. Other requests that arrive before that query is finished are going to use stale cache (if it is in the cache as it is LRU).

### High traffic (on boot)

1000 requests are made in the same time. If there is no cache all the requests are going to git the DNS server which should de-duplicate queries. We rely on dnsmasq for now.

### High traffic (with cache)

With constant traffic 1000 requests per second when the DNS cache expires the first request is going to refresh the query but until it is finished stale cache is going to get used.

## Design

Using OpenResty's `lua-resty-dns` we can connect to any DNS server and implement our own resolver.

DNS resolver caches each record individually and fetches it from the cache recursively. That allows us to have layers of cache and fill just the missing layers. Example: CNAME (TTL 3600) -> CNAME (TTL 360) -> A (TTL 60) will just query the A record when it expires.

Querying multiple nameservers in parallel is accomplished by using "light thread". The first nameserver that responds is used.

De-duplicating queries is achieved by using dnsmasq running in the same container. 

Search scope defined in `/etc/resolv.conf` is evaluted one by one until matching record is returned. This could be optimized by executing all queries in parallel. But this is also improved by using dnsmasq which is going to search the scope on the first query so APIcast does not have to.

Following rules apply to handle scenarios described above:

* When cache is missing query goes to DNS server. It is responsibiity of the deployment to provide local caching dns server.
* When cache is stale, first request is going to refresh the query but all others use stale cache until the cache is updated.
* If record can't be updated, use stale cache for unlimited time, but try to recover.

This has one drawback: in low traffic scenario, the first requests after some time can hit wrong server before the cache is updated.

