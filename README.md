# sqlambda/freebsd14

A FreeBSD 14 Vagrant box for the **libvirt** provider, amd64, built with
Packer from the official release ISO. Current release: **14.5**.

The box name follows the FreeBSD **major** version. The box version follows
the **point release**: `14.5.0` is the first build of 14.5-RELEASE, and
`14.5.1` onwards are rebuilds of it (errata, security advisories, template
fixes). Pin one with `config.vm.box_version`.

## What the box provides

- `vagrant` user, password `vagrant`, the Vagrant insecure keypair (RSA and
  ed25519), passwordless `sudo`. Root password is `vagrant`.
- `sshd` at boot, DHCP on the first NIC (virtio).
- Base system updated with `freebsd-update` to the latest patch level at build
  time, and `pkg` bootstrapped against the default repository for that release.
- Python 3.12 at `/usr/local/bin/python3`, so Ansible's interpreter discovery
  finds it. 3.12 is FreeBSD's default Python, the only version `py3*-`
  packages such as `py312-psycopg2` are built for.
- Root filesystem UFS, grown to fill the disk on boot (`growfs`), no swap.
- No synced folder (FreeBSD base has no rsync).

## Root disk

**Root is `da0`**, on a virtio-scsi controller. The box's Vagrantfile sets
`disk_bus = "scsi"`, the same as `generic/freebsd14`, so it drops in for it.

Any disk you attach with `:bus => 'virtio'` is virtio-blk and numbers from
**`vtbd0`**, in attach order.

If you override `disk_bus` to `virtio`, root becomes `vtbd0` and your attached
disks shift to `vtbd1` onwards. The box still boots either way, because root is
mounted by label (`/dev/gpt/rootfs`), but any path you hard-code to a data
disk moves by one.

## Build

Needs only **Docker** and **`/dev/kvm`** on the host. Packer, its qemu and
vagrant plugins, and QEMU all run in a container built from the `Dockerfile`
(`make image`). The plugins are compiled from their release tags, so the build
does not depend on HashiCorp's plugin release service. Vagrant is needed only
to use the box, not to build it.

    make box            # ISO → build/sqlambda-freebsd14-14.5.0-libvirt-amd64.box
    make add            # vagrant box add it locally as sqlambda/freebsd14, version 14.5.0

The ISO is cached in `packer_cache/`, so rebuilds do not download it again.

A new point release changes `iso_url`, `iso_checksum` (copied from FreeBSD's
`CHECKSUM.SHA256-*` file, never computed locally) and `box_version`.

## License

Apache 2.0 — see [LICENSE](LICENSE).
