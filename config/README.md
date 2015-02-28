ceph-config
===========

This Dockerfile may be used to bootstrap a cluster or add the cluster configuration
to a new host. It uses etcd to store the cluster config. It is especially suitable
to setup ceph on CoreOS.

The following strategy is applied:

  * If a cluster configuration is available, it will be written to `/etc/ceph`
  * If no cluster configuration is available, it will be created. A lock mechanism 
    is used to allow concurrent deployment of multiple hosts.

## Usage 

To bootstrap a new cluster run:

`docker run -e MON_IP=192.168.101.50 -e MON_NAME=mymon -e CLUSTER=testing -v /etc/ceph:/etc/ceph ceph/config`

This will generate:

  *  `ceph.conf` 
  *  `ceph.client.admin.keyring` 
  *  `ceph.mon.keyring` 
  *  `monmap` 

Except the `monmap` the config will be stored in etcd under `/ceph-config/${CLUSTER}`. 

In case a configuration for the cluster is found, the configuration will be pulled
from etcd and written to `/etc/ceph`.

Multiple concurrent invocations will block until the first host finished to generate 
the configuration.

When run without `MON_IP` and `MON_NAME` it will not generate a config but block and 
wait until it becomes available. 

## Configuration

The following environment variables can be used to configure the bootstrapping:

  * `CLUSTER` is the name of the ceph cluster (defaults to: "ceph") 

Mandatory Configuration:
  * `MON_NAME` is the name of the monitor. Usually the short hostname
  * `MON_IP` is the IP address of the monitor (public)
  * `ETCDCTL_PEERS` is a comma seperated list of etcd peers (e.g. http://192.168.2.4:4001)
