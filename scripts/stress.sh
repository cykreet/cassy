#!/bin/bash
# gets a list of all tailscale ips (+ plus ip of the current host), then tries to connect to cassandra on each of them
# if it can, it runs cassandra-stress

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SELECTED_PROFILE="user"

TAILSCALE_AUTHKEY="tskey-auth-kHBHYDCmJ221CNTRL-jUszgszRzs5y7howVzZTs59mqcKxrhbi"
TAILSCALE_DEVICES=$(tailscale status --json | jq -r '.Peer[] | select(.Online == true) | .TailscaleIPs[0]')
SELF_IP=$(tailscale ip -4)
ALL_IPS="$TAILSCALE_DEVICES $SELF_IP"

POD_NAME="cassandra-stress"
CASSANDRA_NODES=""
CASSANDRA_PORT=9042

for ip in $ALL_IPS; do
	if [ -n "$ip" ]; then
		if timeout 3 bash -c "</dev/tcp/$ip/$CASSANDRA_PORT" 2>/dev/null; then
			echo "Discovered Cassandra node: $ip"
			if [ -z "$CASSANDRA_NODES" ]; then
				CASSANDRA_NODES="$ip:$CASSANDRA_PORT"
			else
				CASSANDRA_NODES="$CASSANDRA_NODES,$ip:$CASSANDRA_PORT"
			fi
		fi
	fi
done

if [ -z "$CASSANDRA_NODES" ]; then
	echo "No Cassandra nodes found"
	exit 1
fi

NODES=$CASSANDRA_NODES

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
spec:
  containers:
  - name: ${POD_NAME}
    image: cassandra:5
    command: ["/bin/bash", "-c"]
    args:
    - |
      IFS=',' read -ra NODES <<< "${NODES}"
      for node in "\${NODES[@]}"; do
        ip=\$(echo \$node | cut -d':' -f1)
        port=\$(echo \$node | cut -d':' -f2)
        echo "Testing connection to \$ip:\$port using cqlsh"
        
        for i in {1..30}; do
          if cqlsh --connect-timeout=5 \$ip \$port -e "describe keyspaces" 2>/dev/null; then
            echo "Connected to Cassandra at \$ip:\$port"
            break
          else
            echo "Attempt \$i: Could not connect to \$ip:\$port"
            sleep 2
          fi
          
          if [ \$i -eq 30 ]; then
            echo "ERROR: Failed to connect after 30 attempts"
            exit 1
          fi
        done
      done
      
      /opt/cassandra/tools/bin/cassandra-stress user profile=/profiles/${SELECTED_PROFILE}.yml duration=2m "ops(profile_lookup=1, profile_update=1)" -rate threads=50 -node ${NODES} -graph file=/tmp/results-${TIMESTAMP}.html -log
      sleep 300
    volumeMounts:
      - name: profiles
        mountPath: /profiles
  - name: tailscale
    image: tailscale/tailscale:latest
    securityContext:
      privileged: true
    command: ["/bin/sh", "-c"]
    args:
    - |
      tailscaled &
      sleep 5 &&
      tailscale up --authkey=${TAILSCALE_AUTHKEY} --hostname=$(hostname)
      sleep infinity
    volumeMounts:
    - name: tailscale-data
      mountPath: /var/lib/tailscale 
    env:
    - name: TS_STATE_DIR
      value: /var/lib/tailscale
  dnsPolicy: None
  dnsConfig:
    nameservers:
    - 100.100.100.100
  volumes:
  - name: tailscale-data
    emptyDir: {}
  - name: profiles
    configMap:
      name: profiles
      items:
        - key: user.yml
          path: user.yml
        - key: product.yml
          path: product.yml
EOF

kubectl wait --for=condition=ready pod/$POD_NAME --timeout=600s

timeout=5000
while [ $timeout -gt 0 ]; do
	if kubectl logs $POD_NAME 2>/dev/null | grep -q "END"; then
		break
	fi
	sleep 10
	((timeout-=10))
done

kubectl cp $POD_NAME:/tmp/results-$TIMESTAMP.html ./results-$TIMESTAMP.html
kubectl delete pod $POD_NAME
