# Collecting NCN MAC Addresses

This procedure will detail how to collect the NCN MAC addresses from a Shasta system.  After completing this procedure,
you will have the MAC addresses needed for the Bootstrap MAC, Bond0 MAC0, and Bond0 MAC1 columns in `ncn_metadata.csv`.

The Bootstrap MAC address will be used for identification of this node during the early part of the PXE boot process before the bonded interface can be established.
The Bond0 MAC0 and Bond0 MAC1 are the MAC addresses for the physical interfaces that your node will use for the various VLANs.
The Bond0 MAC0 and Bond0 MAC1 should be on the different network cards to establish redundancy for a failed network card.
On the other hand, if the node has only a single network card, then MAC1 and MAC0 will still produce a valid configuration if they do reside on the same physical card.

#### Sections

- [Procedure: iPXE Consoles](#procedure-ipxe-consoles)
   - [Requirements](#requirements)
   - [MAC Collection](#mac-collection)
- [Procedure: Serial consoles](#procedure-serial-consoles)
- [Procedure: Recovering from an incorrect `ncn_metadata.csv` file](#procedure-recovering-from-an-incorrect-ncn_metadata_csv-file)

The easy way to do this leverages the NIC-dump provided by the metal-ipxe package. This page will walk-through
booting NCNs and collecting their MACs from the conman console logs.
> The alternative is to use serial cables (or SSH) to collect the MACs from the switch ARP tables, this can become exponentially difficult for large systems.
> If this is the only way, please proceed to the bottom of this page.

<a name="procedure-ipxe-consoles"></a>
## Procedure: iPXE Consoles

This procedure is faster for those with the LiveCD (CRAY Pre-Install Toolkit) it can be used to quickly
boot-check nodes to dump network device information without an operating system. This works by accessing the PCI Configuration Space.

<a name="requirements"></a>
#### Requirements

> If CSI does not work due to requiring a file, please file a bug. By default, dnsmasq
> and conman are already running on the LiveCD but bond0 needs to be configured, dnsmasq needs to
> serve/listen over bond0, and conman needs the BMC information.

1. LiveCD dnsmasq is configured for the bond0/metal network (NMN/HMN/CAN do not matter)
2. BMC MAC addresses already collected
3. LiveCD conman is configured for each BMC

For help with either of those, see [LiveCD Setup](bootstrap_livecd_remote_iso.md).

<a name="mac-collection"></a>
#### MAC Collection

1. (optional) Shim the boot so nodes bail after dumping their netdevs. 
   Removing the iPXE script will prevent network booting but beware of disk-boots.
   This will prevent the nodes from continuing to boot and end in undesired states.
    ```bash
    pit# mv /var/www/boot/script.ipxe /var/www/boot/script.ipxe.bak
    ```
2. Verify consoles are active with `conman -q`,
    ```bash
    pit# conman -q
    ncn-m002-mgmt
    ncn-m003-mgmt
    ncn-s001-mgmt
    ncn-s002-mgmt
    ncn-s003-mgmt
    ncn-w001-mgmt
    ncn-w002-mgmt
    ncn-w003-mgmt
    ```

3. Now set the nodes to PXE boot and (re)start them.
    ```bash
    pit# export username=root
    pit# export IPMI_PASSWORD=changeme
    pit# grep -oP "($mtoken|$stoken|$wtoken)" /etc/dnsmasq.d/statics.conf | sort -u | xargs -t -i ipmitool -I lanplus -U $username -E -H {} chassis bootdev pxe options=efiboot,persistent
    pit# grep -oP "($mtoken|$stoken|$wtoken)" /etc/dnsmasq.d/statics.conf | sort -u | xargs -t -i ipmitool -I lanplus -U $username -E -H {} power off
    pit# sleep 10
    pit# grep -oP "($mtoken|$stoken|$wtoken)" /etc/dnsmasq.d/statics.conf | sort -u | xargs -t -i ipmitool -I lanplus -U $username -E -H {} power on
    ```
4. Now wait for the nodes to netboot. You can follow them with `conman -j ncn-*id*-mgmt` (use `conman -q` to see ). This takes less than 3 minutes, speed depends on how quickly your nodes POST.
5. Print off what's been found in the console logs, this snippet will omit duplicates from multiple boot attempts:
    ```bash
    pit# for file in /var/log/conman/*; do
        echo $file
        grep -Eoh '(net[0-9] MAC .*)' $file | sort -u | grep PCI && echo -----
    done
    ```
6. From the output you must fish out 2 MACs to use for bond0, and 2 more to use for bond1 based on your topology. **The `Bond0 MAC0` must be the first port** of the first PCIe card, specifically the port connecting the NCN to the lower spine (for example, if connected to spines01 and 02, this is going to sw-spine-001 - if connected to sw-spine-007 and sw-spine-008, then this is sw-spine-007). **The 2nd MAC for `bond0` is the first port of the 2nd PCIe card, or 2nd port of the first when only one card exists**.
    - Examine the output, you can use the table provided on [NCN Networking](../background/ncn_networking.md) for referencing commonly seen devices.
    - Note that worker nodes also have the high-speed network cards. If you know these cards, you can filter their device IDs out from the above output using this snippet:
        ```bash
        pit# unset did # clear it if you used it.
        pit# did=1017 # ConnectX-5 example.
        pit# for file in /var/log/conman/*; do
            echo $file
            grep -Eoh '(net[0-9] MAC .*)' $file | sort -u | grep PCI | grep -Ev "$did" && echo -----
        done
        ```
    - Note to filter out onboard NICs, or site-link cards, you can omit their device IDs as well. Use the above snippet but add the other IDs:
      **this snippet prints out only mgmt MACs, the `did` is the HSN and onboard NICs that is being ignored.**
        ```bash
        pit# unset did # clear it if you used it.
        pit# did='(1017|8086|ffff)'
        pit# for file in /var/log/conman/*; do
            echo $file
            grep -Eoh '(net[0-9] MAC .*)' $file | sort -u | grep PCI | grep -Ev "$did" && echo -----
        done
        ```
7. Examine the output from `grep`, use the lowest value MAC address per PCIe card.

    > example: 1 PCIe card with 2 ports for a total of 2 ports per node.\

    ```bash
    -----
    /var/log/conman/console.ncn-w003-mt
    net2 MAC b8:59:9f:d9:9e:2c PCI.DeviceID 1013 PCI.VendorID 15b3 <-bond0-mac0 (0x2c < 0x2d)
    net3 MAC b8:59:9f:d9:9e:2d PCI.DeviceID 1013 PCI.VendorID 15b3 <-bond0-mac1
    -----
    ```

    > example: 2 PCIe cards with 2 ports each for a total of 4 ports per node.

    ```bash
    -----
    /var/log/conman/console.ncn-w006-mgmt
    net0 MAC 94:40:c9:5f:b5:df PCI.DeviceID 8070 PCI.VendorID 1077 <-bond0-mac0 (0x38 < 0x39)
    net1 MAC 94:40:c9:5f:b5:e0 PCI.DeviceID 8070 PCI.VendorID 1077 (future use)
    net2 MAC 14:02:ec:da:b9:98 PCI.DeviceID 8070 PCI.VendorID 1077 <-bond0-mac1 (0x61f0 < 0x7104)
    net3 MAC 14:02:ec:da:b9:99 PCI.DeviceID 8070 PCI.VendorID 1077 (future use)
    -----
    ```

8. The above output identified MAC0 and MAC1 of the bond as 14:02:ec:df:9c:38 and 94:40:c9:c1:61:f0 respectively.
    > Tip: Mind the index (3, 2, 1.... ; not 1, 2, 3)
    ```
    Xname,Role,Subrole,BMC MAC,Bootstrap MAC,Bond0 MAC0,Bond0 MAC1
    x3000c0s9b0n0,Management,Worker,94:40:c9:37:77:26,14:02:ec:df:9c:38,14:02:ec:df:9c:38,94:40:c9:c1:61:f0
                                                      ^^^^^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^^^
    ```

<a name="procedure-serial-consoles"></a>
## Procedure: Serial Consoles

For this, you will need to double-back to [Collecting BMC MAC Addresses](collecting_bmc_mac_addresses.md) and pick out
the MACs for your BOND from each the sw-spine-001 and sw-spine-002 switch.

> **Note:** The node must be booted into an operating system in order for the Bond MAC addresses to appear on the spine switches.

> Tip: A PCIe card with dual-heads may go to either spine switch, meaning MAC0 ought to be collected from
> spine-01. Please refer to your cabling diagram, or actual rack (in-person).

1. Follow "Metadata BMC" on each spine switch that port1 and port2 of the bond is plugged into.
2. Usually the 2nd/3rd/4th/Nth MAC on the PCIe card will be a 0x1 or 0x2 deviation from the first port. If you confirm this, then collection
is quicker.

<a name="procedure-recovering-from-an-incorrect-ncn_metadata_csv-file"></a>
## Procedure: Recovering from an incorrect `ncn_metadata.csv` file

If you have an incorrect `ncn_metadata.csv` file, you will be unable to deploy the NCNs.  This section details a recovery procedure in case that happens.

1. Remove the incorrectly-generated configs. Before deleting the incorrectly-generated configs consider making a backup of them. In case they need to be examined at a later time. 

> **`WARNING`** Ensure that the `SYSTEM_NAME` environment variable is correctly set. If `SYSTEM_NAME` is
> not set the command below could potentially remove the entire prep directory.
> ```bash
> pit# export SYSTEM_NAME=eniac
> ```

```bash
pit# rm -rf /var/www/ephemeral/prep/$SYSTEM_NAME
```

2. Manually edit `ncn_metadata.csv`, replacing the bootstrap MAC address with Bond0 MAC0 address for the afflicted nodes that failed to boot

3. Re-run `csi config init` with the required flags

4. Copy all the newly-generated files into place

```bash
pit# \
cp -p /var/www/ephemeral/prep/$SYSTEM_NAME/dnsmasq.d/* /etc/dnsmasq.d/*
cp -p /var/www/ephemeral/prep/$SYSTEM_NAME/basecamp/* /var/www/ephemeral/configs/
cp -p /var/www/ephemeral/prep/$SYSTEM_NAME/conman.conf /etc/
cp -p /var/www/ephemeral/prep/$SYSTEM_NAME/pit-files/* /etc/sysconfig/network/
```

5. Update CA Cert on the copied data.json file. Provide the path to the data.json, the path to our customizations.yaml, and finally the sealed_secrets.key

```bash
pit# csi patch ca \
--cloud-init-seed-file /var/www/ephemeral/configs/data.json \
--customizations-file /var/www/ephemeral/prep/site-init/customizations.yaml \
--sealed-secret-key-file /var/www/ephemeral/prep/site-init/certs/sealed_secrets.key
```

6. Now restart everything to apply the new configs:

```bash
pit# \
wicked ifreload all
systemctl restart dnsmasq conman basecamp
systemctl restart nexus
```

7. Apply any NCN pre-boot Workarounds. Check for workarounds in the `/opt/cray/csm/workarounds/before-ncn-boot` directory. If there are any workarounds in that directory, run those now. Each has its own instructions in their respective README.md files.

```bash
pit# ls /opt/cray/csm/workarounds/before-ncn-boot
```

If there is a workaround here, the output looks similar to the following:
```
CASMINST-980
```

8. Before relaunching NCNs, be sure to wipe the disks first.  To wipe all disks in all NCNs, refer to the disk wipe procedure in the
[Degraded System Notice](prepare_configuration_payload.md#degraded-system-notice).