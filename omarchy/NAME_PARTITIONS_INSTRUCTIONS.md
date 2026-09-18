# How to Name and Label Partitions in Omarchy OS

This guide explains how to add and change volume labels and partition names for your drives in Omarchy OS, both using the graphical **GNOME Disks** tool and via the **Command Line**.

---

## 1. Method 1: Using GNOME Disks (GUI)

GNOME Disks is the graphical tool shown in your system disks view.

### Steps to Label a Filesystem (Volume Name):
1. Open **Disks** from the app launcher (`Super` key, search for "Disks").
2. Select the target drive from the left sidebar (e.g., your Western Digital HDD, NVMe SSD, etc.).
3. In the graphical partition map, click on the **partition** you wish to name.
4. Click the **Gear icon (⚙)** located directly below the partition bar (next to the Play/Stop button).
5. Select **Edit Filesystem…**:
   - In the **Volume Name** box, enter your desired label (e.g., `Windows`, `Fedora`, `Storage`).
   - Click **Change** (enter your user/sudo password if prompted).

> [!NOTE]
> **If "Edit Filesystem" is grayed out:**
> The partition is actively mounted. Click the **Square / Stop (⏹)** button next to the gear icon to unmount it first, change the name, and then press the **Play (⏵)** button to remount it.

### (Optional) Steps to Label a GPT Partition (Partition Name):
- From the same **Gear icon (⚙)** menu, select **Edit Partition…**.
- Change the **Name** field. This updates the GPT partition table entry (PARTLABEL).

---

## 2. Method 2: Using the Command Line (CLI)

Different filesystem formats use different command-line tools to update volume labels.

### Btrfs (e.g., `/dev/nvme0n1p1`, `/dev/nvme0n1p3`)
*Can be changed while mounted or unmounted:*
```bash
sudo btrfs filesystem label /dev/nvme0n1p1 "NewName"
```
Or if already mounted:
```bash
sudo btrfs filesystem label /mount/point "NewName"
```

### Ext4 (e.g., `/dev/sdb5`, `/dev/sdc1`)
*Must be unmounted or root-permitted:*
```bash
sudo e2label /dev/sdb5 "spare"
```
*(Alternative: `sudo tune2fs -L "NewName" /dev/sdb5`)*

### NTFS (e.g., `/dev/sdb3`)
*Must be unmounted:*
```bash
# 1. Unmount if currently mounted
sudo umount /dev/sdb3

# 2. Set label (max 128 Unicode characters)
sudo ntfslabel /dev/sdb3 "Windows"
```

### FAT32 / vfat (e.g., EFI Partitions: `/dev/sda1`, `/dev/sdb1`, `/dev/nvme0n1p2`)
*Must be unmounted:*
```bash
# Label must be uppercase and maximum 11 characters
sudo fatlabel /dev/sdb1 "EFI_WIN"
```

### Setting GPT Partition Names (PARTLABEL)
To change the GPT partition table name (independent of filesystem type):
```bash
# Using sgdisk: sudo sgdisk -c <PART_NUM>:"<NAME>" /dev/<DISK>
sudo sgdisk -c 3:"Windows 11" /dev/sdb
```

---

## 3. Reference: Your Current Drive Layout

| Drive / Partition | Filesystem | Size | Current Label / PARTLABEL | Suggested Use / Notes |
| :--- | :--- | :--- | :--- | :--- |
| **`/dev/sda1`** | `vfat` | 2.0 GB | *(None)* | Omarchy `/boot` |
| **`/dev/sda2`** | `crypto_LUKS` | 221.6 GB | *(Encrypted Root)* | Omarchy system partition |
| **`/dev/sdb1`** | `vfat` | 100 MB | `EFI system partition` | Secondary EFI partition |
| **`/dev/sdb2`** | — | 16 MB | `Microsoft reserved partition` | Windows MSR |
| **`/dev/sdb3`** | `ntfs` | 116.4 GB | `Basic data partition` | Windows OS / Data |
| **`/dev/sdb4`** | `ntfs` | 666 MB | *(None)* | Windows Recovery |
| **`/dev/sdb5`** | `ext4` | 348.6 GB | `spare` | Linux Data |
| **`/dev/sdc1`** | `ext4` | 931.5 GB | `big_one` | Large storage drive |
| **`/dev/nvme0n1p1`** | `btrfs` | 93.1 GB | *(None)* | Secondary OS root |
| **`/dev/nvme0n1p2`** | `vfat` | 1.0 GB | *(None)* | NVMe EFI partition |
| **`/dev/nvme0n1p3`** | `btrfs` | 382.8 GB | *(None)* | NVMe Home / User data |

---

## 4. How to Verify Partition Labels

To check the updated labels across all drives at any time, run:

```bash
lsblk -o NAME,FSTYPE,LABEL,PARTLABEL,SIZE,MOUNTPOINT
```

Or for filesystem details:
```bash
lsblk -f
```
