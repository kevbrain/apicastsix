# Performance

There is a Vagrantfile with performance inspection tools like SystemTap.

```shell
vagrant up
vagrant ssh
```

APIcast is mounted into `/home/vagrant/app` so you can start it by:

```shell
cd app
bin/apicast
```

For profiling with stapxx it is recommended to start just one process and worker:

```shell
bin/apicast -m off -w 1 -c examples/configuration/echo.json  > /dev/null
```

Then by opening another terminal you can use vegeta to create traffic:

```shell
echo 'GET http://localhost:8080/?user_key=foo' | vegeta attack -rate=200 -duration=5m | vegeta report
```

And in another terminal you can create flamegraphs:

```shell
lj-lua-stacks.sxx  -x `pgrep openresty` --skip-badvars --arg time=30 | fix-lua-bt - | stackcollapse-stap.pl | flamegraph.pl > app/graph.svg
```