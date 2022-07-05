# MetalLB Configuration

MetalLB provides a more robust configuration for the Node Management Network \(NMNLB\), Hardware Management Network \(HMNLB\), Customer Management Network \(CMN\), Customer High-Speed Network \(CHN\), and
Customer Access Network \(CAN\). This configuration is generated from the `csi config init` input values.

## MetalLB Peer Configuration

The content for `metallb_bgp_peers` is generated by the `csi config init` command. In addition to the MetalLB configuration, there is configuration needed on the spine switches to set up the BGP router on these
switches. If the system is configured to use the CHN for the user network, then configuration is also needed on the edge switches.

The MetalLB ConfigMap can also be viewed:

```text
peers:
- peer-address: 10.103.11.2
  peer-asn: 65533
  my-asn: 65532
- peer-address: 10.103.11.3
  peer-asn: 65533
  my-asn: 65532
- peer-address: 10.252.0.1
  peer-asn: 65533
  my-asn: 65533
- peer-address: 10.252.0.3
  peer-asn: 65533
  my-asn: 65533
```

To retrieve data about BGP peers:

```bash
kubectl get cm metallb -n metallb-system -o yaml
```

The speakers get their peering configuration from the MetalLB ConfigMap. This configuration specifies the IP address of the spine or aggregate switch, as well as the Autonomous System Number \(ASN\) for the speaker and the switch with which it is peering.

## CMN Configuration

This network has two MetalLB address pools, one for static IP allocation and the other for dynamic IP allocation. Static allocation guarantees the same IP allocation for services using this pool across deployment
and installations. Dynamic allocations means that the allocated IP addresses will be in this pool, but may change depending on the timing and ordering of the IP allocation.

View the address pool configurations in the MetalLB ConfigMap after system installation. The MetalLB ConfigMap should not be edited directly or they may be overwritten in a later update. The following is an example
of the values for the CMN address pools in the ConfigMap:

```text
- name: customer-management 
  protocol: bgp
  addresses:
    **- 10.102.5.64/26**
- name: customer-management-static 
  protocol: bgp
  addresses:
    **- 10.102.5.60/30**
```

The CMN configuration is set in the `csi config init` input:

```bash
csi config init
.
.
.
     --cmn-cidr 10.102.5.0/25
     --cmn-gateway 10.102.5.1
     --cmn-static-pool 10.102.5.60/30
     --cmn-dynamic-pool 10.102.5.64/26
.
.
.
```

## CAN or CHN Configuration

There will be either CAN or CHN configured, not both.  This network has one MetalLB address pool for dynamic IP allocation. A static pool is not needed for this network.

The following is an example of the values for the CAN address pool in the ConfigMap:

```text
- name: customer-access
  protocol: bgp
  addresses:
    **- 10.102.5.160/27**
```

The following is an example of the values for the CHN address pool in the ConfigMap:

```text
- name: customer-high-speed 
  protocol: bgp
  addresses:
    **- 10.102.6.160/27**
```

The CAN or CHN configuration is set in the `csi config init` input:

```bash
csi config init
.
.
.
     --can-cidr 10.102.5.128/26
     --can-gateway 10.102.5.129
     --can-dynamic-pool 10.102.5.160/27

     --chn-cidr 10.102.6.128/26
     --chn-gateway 10.102.6.129
     --chn-dynamic-pool 10.102.6.160/27
.
.
.
```