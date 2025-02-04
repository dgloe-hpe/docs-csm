# CSM RBD Tool Usage

## Introduction

## Usage

```text
usage: csm_rbd_tool.py [-h] [--status] [--rbd_action RBD_ACTION]
                       [--pool_action POOL_ACTION] [--target_host TARGET_HOST]
                       [--csm_version CSM_VERSION]

A Helper tool to utilize an rbd device so additional upgrade space.

optional arguments:
  -h, --help            show this help message and exit
  --status              Provides the status of an rbd device managed by this
                        script
  --rbd_action RBD_ACTION
                        "create/delete/move" an rbd device to store and
                        decompress the csm tarball
  --pool_action POOL_ACTION
                        Use with "--pool_action delete" to delete a predefined
                        pool and rbd device used with the csm tarball.
  --target_host TARGET_HOST
                        Destination node to map the device to. Must be a k8s
                        master host
  --csm_version CSM_VERSION
                        The CSM version being installed or upgraded to. This
                        is used for the rbd device mount point. [Future Placeholder]
```

## Examples

1. (`ncn-m#`) Check the status of the `rbd` device.

   ```bash
   /usr/share/doc/csm/scripts/csm_rbd_tool.py --status
   ```

   Output:

   ```text
   [{"id":"0","pool":"csm_admin_pool","namespace":"","name":"csm_scratch_img","snap":"-","device":"/dev/rbd0"}]
   Pool csm_admin_pool exists: True
   RBD device exists True
   RBD device mounted at - ncn-m001.nmn:/etc/cray/upgrade/csm
   ```

2. (`ncn-s001`) Move the `rbd` device.

   ```bash
   /usr/share/doc/csm/scripts/csm_rbd_tool.py --rbd_action move --target_host ncn-m002
   ```

   Output:

   ```text
   [{"id":"0","pool":"csm_admin_pool","namespace":"","name":"csm_scratch_img","snap":"-","device":"/dev/rbd0"}]
   /dev/rbd0
   RBD device mounted at - ncn-m002.nmn:/etc/cray/upgrade/csm
   ```

## Troubleshooting the RBD Tool

### Issue

Moving the `rbd` device can fail with the error message:

 `mount: /etc/cray/upgrade/csm: mount(2) system call failed: Structure needs cleaning.`

### Fix

To clean the device, first get the `rbd` device name and location.
This can be found in the information outputted by the status check shown above. The device name is likely `/dev/rbd0` or similar and it should be located on `ncn-m001` or `ncn-m002`.
Run the following command on the node that the device is located on.

(`ncn-m#`) Clean the device. This may have multiple prompts. 

```bash
   fsck.ext4 <device_name>
```

Example output:

```text
e2fsck 1.43.8 (1-Jan-2018)
One or more block group descriptor checksums are invalid.  Fix<y>?

Group descriptor 7999 checksum is 0x6f65, should be 0x6971.  FIXED.
Pass 1: Checking inodes, blocks, and sizes

Pass 2: Checking directory structure
Pass 3: Checking directory connectivity
Pass 4: Checking reference counts
Pass 5: Checking group summary information
Block bitmap differences:  +(32768--33917) +(98304--99453) + ...
Fix<y>? yes
Free blocks count wrong (246632145, counted=257747999).
Fix<y>? yes
Free inodes count wrong (65529942, counted=65535989).
Fix<y>? yes
Padding at end of inode bitmap is not set. Fix<y>? yes

/dev/rbd0: ***** FILE SYSTEM WAS MODIFIED *****
/dev/rbd0: 11/65536000 files (0.0% non-contiguous), 4396001/262144000 blocks
```

Example output if the `rbd` device is already clean:

```text
e2fsck 1.43.8 (1-Jan-2018)
/dev/rbd0: clean, 11/65536000 files, 4396001/262144000 blocks
```

Once this is completed, retry moving the `rbd` device.
