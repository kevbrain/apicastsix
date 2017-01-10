# Custom Config

Sometimes you might require injecting custom nginx configuration into the gateway for customization. For example to add another server block to handle some routing. This **does not override existing configuration**. So the gateway will work as usual + your extra configuration.

That can be done very easily just with mounting a volume inside `sites.d` folder in the container:

```shell
docker run --publish 8080:8080 --volume $(pwd)/echo.conf:/opt/app/sites.d/echo.conf --env THREESCALE_PORTAL_ENDPOINT=http://portal.example.com quay.io/3scale/apicast:master
```

And then try a request:

```shell
curl localhost:8080 -H 'Host: echo' -X 'POST'
```

And you should see:

```
POST / HTTP/1.1
Host: echo
User-Agent: curl/7.49.1
Accept: */*
```

