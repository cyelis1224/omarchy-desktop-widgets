#!/usr/bin/env python3
import os
import json
import subprocess

HOME = os.path.expanduser('~')
CLOUD_BASE = os.path.join(HOME, 'Cloud')

def stat_mount(mount, remote):
    """Returns (total_bytes, free_bytes), or None when the mount cannot be read.

    A stalled FUSE/network mount blocks statfs in the kernel where only SIGKILL
    reaches it, so an in-process alarm never fires. Remote mounts are therefore
    stat'ed in a child process that can be killed on timeout.
    """
    try:
        if not remote:
            st = os.statvfs(mount)
            return st.f_blocks * st.f_frsize, st.f_bavail * st.f_frsize
        out = subprocess.run(['stat', '-f', '-c', '%b %a %S', '--', mount],
                             capture_output=True, text=True, timeout=2)
        if out.returncode != 0:
            return None
        blocks, avail, frsize = (int(v) for v in out.stdout.split())
        return blocks * frsize, avail * frsize
    except Exception:
        return None

def format_bytes(n):
    for unit in ['B', 'K', 'M', 'G', 'T']:
        if n < 1024.0:
            if unit in ['T', 'P'] and n < 10.0:
                return f"{n:.1f}{unit}"
            return f"{n:.0f}{unit}"
        n /= 1024.0
    return f"{n:.1f}P"

def is_cloud_mount(fs, mount, fstype):
    # 1. Mounts located inside ~/Cloud (e.g. ~/Cloud/GoogleDrive, ~/Cloud/OneDrive)
    if CLOUD_BASE and (mount == CLOUD_BASE or mount.startswith(CLOUD_BASE + '/')):
        return True

    # 2. Known cloud / remote FUSE filesystems
    cloud_fstypes = {
        'fuse.rclone', 'rclone', 'fuse.gcsfuse', 'fuse.s3fs',
        'fuse.davfs', 'davfs2', 'fuse.onedrive', 'fuse.dropbox',
        'fuse.sshfs'
    }
    if fstype in cloud_fstypes or fstype.startswith('fuse.rclone'):
        if not mount.startswith(('/proc', '/sys', '/dev', '/run/user')):
            return True
        if 'rclone' in fstype or 'rclone' in fs:
            return True

    # 3. Source ending with ':' (standard rclone remote notation e.g. GoogleDrive:)
    if fs.endswith(':') and ('fuse' in fstype or mount.startswith(HOME)):
        return True

    # 4. Typical cloud mount paths in home directory
    if mount.startswith((
        os.path.join(HOME, 'GoogleDrive'),
        os.path.join(HOME, 'Google Drive'),
        os.path.join(HOME, 'OneDrive'),
        os.path.join(HOME, 'Dropbox'),
        os.path.join(HOME, 'Nextcloud'),
        os.path.join(HOME, 'ownCloud')
    )):
        return True

    return False

def get_disks():
    disks = []
    seen_devs = set()
    seen_mounts = set()

    ignored_fstypes = {
        'tmpfs', 'devtmpfs', 'efivarfs', 'overlay', 'squashfs', 'proc', 'sysfs',
        'devpts', 'cgroup', 'cgroup2', 'securityfs', 'pstore', 'autofs', 'mqueue',
        'hugetlbfs', 'debugfs', 'tracefs', 'fusectl', 'configfs', 'ramfs',
        'binfmt_misc', 'bpf', 'nsfs'
    }

    # 1. Native /proc/mounts + os.statvfs (Fast, robust, timeout-safe against hung network FUSE endpoints)
    try:
        if os.path.exists('/proc/mounts'):
            with open('/proc/mounts', 'r') as f:
                for line in f:
                    parts = line.split()
                    if len(parts) >= 3:
                        fs, mount, fstype = parts[0], parts[1], parts[2]
                        if fstype in ignored_fstypes:
                            continue

                        cloud = is_cloud_mount(fs, mount, fstype)
                        if fstype == 'fuse' and not cloud:
                            continue
                        if not fs.startswith('/dev/') and not cloud:
                            continue
                        if mount == '/boot' or mount.startswith('/boot/'):
                            continue
                        if mount in seen_mounts:
                            continue
                        if not cloud and fs in seen_devs and mount != '/':
                            continue

                        sizes = stat_mount(mount, cloud)
                        if sizes is None:
                            continue
                        total, free = sizes

                        seen_mounts.add(mount)
                        if not cloud:
                            seen_devs.add(fs)

                        used = total - free
                        pct = (used / total) if total > 0 else 0.0

                        # Form readable label and icon
                        if cloud:
                            if CLOUD_BASE and mount.startswith(CLOUD_BASE + '/'):
                                rel = os.path.relpath(mount, CLOUD_BASE)
                                name = rel.split('/')[0]
                            elif fs.endswith(':'):
                                name = fs.rstrip(':')
                            else:
                                name = os.path.basename(mount.rstrip('/'))
                            label = f'Cloud ({name})'
                            icon = '\uf0c2'  # fa-cloud
                            dtype = 'cloud'
                        elif mount == '/':
                            label = 'Root Storage (/)'
                            icon = '\uf0a0'  # fa-hdd
                            dtype = 'root'
                        elif mount.startswith(('/run/media/', '/media/', '/mnt/')):
                            dev_name = fs.split('/')[-1]
                            label = f'Secondary ({dev_name})'
                            icon = '\uf0a0'  # fa-hdd
                            dtype = 'secondary'
                        else:
                            label = f'Disk ({mount})'
                            icon = '\uf0a0'  # fa-hdd
                            dtype = 'disk'

                        disks.append({
                            'label': label,
                            'mount': mount,
                            'size': format_bytes(total),
                            'used': format_bytes(used),
                            'avail': format_bytes(free),
                            'pct': round(pct, 2),
                            'icon': icon,
                            'type': dtype
                        })
    except Exception:
        pass

    # 2. Fallback to df if /proc/mounts yielded nothing
    if not disks:
        try:
            p = subprocess.run(
                ['df', '-hP', '-x', 'tmpfs', '-x', 'devtmpfs', '-x', 'efivarfs', '-x', 'overlay'],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                timeout=3
            )
            for line in p.stdout.strip().split('\n')[1:]:
                parts = line.split()
                if len(parts) >= 6:
                    fs, size, used, avail, use_pct = parts[0], parts[1], parts[2], parts[3], parts[4]
                    mount = ' '.join(parts[5:])
                    if mount.startswith('/boot'):
                        continue

                    cloud = (CLOUD_BASE and (mount == CLOUD_BASE or mount.startswith(CLOUD_BASE + '/'))) or fs.endswith(':')
                    if not fs.startswith('/dev/') and not cloud:
                        continue
                    if mount in seen_mounts:
                        continue
                    if not cloud and fs in seen_devs and mount != '/':
                        continue

                    seen_mounts.add(mount)
                    if not cloud:
                        seen_devs.add(fs)

                    if cloud:
                        if CLOUD_BASE and mount.startswith(CLOUD_BASE + '/'):
                            rel = os.path.relpath(mount, CLOUD_BASE)
                            name = rel.split('/')[0]
                        elif fs.endswith(':'):
                            name = fs.rstrip(':')
                        else:
                            name = os.path.basename(mount.rstrip('/'))
                        label = f'Cloud ({name})'
                        icon = '\uf0c2'
                        dtype = 'cloud'
                    elif mount == '/':
                        label = 'Root Storage (/)'
                        icon = '\uf0a0'
                        dtype = 'root'
                    elif mount.startswith(('/run/media/', '/media/', '/mnt/')):
                        dev_name = fs.split('/')[-1]
                        label = f'Secondary ({dev_name})'
                        icon = '\uf0a0'
                        dtype = 'secondary'
                    else:
                        label = f'Disk ({mount})'
                        icon = '\uf0a0'
                        dtype = 'disk'

                    raw_pct = use_pct.rstrip('%')
                    pct = (int(raw_pct) if raw_pct.isdigit() else 0) / 100.0
                    disks.append({
                        'label': label,
                        'mount': mount,
                        'size': size,
                        'used': used,
                        'avail': avail,
                        'pct': pct,
                        'icon': icon,
                        'type': dtype
                    })
        except Exception:
            pass

    print(json.dumps(disks))

if __name__ == '__main__':
    get_disks()
