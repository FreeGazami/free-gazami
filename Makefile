.PHONY: build create-img clean run-qemu

# IMG_NAME=$(PACKAGE_NAME)-$(TRIPLE).img
BOOTLOADER=crustlet
KERNEL=gazami

ROOT=$(shell pwd)
BOOTLOADER_PATH=$(ROOT)/$(BOOTLOADER)
KERNEL_PATH=$(ROOT)/$(KERNEL)

build-gazami:
	$(MAKE) -C $(KERNEL_PATH) build

build-crustlet:
	$(MAKE) -C $(BOOTLOADER_PATH) build

generate-meta-json: build-crustlet build-gazami
	jq --slurpfile attribute crustlet/crustlet-build.json -n '{crustlet: $$attribute[0]}' > tmp-build.json
	jq --slurpfile attribute gazami/gazami-build.json '. + {gazami: $$attribute[0]}' tmp-build.json > tmp-combine-build.json
	jq '. + {image_name: (.gazami.package_name + "-" + .gazami.triple)}' tmp-combine-build.json > free-gazami-build.json
	rm tmp-build.json
	rm tmp-combine-build.json

build: generate-meta-json

# Creates a FAT32 image for UEFI boot
# IMG_NAME=$(KERNEL_PACKAGE_NAME)-$(KERNEL_TRIPLE).img

create-img: build
	qemu-img create -f raw $(shell jq -r '.image_name' free-gazami-build.json).img 64M
	mkfs.fat -F 32 $(shell jq -r '.image_name' free-gazami-build.json).img
	mkdir -p efi_mount
	sudo mount -o loop $(shell jq -r '.image_name' free-gazami-build.json).img efi_mount
	sudo mkdir -p efi_mount/EFI/BOOT
	sudo mkdir -p efi_mount/crustlet/
	sudo cp $(BOOTLOADER_PATH)/target/x86_64-unknown-uefi/debug/$(shell jq -r '.crustlet.bin_name' free-gazami-build.json).efi efi_mount/EFI/BOOT/BOOTX64.EFI
	sudo cp $(BOOTLOADER_PATH)/runtime_configs/rEnv.txt efi_mount/rEnv.txt
	sudo cp $(KERNEL_PATH)/target/x86_64-unknown-gazami/debug/gazami efi_mount/gazami
	sudo umount efi_mount
	rm -rf efi_mount

run-qemu: create-img
	qemu-system-x86_64 -bios /usr/share/ovmf/x64/OVMF.4m.fd -drive file=$(shell jq -r '.image_name' free-gazami-build.json).img,format=raw -m 4G -serial file:$(shell pwd)/$(shell date +"%Y-%m-%d-%H:%M:%S").log

clean:
	$(MAKE) -C $(BOOTLOADER_PATH) clean
	$(MAKE) -C $(KERNEL_PATH) clean
	rm -f ./*.img ./*.log ./*.bin ./free-gazami-build.json