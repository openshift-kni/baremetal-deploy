import ipaddress
import json
import os
import re
import socket
import subprocess
import sys
import time

from shutil import copyfile

import ibmconf

def ibmcloud(cmd):
    cmd = ["ibmcloud"]+cmd+["--output", "JSON"]
    try:
        data = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE, check=True).stdout
    except subprocess.CalledProcessError as E:
        exit("ERROR: %s\n%s"%(" ".join(cmd), E.stderr))
    return json.loads(data)

def ppjson(d):
    print(json.dumps(d, indent=2))

class Host(object):
    def __init__(self, detail):
        self.data = {}
        self.data["hostname"] = detail["hostname"]
        self.data["id"] = detail["id"]

        self.data["vlans"] = {}
        for vlan in detail["networkVlans"]:
            self.data["vlans"][vlan["networkSpace"]] = vlan["vlanNumber"]
            self.data["vlans"][vlan["networkSpace"]+"Id"] = vlan["id"]

        for net in detail["networkComponents"]:
            if net.get("ipmiIpAddress"):
                self.data["ipmi_ip"] = net["ipmiIpAddress"]
                self.data["ipmi_user"] = detail["remoteManagementAccounts"][0]["username"]
                self.data["ipmi_password"] = detail["remoteManagementAccounts"][0]["password"]
            elif net.get("primaryIpAddress") == detail["primaryIpAddress"]:
                self.data["publicip"] = net["primaryIpAddress"]
                self.data["publicmac"] = net["macAddress"]
                self.data.setdefault("publicnics", []).append("eth%d"%net.get("port"))
            elif net.get("primaryIpAddress") == detail["primaryBackendIpAddress"]:
                self.data["privatemac"] = net["macAddress"]
                self.data["privateip"] = net["primaryIpAddress"]
                self.data.setdefault("privatenics", []).append("eth%d"%net.get("port"))

    def __repr__(self):
        return "%s - ipmi:%s, prov_mac:%s"%(self.data["hostname"], self.data["ipmi_ip"], self.data["privatemac"])

bshost = None
masters = []
workers = []
for host in ibmcloud(["sl","hardware","list", "-d", ibmconf.DC]):
    if host["hardwareStatus"]["status"] != "ACTIVE":
        continue
    hostid = host["id"]
    hostname = host["hostname"]
    host = Host(ibmcloud(["sl","hardware","detail", str(hostid)]))
    if hostname == getattr(ibmconf, "BSHOST", ""):
        bshost = host
    elif hostname in getattr(ibmconf, "MASTERS", []):
        host.data["role"] = "master"
        host.data["name"] = "master-%s"%(len(masters))
        masters.append(host)
    elif hostname in getattr(ibmconf, "WORKERS", []):
        host.data["role"] = "worker"
        host.data["name"] = "worker-%s"%(len(workers))
        workers.append(host)

keys = ibmcloud(["sl", "security", "sshkey-list"])
if len(keys) < 1:
    sys.exit("Please create a sshkey: ibmcloud sl security sshkey-add %s-key -f ~/.ssh/id_rsa.pub"%ibmconf.DEPLOYMENTCODE)

if not bshost or (len(masters) not in [1,3]):
    print("Missing hosts, you need a bootstrap host and 1 or 3 masters", file=sys.stderr)
    print("To create a bootstrap host: ibmcloud sl hardware create --hostname %s-bs --domain %s.%s --size 1U_1270_V6_2X2TB_NORAID --os CENTOS_8_64 --datacenter %s --port-speed 1000 --billing hourly --key %d" % (ibmconf.DEPLOYMENTCODE, ibmconf.CLUSTER, ibmconf.DOMAIN, ibmconf.DC, keys[0]["id"]), file=sys.stderr)
    print("To create a master host: ibmcloud sl hardware create --hostname %s-m<X> --domain %s.%s --size 1U_1270_V6_2X2TB_NORAID --os CENTOS_8_64 --datacenter %s --port-speed 1000 --billing hourly" % (ibmconf.DEPLOYMENTCODE, ibmconf.CLUSTER, ibmconf.DOMAIN, ibmconf.DC), file=sys.stderr)
    print("To create a worker host: ibmcloud sl hardware create --hostname %s-w<X> --domain %s.%s --size 1U_1270_V6_2X2TB_NORAID --os CENTOS_8_64 --datacenter %s --port-speed 1000 --billing hourly" % (ibmconf.DEPLOYMENTCODE, ibmconf.CLUSTER, ibmconf.DOMAIN, ibmconf.DC), file=sys.stderr)
    sys.exit("Retry when they are available")

vlans = {}
for vlan in ibmcloud(["sl", "vlan", "list", "-d", ibmconf.DC]):
    vlans[vlan["id"]] = ibmcloud(["sl", "vlan", "detail", str(vlan["id"])])

subnets={}
for subnet in ibmcloud(["sl", "subnet", "list", "-d", ibmconf.DC]):
    subnets[subnet["id"]] = ibmcloud(["sl", "subnet", "detail", str(subnet["id"])])

dnszones = ibmcloud(["sl", "dns", "zone-list"])
dnsrecords = ibmcloud(["sl", "dns", "record-list", "%s.%s"%(ibmconf.CLUSTER, ibmconf.DOMAIN)])

# We need a number of details from ip stuff
if len(set([host.data["vlans"]["PUBLIC"] for host in [bshost]+masters+workers])) > 1:
    sys.exit("Hosts not all on the same Public vlan")
if len(set([host.data["vlans"]["PRIVATE"] for host in [bshost]+masters+workers])) > 1:
    sys.exit("Hosts not all on the same Private vlan")

publicvlan = vlans[bshost.data["vlans"]["PUBLICId"]]
publicsubnet = subnets[publicvlan["subnets"][0]["id"]]
privatevlan = vlans[bshost.data["vlans"]["PRIVATEId"]]
privatesubnet = subnets[privatevlan["subnets"][0]["id"]]

# Ensure DNS entries resolve to IP's on the public domain
ips_taken=[]
ips_taken.append((socket.gethostbyname('api.%s.%s'%(ibmconf.CLUSTER, ibmconf.DOMAIN)), "api",))
ips_taken.append((socket.gethostbyname('dummy.apps.%s.%s'%(ibmconf.CLUSTER, ibmconf.DOMAIN)),"*.apps"))
ips_taken.append((publicsubnet["networkIdentifier"], "networkIdentifier"))
ips_taken.append((publicsubnet["broadcastAddress"], "broadcastAddress"))
ips_taken.append((publicsubnet["gateway"], "gateway"))
for host in publicvlan["hardware"]+publicvlan.get("virtualGuests", []):
    ips_taken.append((host["primaryIpAddress"], host["hostname"]))

ips_available=[str(ip) for ip in ipaddress.IPv4Network('%s/%s'%(publicsubnet["networkIdentifier"], publicsubnet["cidr"]))]

conflict=False
for ip, label in ips_taken:
    try:
        del ips_available[ips_available.index(ip)]
    except:
        print("Conflict in public subnet:",[gone for gone in ips_taken if gone[0] == ip], file=sys.stderr)
        conflict=True
if conflict:
    sys.exit("Resolve conflicts from: %r"%ips_available)

if len(ips_available) < 1:
    sys.exit("Not enough IP addresses available: %r"%ips_available)

return_data = {}
return_data["gateway"] = publicsubnet["gateway"]
return_data["bootstrap_pub_ip"] = bshost.data["publicip"]
return_data["bootstrap_priv_ip"] = bshost.data["privateip"]
return_data["bootstrap_priv_nics"] = " ".join(bshost.data["privatenics"])
return_data["bootstrap_pub_nics"] = "".join(bshost.data["publicnics"])
return_data["domain"] = "%s.%s"%(ibmconf.CLUSTER, ibmconf.DOMAIN)
return_data["mgtnet"] = '%s/%s'%(privatesubnet["networkIdentifier"], privatesubnet["cidr"])
return_data["privategateway"] = privatesubnet["gateway"]
return_data["publiccidr"] = publicsubnet["cidr"]
return_data["privatecidr"] = privatesubnet["cidr"]

return_data["dhcprange"] = "%s,%s,%s"%(ips_available[0], ips_available[0], publicsubnet["cidr"])

# If present we edit the hosts file, if not we edit hosts.sample
# Can't parse this file as a ini and don't want to build it up from scratch as it contains
# values I may need to keep, so editing instead
if os.path.exists("ansible-ipi-install/inventory/hosts"):
    hosts = open("ansible-ipi-install/inventory/hosts").read()
    copyfile("ansible-ipi-install/inventory/hosts", "ansible-ipi-install/inventory/hosts_%s"%time.strftime("%Y%m%d_%H%M%S.saved"))
else:
    hosts = open("ansible-ipi-install/inventory/hosts.sample").read()

hosts = re.sub("worker-.*\n","",hosts)
hosts = re.sub("master-.*\n","",hosts)
for host in masters+workers:
    return_data["dhcphosts"] = return_data.get("dhcphosts",  "")+"%s,%s,%s\n"%(host.data["publicmac"], host.data["publicip"],host.data["name"])
    hosts = re.sub(
        "\[%ss\]"%host.data["role"],
        "[%ss]\n%s name=%s role=%s ipmi_user=root ipmi_password=%s ipmi_address=%s ipmi_port=623 provision_mac=%s hardware_profile=default poweroff=true privilegelevel=OPERATOR"%
            (host.data["role"], host.data["name"], host.data["name"], host.data["role"], host.data["ipmi_password"], host.data["ipmi_ip"], host.data["privatemac"]), hosts)

hosts = re.sub("domain=.*","domain=\"%s\""%ibmconf.DOMAIN, hosts)
hosts = re.sub("cluster=.*","cluster=\"%s\""%ibmconf.CLUSTER, hosts)
hosts = re.sub("extcidrnet=.*","extcidrnet=\"%s/%s\""%(publicsubnet["networkIdentifier"], publicsubnet["cidr"]), hosts)
hosts = re.sub("provisioner.example.com",bshost.data["publicip"],hosts)

open("ansible-ipi-install/inventory/hosts", "w").write(hosts)
ppjson(return_data)
