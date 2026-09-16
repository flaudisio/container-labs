# gatus-consul

This is a proof of concept (PoC) image to simulate a cross-network monitoring environment by using:

- [Consul](https://developer.hashicorp.com/consul) for [service discovery](https://developer.hashicorp.com/consul/docs/concepts/service-discovery)
- [Consul Template](https://github.com/hashicorp/consul-template) for automatic configuration updates
- [Gatus](https://github.com/TwiN/gatus) to provide a status page

## How it works

The `gatus-consul` image uses [s6-overlay](https://github.com/just-containers/s6-overlay) to run the following processes
in a single container:

- [Consul agent](https://developer.hashicorp.com/consul/docs/agent) to manage the Gatus [service](https://developer.hashicorp.com/consul/docs/services/usage/define-services)
  [registration](https://developer.hashicorp.com/consul/docs/services/usage/register-services-checks) in the Consul server;
- [Consul Template](https://github.com/hashicorp/consul-template) to ensure the Gatus' configuration file is updated;
- [Gatus](https://github.com/TwiN/gatus) for monitoring all Gatus instances (including itself).

In a nutshell, every time a new Gatus container is started:

1. Consul agent [generates](gatus/s6-rc.d/consul-agent/run) a [service configuration file](https://developer.hashicorp.com/consul/docs/services/configuration/services-configuration-reference)
   for Gatus and registers it in the Consul server.
1. Consul Template detects the new service registration and automatically [updates](gatus/s6-rc.d/consul-template/run) the
   Gatus [configuration file](https://github.com/TwiN/gatus#configuration) on all running containers.
1. As Gatus supports reloading its configuration [on the fly](https://github.com/TwiN/gatus#reloading-configuration-on-the-fly),
   all Gatus instances automatically start to monitor the new service.

The same logic applies when stopping or destroying any Gatus container of the stack.

## Running the stack

1. Build the Gatus image:

    ```bash
    docker compose build gatus-01
    ```

1. Start the Consul Server:

    ```bash
    docker compose up -d consul-server
    ```

1. Start the first Gatus container:

    ```bash
    docker compose up -d gatus-01
    ```

   Its web UI should be available at http://localhost:18001 and its Consul service should be listed in
   http://localhost:8500/ui/dc1/services/gatus/instances.

1. Start the remaining containers:

    ```bash
    docker compose up -d gatus-02
    docker compose up -d gatus-03
    ```

   They should be available at http://localhost:18002, http://localhost:18003 and so on.
