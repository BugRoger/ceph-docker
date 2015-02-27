#!/bin/bash
set -e 

if [ ! -n "$MON_NAME" ]; then
  echo >&2 "ERROR: MON_NAME must be defined as the name of the monitor"
  exit 1
fi
 
if [ ! -n "$MON_IP" ]; then
  echo >&2 "ERROR: MON_IP must be defined as the IP address of the monitor"
  exit 1
fi
 
CLUSTER=${CLUSTER:-ceph}
CLUSTER_PATH=/ceph-config/$CLUSTER
 
while monitor=$(etcdctl get ${CLUSTER_PATH}/lock 2> /dev/null) ; do
  echo "Waiting for ${monitor} to finish generating the inital cluster config."
  sleep 1
done

etcdctl set ${CLUSTER_PATH}/mon/${MON_NAME} "${MON_IP}:6789" >/dev/null

if etcdctl get ${CLUSTER_PATH}/done > /dev/null 2>%1 ; then
  echo "Configuration found for cluster ${CLUSTER}. Writing to disk."
 
  fsid=$(etcdctl get ${CLUSTER_PATH}/fsid)
  
  mon_host=""
  mon_inital_members=""
  for monitor in `etcdctl ls ${CLUSTER_PATH}/mon`; do
    ip=$(etcdctl get $monitor)
    monitor=${monitor##*/}

    mon_host+=$ip","
    mon_inital_members+=$monitor","
  done

  mon_host=${mon_host%,}
  mon_inital_members=${mon_inital_members%,}

   cat <<ENDHERE >/etc/ceph/ceph.conf
fsid = $fsid
mon initial members = ${mon_inital_members}
mon host = ${mon_host}
auth cluster required = cephx
auth service required = cephx
auth client required = cephx
ENDHERE

  etcdctl get ${CLUSTER_PATH}/ceph.mon.keyring > /etc/ceph/ceph.mon.keyring
  etcdctl get ${CLUSTER_PATH}/ceph.client.admin.keyring > /etc/ceph/ceph.client.admin.keyring
  # ceph mon getmap -o /etc/ceph/monmap

  cat /etc/ceph/ceph.conf
else 
  echo "No configuration found for cluster ${CLUSTER}. Generating."

  etcdctl mk ${CLUSTER_PATH}/lock ${MON_NAME} --ttl 15 > /dev/null 2>&1
 
  fsid=$(uuidgen)
  cat <<ENDHERE >/etc/ceph/ceph.conf
fsid = $fsid
mon initial members = ${MON_NAME}
mon host = ${MON_IP}
auth cluster required = cephx
auth service required = cephx
auth client required = cephx
ENDHERE

  ceph-authtool /etc/ceph/ceph.client.admin.keyring --create-keyring --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'
  ceph-authtool /etc/ceph/ceph.mon.keyring --create-keyring --gen-key -n mon. --cap mon 'allow *'
  monmaptool --create --clobber --add ${MON_NAME} ${MON_IP} --fsid ${fsid}  /etc/ceph/monmap

  etcdctl set ${CLUSTER_PATH}/fsid $fsid > /dev/null
  etcdctl set ${CLUSTER_PATH}/ceph.mon.keyring < /etc/ceph/ceph.mon.keyring >/dev/null
  etcdctl set ${CLUSTER_PATH}/ceph.client.admin.keyring < /etc/ceph/ceph.client.admin.keyring >/dev/null
    
  sleep 10

  echo "completed initialization for ${MON_NAME}"
  etcdctl set ${CLUSTER_PATH}/done true > /dev/null 2>&1
  etcdctl rm ${CLUSTER_PATH}/lock > /dev/null 2>&1
fi
