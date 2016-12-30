# APIcast v2 installation on CentOS

This document explains how to install and run APIcast v2 on a clean CentOS.

## Install OpenResty and dependencies

OpenResty provides official pre-built packages for CentOS, the latest installation instructions are provided in [OpenResty documentation](https://openresty.org/en/linux-packages.html).

You will need to create a file `/etc/yum.repos.d/OpenResty.repo` with the following content:

```
[openresty]
name=Official OpenResty Repository
baseurl=https://copr-be.cloud.fedoraproject.org/results/openresty/openresty/epel-$releasever-$basearch/
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://copr-be.cloud.fedoraproject.org/results/openresty/openresty/pubkey.gpg
enabled=1
enabled_metadata=1
```

Install OpenResty and the `resty` command-line utility, which is required for APIcast v2:

```shell
sudo yum install openresty openresty-resty
```
You can learn more about these and other OpenResty packages in [OpenResty documentation](https://openresty.org/en/rpm-packages.html).

APIcast v2 uses LuaRocks for managing Lua dependencies. As it is not in the standard Yum repositories, you must first enable the [EPEL](https://fedoraproject.org/wiki/EPEL) (Extra Packages for Enterprise Linux) package repository with the following command:

```shell
sudo yum install epel-release
```

Install LuaRocks:
```shell
sudo yum install luarocks
```

If you are using OAuth authentication method, you will also need to install Redis. This can be done with `sudo yum install redis` command (note that you will need the [EPEL](https://fedoraproject.org/wiki/EPEL) for this).

## Install and run APIcast v2

To use the latest APIcast version, you can check out the `v2` branch of the [APIcast GitHub repository](https://github.com/3scale/apicast).

If you want to use a specific version of APIcast, check the APIcast [releases page](https://github.com/3scale/apicast/releases). You can either download the source code from there, or checkout a specific tag with `git`, for example:

```shell
git checkout tags/v2.0.0-rc1
```

Go to the APIcast directory, that you checked out with git or extracted from the downloaded archive.

Install all the dependencies:

```shell
sudo luarocks make apicast/*.rockspec --tree /usr/local/openresty/luajit
```

Run APIcast v2 on OpenResty:

```shell
THREESCALE_PORTAL_ENDPOINT=https://<access-token>@<admin-domain>.3scale.net bin/apicast
```

This command will start APIcast v2 and download the latest API gateway configuration from the 3scale admin portal.

`bin/apicast` executable accepts a number of options, you can check them out by running:

```shell
bin/apicast -h
```

Additional parameters can be specified using environment variables.

Example:
```shell
APICAST_LOG_FILE=logs/error.log bin/apicast -c config.json -d -v -v -v
```
The above command will load the APIcast using the configuration file `config.json`, will run as daemon (`-d` option), and the error log will be at `debug` level (`-v -v -v`) and will be written to the file `logs/error.log` inside the directory `apicast` (the *prefix* directory).
