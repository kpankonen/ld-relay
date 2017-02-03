LaunchDarkly Relay Proxy
=========================

What is it?
-----------

The LaunchDarkly Relay Proxy establishes a connection to the LaunchDarkly streaming API, then proxies that stream connection to multiple clients. 

The relay proxy lets a number of servers connect to a local stream instead of making a large number of outbound connections to `stream.launchdarkly.com`.

The relay proxy can be configured to proxy multiple environment streams, even across multiple projects.

Quick setup
-----------

1. Copy `ld-relay.conf` to `/etc/ld-relay.conf`, and edit to specify your port and LaunchDarkly API keys for each environment you wish to proxy.

2. If building from source, have `go` 1.6+ and `godep` installed, and run `godep go build`.

3. Run `ld-relay`.

4. Set `stream` to `true` in your application's LaunchDarkly SDK configuration. Set the `streamUri` parameter to the host and port of your relay proxy instance.

Configuration file format 
-------------------------

You can configure LDR to proxy as many environments as you want, even across different projects. You can also configure LDR to send periodic heartbeats to connected clients. This can be useful if you are load balancing LDR instances behind a proxy that times out HTTP connections (e.g. Elastic Load Balancers).

Here's an example configuration file that synchronizes four environments across two different projects (called Spree and Shopnify), and sends heartbeats every 15 seconds:

        [main]
        streamUri = "https://stream.launchdarkly.com"
        baseUri = "https://app.launchdarkly.com"
        exitOnError = false
        ignoreConnectionErrors = true
        heartbeatIntervalSecs = 15

        [environment "Spree Project Production"]
        apiKey = "SPREE_PROD_API_KEY"

        [environment "Spree Project Test"]
        apiKey = "SPREE_TEST_API_KEY"

        [environment "Shopnify Project Production"]
        apiKey = "SHOPNIFY_PROD_API_KEY"

        [environment "Shopnify Project Test"]
        apiKey = "SHOPNIFY_TEST_API_KEY"

Redis storage and daemon mode
-----------------------------

You can configure LDR to persist feature flag settings in Redis. This provides durability in case of (e.g.) a temporary network partition that prevents LDR from 
communicating with LaunchDarkly's servers.

Optionally, you can configure our SDKs to communicate directly to the Redis store. If you go this route, there is no need to put a load balancer in front of LDR-- we call this daemon mode. 

To set up LDR in this mode, provide a redis host and port, and supply a Redis key prefix for each environment in your configuration file:

        [redis]
        host = "localhost"
        port = 6379
        localTtl = 30000

        [main]
        ...

        [environment "Spree Project Production"]
        prefix = "ld:spree:production"
        apiKey = "SPREE_PROD_API_KEY"

        [environment "Spree Project Test"]
        prefix = "ld:spree:test"
        apiKey = "SPREE_TEST_API_KEY"

You can also configure an in-memory cache for the relay to use so that connections do not always hit redis. To do this, set the `localTtl` parameter in your `redis` configuration section to a number (in milliseconds). 

If you're not using a load balancer in front of LDR, you can configure your SDKs to connect to Redis directly by setting `use_ldd` mode to `true` in your SDK, and connecting to Redis with the same host and port in your SDK configuration.


Docker
-------

To build the ld-relay container:

        $ docker build -t ld-relay-build -f Dockerfile-build . # create the build container image
        $ docker run -v $(pwd):/build -t -i -e CGO_ENABLED=0 -e GOOS=linux ld-relay-build godep go build -a -installsuffix cgo -o ldr # create the ldr binary
        $ docker build -t ld-relay . # build the ld-relay container image
        $ docker rmi ld-relay-build # remove the build container image that is no longer needed

To run a single environment, without Redis:

        $ docker run --name ld-relay -e LD_ENV_test="sdk-test-apiKey" ld-relay

To run multiple environments, without Redis:

        $ docker run --name ld-relay -e LD_ENV_test="sdk-test-apiKey" -e LD_ENV_prod="sdk-prod-apiKey" ld-relay

To run a single environment, with Redis:

        $ docker run --name redis redis:alpine
        $ docker run --name ld-relay --link redis:redis -e LD_ENV_test="sdk-test-apiKey" ld-relay

To run multiple environment, with Redis:

        $ docker run --name redis redis:alpine
        $ docker run --name ld-relay --link redis:redis -e LD_ENV_test="sdk-test-apiKey" -e LD_PREFIX_test="ld:default:test" -e LD_ENV_prod="sdk-prod-apiKey" -e LD_PREFIX_prod="ld:default:prod" ld-relay


Docker Environment Variables
-------

`LD_ENV_${environment}`: At least one `LD_ENV_${environment}` variable is recommended.  The value should be the api key for that specific environment.  Multiple environments can be listed

`LD_PREFIX_${environment}`: This variable is optional.  Configures a Redis prefix for that specific environment.  Multiple environments can be listed

`USE_REDIS`: This variable is optional.  If set to 1, Redis configuration will be added

`REDIS_HOST`: This variable is optional.  Sets the hostname of the Redis server.  If linked to a redis container that sets `REDIS_PORT` to `tcp://172.17.0.2:6379`, `REDIS_HOST` will use this value as the default.  If not, the default value is `redis`

`REDIS_PORT`: This variable is optional.  Sets the port of the Redis server.  If linked to a redis container that sets `REDIS_PORT` to `REDIS_PORT=tcp://172.17.0.2:6379`, `REDIS_PORT` will use this value as the default.  If not, the defualt value is `6379`

`REDIS_TTL`: This variable is optional.  Sets the TTL in milliseconds, defaults to `30000`
