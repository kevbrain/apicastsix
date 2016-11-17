# APIcast v2 installation

This document explains how to install and run APIcast v2 on a clean operating system.

## Installation on CentOS

### Install OpenResty and dependencies

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

APIcast v2 uses LuaRocks for managing Lua dependencies. As it is not in the standard Yum repositories, you must first enable the [EPEL](https://fedoraproject.org/wiki/EPEL) (Extra Packages for Enterprise Linux) package repository with the following command:

```shell
sudo yum install epel-release
```

Install LuaRocks:
```shell
sudo yum install luarocks
```

If you are using OAuth authentication method, you will also need to install Redis. This can be done with `sudo yum install redis` command (note that you will need the [EPEL](https://fedoraproject.org/wiki/EPEL) for this).

### Install and run APIcast v2

To use the upstream project, you can check out the [APIcast GitHub repository](https://github.com/3scale/apicast).

```shell
sudo yum install git
git checkout https://github.com/3scale/apicast.git
cd apicast
```

You can see all the APIcast releases on the [releases page](https://github.com/3scale/apicast/releases). Use the tags to checkout the vesrion you want to use, for example:

```shell
git checkout tags/v2.0.0-beta1
```

Alternatively, you can stay on the latest development branch (`v2`).

Install all the dependencies:

```shell
sudo luarocks make apicast/*.rockspec --tree /usr/local/openresty/luajit
```

Run APIcast v2 on OpenResty:

```shell
sudo THREESCALE_PORTAL_ENDPOINT=https://<access-token>@<admin-domain>.3scale.net bin/apicast
```

This command will start APIcast v2 and download the latest API gateway configuration from the 3scale admin portal.
For other configuration options refer to the [README](README.md).

