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

add:
	vagrant box add --force --name sqlambda/freebsd14 $(BOX)

clean:
	rm -rf build
