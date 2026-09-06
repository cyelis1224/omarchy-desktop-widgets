#!/usr/bin/env python3
import os
import json
import subprocess

def format_bytes(n):
    for unit in ['B', 'K', 'M', 'G', 'T']:
        if n < 1024.0:
            return f"{n:.0f}{unit}" if unit in ['B', 'K'] else f"{n:.0f}{unit}"
        n /= 1024.0
    return f"{n:.0f}P"

def get_disks():
    disks = []
    seen_devs = set()
    
    # 1. Native /proc/mounts + os.statvfs (Fast, robust, immune to broken FUSE endpoints)
    try:
        if os.path.exists('/proc/mounts'):
            with open('/proc/mounts', 'r') as f:
                for line in f:
                    parts = line.split()
                    if len(parts) >= 3:
                        fs, mount, fstype = parts[0], parts[1], parts[2]
                        if fstype in ['tmpfs', 'devtmpfs', 'efivarfs', 'overlay', 'squashfs', 'proc', 'sysfs', 'devpts', 'cgroup', 'cgroup2', 'securityfs', 'pstore', 'autofs', 'mqueue', 'hugetlbfs', 'debugfs', 'tracefs', 'fusectl', 'configfs', 'ramfs', 'binfmt_misc', 'bpf', 'fuse']:
                            continue
                        if not fs.startswith('/dev/'):
                            continue
                        if mount == '/boot' or mount.startswith('/boot/'):
                            continue
                        if fs in seen_devs and mount != '/':
                            continue
                        seen_devs.add(fs)
                        
                        try:
                            st = os.statvfs(mount)
                            total = st.f_blocks * st.f_frsize
                            free = st.f_bavail * st.f_frsize
                            used = total - free
                            pct = (used / total) if total > 0 else 0.0
                            
                            # Form readable label
                            if mount == '/':
                                label = 'Root Storage (/)'
                            elif mount.startswith('/run/media/') or mount.startswith('/media/') or mount.startswith('/mnt/'):
                                dev_name = fs.split('/')[-1]
                                label = f'Secondary ({dev_name})'
                            else:
                                label = f'Disk ({mount})'
                                
                            disks.append({
                                'label': label,
                                'mount': mount,
                                'size': format_bytes(total),
                                'used': format_bytes(used),
                                'avail': format_bytes(free),
                                'pct': round(pct, 2)
                            })
                        except Exception:
                            pass
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
                    if mount.startswith('/boot') or not fs.startswith('/dev/'):
                        continue
                    if fs in seen_devs and mount != '/':
                        continue
                    seen_devs.add(fs)
                    
                    label = 'Root Storage (/)' if mount == '/' else f'Secondary ({fs.split("/")[-1]})'
                    raw_pct = use_pct.rstrip('%')
                    pct = (int(raw_pct) if raw_pct.isdigit() else 0) / 100.0
                    disks.append({
                        'label': label,
                        'mount': mount,
                        'size': size,
                        'used': used,
                        'avail': avail,
                        'pct': pct
                    })
        except Exception:
            pass

    print(json.dumps(disks))

if __name__ == '__main__':
    get_disks()
