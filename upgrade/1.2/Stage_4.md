# Stage 4 - Ceph Upgrade

## Addresses CVEs

1. CVE-2021-3531: Swift API denial of service.
1. CVE-2021-3524: HTTP header injects via CORS in RGW.
1. CVE-2021-3509: Dashboard XSS via token cookie.
1. CVE-2021-20288: Unauthorized global_id reuse in cephx.

**IMPORTANT:**

> * This upgrade is performed using the ceph orchestrator.
> * The upgrade includes all fixes from v15.2.9 through to v15.2.15 listed here [Ceph version index](https://docs.ceph.com/en/latest/releases/octopus/)

## Procedure

### Upgrade

1. Check to ensure the upgrade is possible.

   ```bash
   ceph orch upgrade check --image registry.local/ceph/ceph:v15.2.15
   ```

1. Set the container image.

   ```bash
   ceph config set global container_image registry.local/ceph/ceph:v15.2.15
   ```

   Verify the change has occured:

   ```bash
   ceph config dump -f json-pretty|jq '.[]|select(.name=="container_image")|.value'
   ```

   Expected result:

   ```text
   "registry.local/ceph/ceph:v15.2.15"
   ```

1. Start the upgrade.

   ```bash
   ceph orch upgrade start --image registry.local/ceph/ceph:v15.2.15
   ```

1. Monitor the upgrade.

***NOTE***: You may want to split these commands into multiple windows depending on the size of your cluster.

   ```bash
   watch "ceph -s; ceph orch ps"
   ```

Expected Warnings:

From `ceph -s`

```text
health: HEALTH_WARN
        clients are using insecure global_id reclaim
        mons are allowing insecure global_id reclaim
```

From `ceph health detail`

```text
HEALTH_WARN clients are using insecure global_id reclaim; mons are allowing insecure global_id reclaim; 1 osds down
[WRN] AUTH_INSECURE_GLOBAL_ID_RECLAIM: clients are using insecure global_id reclaim
    osd.4 at [REDACTED] is using insecure global_id reclaim
    mds.cephfs.ncn-s001.qcalye at [REDACTED] is using insecure global_id reclaim
    client.rgw.site1.zone1.ncn-s001.lgfngf at [REDACTED] is using insecure global_id reclaim
    client.rgw.site1.zone1.ncn-s001.lgfngf at [REDACTED] is using insecure global_id reclaim
    osd.0 at [REDACTED] is using insecure global_id reclaim
    client.rgw.site1.zone1.ncn-s003.wllbbx at [REDACTED] is using insecure global_id reclaim
    osd.5 at [REDACTED] is using insecure global_id reclaim
    osd.7 at [REDACTED] is using insecure global_id reclaim
    client.rgw.site1.zone1.ncn-s002.aanqmw at [REDACTED] is using insecure global_id reclaim
    client.rgw.site1.zone1.ncn-s002.aanqmw at [REDACTED] is using insecure global_id reclaim
    client.rgw.site1.zone1.ncn-s002.aanqmw a [REDACTED] is using insecure global_id reclaim
    osd.3 at [REDACTED]] is using insecure global_id reclaim
    mds.cephfs.ncn-s002.tdrohq at [REDACTED]] is using insecure global_id reclaim
    client.rgw.site1.zone1.ncn-s003.wllbbx a [REDACTED] is using insecure global_id reclaim
    client.rgw.site1.zone1.ncn-s001.lgfngf a [REDACTED] is using insecure global_id reclaim
    client.rgw.site1.zone1.ncn-s003.wllbbx a [REDACTED] is using insecure global_id reclaim
    mds.cephfs.ncn-s003.ddbgzt at [REDACTED]] is using insecure global_id reclaim
    osd.8 at [REDACTED]] is using insecure global_id reclaim
    osd.1 at [REDACTED]] is using insecure global_id reclaim
[WRN] AUTH_INSECURE_GLOBAL_ID_RECLAIM_ALLOWED: mons are allowing insecure global_id reclaim
    mon.ncn-s001 has auth_allow_insecure_global_id_reclaim set to true
    mon.ncn-s002 has auth_allow_insecure_global_id_reclaim set to true
    mon.ncn-s003 has auth_allow_insecure_global_id_reclaim set to true
```

You will see the processes running the ceph container image go through the upgrade process.  This will involve stopping the old process running the v15.2.8 container and restarting the process with the new v15.2.15 container image.

**IMPORTANT:**
Only processes running the v15.2.8 image will be upgraded.  This will include `MON,MGR,MDS,RGW,OSD` processes only.

### Post Upgrade

1. Verify the upgrade

   ceph health detail should only show:

   ```text
   HEALTH_WARN mons are allowing insecure global_id reclaim
   [WRN] AUTH_INSECURE_GLOBAL_ID_RECLAIM_ALLOWED: mons are allowing insecure global_id reclaim
    mon.ncn-s001 has auth_allow_insecure_global_id_reclaim set to true
    mon.ncn-s002 has auth_allow_insecure_global_id_reclaim set to true
    mon.ncn-s003 has auth_allow_insecure_global_id_reclaim set to true
    ```

   ceph -s should show:

   ```text
       health: HEALTH_WARN
            mons are allowing insecure global_id reclaim
   ```

   ceph orch ps should show:

   `MON,MGR,MDS,RGW,OSD` processes running version `v15.2.15`.  There should be no processes running version `v15.2.8`

2. Disable `auth_allow_insecure_global_id_reclaim`

   ```bash
   ceph config set mon auth_allow_insecure_global_id_reclaim false
   ```

   Now the status of the cluster should show **HEALTH_OK**.  

   Please ***NOTE*** that this may take up to 30 seconds to apply and the health to return to **HEALTH_OK**.