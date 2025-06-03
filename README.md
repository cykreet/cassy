Cassandra multi-datacentre deployment to Kubernetes clusters on a Tailscale network.

# Cassandra Deployment

This project initially stemmed from a uni project for distribiuted database deployment, and although the obvious option should've been to throw together a quick MongoDB cluster Atlas and call it a day, I thought it'd be fun to try Cassandra instead (it kinda kicked my ass) *and* put it on Kubernetes with tailscale for node networking.

The most obvious issue I ran into pretty early on was getting static IPs from tailscale for seed nodes and passing them to all other nodes. Ideally you'd have 2 auth keys, one ephemeral, and one not (both reusable and automatically tagged), so seed nodes would connect with the non-ephemeral key and the rest would connect with the ephemeral key, this deployment will have to be modified to accomodate 2 different keys. Once the seed notes connect to tailscale for the first time, they should get assigned static IPs and those can be passed to the seed list (important that the tailscale sidecar pvc isn't deleted since tailscale will then re-assign new IPs).

After that, it seemed like everything should just work baesd on some other examples I've (mostly single-datacentre ones), but it didn't. Gossip connections kept returning `connection refused`, which I ended up boiling down to a `listening_address` and seed list issue: `localhost` or the pod IP can't be used for the listening address, since the container checks the seed list for the listening address to determine whether it's a seed or not, so the tailscale IP should be used for the listening address and broadcast address; the seed list should consist of IP-port pairs (default for port is `7000` for inter-node communication), which will be used to connect to the seed nodes. 

# Quick Setup

1. `kubectl create configmap cassandra-init-cql --from-file=data.cql=scripts/data.cql`
2. replace the secret in `cassandra/secrets/tailscale-secret.yml` with a base64 encoded ephemeral Tailscale auth key, then `kubectl apply -f cassandra/secrets/tailscale-secret.yml`
3. `kubectl apply -f cassandra/service.yml`
4. `kubectl apply -f cassandra/statefulset.yml`
5. `kubectl apply -f cassandra/init-job.yml`