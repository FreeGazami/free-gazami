.PHONY: build create-img clean run-qemu

# IMG_NAME=$(PACKAGE_NAME)-$(TRIPLE).img
ROOT=$(shell pwd)
BOOTLOADER=$(ROOT)/crustlet
KERNEL=$(ROOT)/gazami

include .env

all: run-qemu

build-gazami:
	$(MAKE) -C $(KERNEL) build
	cat $(KERNEL)/.*_env >> .env

build-crustlet: 
	$(MAKE) -C $(BOOTLOADER) build
	cat $(BOOTLOADER)/.*_env >> .env

build: build-crustlet build-gazami

# Creates a FAT32 image for UEFI boot
IMG_NAME=$(KERNEL_PACKAGE_NAME)-$(KERNEL_TRIPLE).img

create-img: build
	qemu-img create -f raw $(IMG_NAME) 64M
	mkfs.fat -F 32 $(IMG_NAME)
	mkdir -p efi_mount
	sudo mount -o loop $(IMG_NAME) efi_mount
	sudo mkdir -p efi_mount/EFI/BOOT
	sudo mkdir -p efi_mount/crustlet/
	sudo cp $(BOOTLOADER)/target/x86_64-unknown-uefi/debug/$(BOOT_PACKAGE_NAME).efi efi_mount/EFI/BOOT/BOOTX64.EFI
	sudo cp $(BOOTLOADER)/runtime_configs/rEnv.txt efi_mount/crustlet/rEnv.txt
	sudo cp $(KERNEL)/target/x86_64-unknown-gazami/debug/gazami efi_mount/gazami
	sudo umount efi_mount
	rm -rf efi_mount

run-qemu: create-img
	qemu-system-x86_64 -bios /usr/share/ovmf/x64/OVMF.4m.fd -drive file=$(IMG_NAME),format=raw -m 4G -serial file:$(shell pwd)/$(shell date +"%Y-%m-%d-%H:%M:%S").log

clean:
	$(MAKE) -C $(BOOTLOADER) clean
	$(MAKE) -C $(KERNEL) clean
	rm -f ./*.img ./*.log ./*.bin