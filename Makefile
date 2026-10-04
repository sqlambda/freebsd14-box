# ISO → .box in one step. `make box`, then `make add` to try it locally.
# Packer and QEMU run in a container (see Dockerfile); the host needs only
# Docker and /dev/kvm. Vagrant is needed only for `make add`.
VERSION ?= 14.5.0
BOX     := build/sqlambda-freebsd14-$(VERSION)-libvirt-amd64.box
IMAGE   := freebsd14-box-builder

# Run as the invoking user so build/ and packer_cache/ stay theirs, with the
# host's kvm group so QEMU can open /dev/kvm.
PACKER := docker run --rm --init \
	--device /dev/kvm --group-add $(shell stat -c %g /dev/kvm) \
	--user $(shell id -u):$(shell id -g) \
	--volume $(CURDIR):/work \
	$(IMAGE)

.PHONY: image validate box add clean

image:
	docker build --quiet --tag $(IMAGE) .

validate: image
	$(PACKER) fmt -check freebsd14.pkr.hcl
	$(PACKER) validate -var box_version=$(VERSION) freebsd14.pkr.hcl

box: validate
	rm -rf build/qemu build/*.sha256
	$(PACKER) build -var box_version=$(VERSION) freebsd14.pkr.hcl

# Added through a one-box catalog rather than the bare .box file: a bare file
# always registers as version 0, so a rebuild could not be told apart from the
# build it replaced. The catalog carries VERSION, and the checksum packer wrote.
add: build/metadata.json
	vagrant box add --force build/metadata.json

build/metadata.json: $(BOX).sha256
	printf '{"name":"sqlambda/freebsd14","versions":[{"version":"%s","providers":[{"name":"libvirt","url":"file://%s","checksum_type":"sha256","checksum":"%s"}]}]}\n' \
		$(VERSION) $(abspath $(BOX)) $$(cut -f1 $(BOX).sha256) > $@

clean:
	rm -rf build
