# Why V2?

3scale provided downloadable NGINX configuration for many years and it worked great for our customers. However, some things could be improved.

## Splitting code and configuration

When NGINX configuration is generated from the Admin Portal, it has all the configuration embedded.
That means changes to the code will result in conflicts when configuration changes and needs to be regenerated.

Splitting code and configuration makes the code shareable. Now everyone can run the same code and just download new configuration (in JSON format) when needed. That also allows doing customizations to the code without worrying about configs when new configuration needs to be aplied. The configuration is just JSON file.

That also allows contribuing those customizations back the the project, so they can be used by everyone.
All code is open-source on GitHub.

## Testing

Splitting code and configuration allows thorough testing of each component individually. We are trying hard to cover every feature and every fix by a regression test. 

Using wonderful [Test::Nginx](http://search.cpan.org/~agent/Test-Nginx/lib/Test/Nginx/Socket.pm) framework for high level integration tests allows us to run every test several times in random order to ensure there are no random failures.

Low level unit testing is done in Lua testing framework [busted](https://olivinelabs.com/busted/). That allows us to run low level tests for edge cases easily and run them in isolation.

## Modules

We would like to make proxy modular, so you can load a plugin that adds some behaviour. 