#include <string>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/mount.h>
#include <stdio.h>
#include <unistd.h>
#include <libfiemap/image_manager.h>
#include <android-base/file.h>

using namespace std::chrono_literals;
using namespace std::string_literals;
using android::fiemap::IImageManager;

int main(int argc, char **argv) {
	mkdir("/metadata/gsi/phh", 0771);
	chown("/metadata/gsi/phh", 0, 1000);
	mkdir("/data/gsi/phh", 0771);
	chown("/data/gsi/phh", 0, 1000);

	auto imgManager = IImageManager::Open("phh", 0ms);
	if(argc>=2 && strcmp(argv[1], "unmap") == 0) {
		fprintf(stderr, "Unmapping backing image returned %s\n", imgManager->UnmapImageDevice("system_otaphh_a") ? "true" : "false");
		fprintf(stderr, "Unmapping backing image returned %s\n", imgManager->UnmapImageDevice("system_otaphh_b") ? "true" : "false");
		return 0;
	}
	if(argc>=2 && strcmp(argv[1], "switch-slot") == 0) {
		std::string current_slot;
		std::string next_slot;
		if(!android::base::ReadFileToString("/metadata/phh/img", &current_slot)) {
			next_slot = "a";
		} else {
			if(current_slot.c_str()[0] == 'a')
				next_slot = "b";
		}
		mkdir("/metadata/phh", 0700);
		android::base::WriteStringToFile(next_slot, "/metadata/phh/img");
		return 0;
	}
	if(argc>=2 && strcmp(argv[1], "new-slot") == 0) {
		std::string current_slot;
		std::string next_slot;
		if(!android::base::ReadFileToString("/metadata/phh/img", &current_slot)) {
			next_slot = "a";
		} else {
			if(current_slot.c_str()[0] == 'a')
				next_slot = "b";
		}

		std::string imageName = "system_otaphh_"s + next_slot;

		fprintf(stderr, "Unmapping backing image returned %s\n", imgManager->UnmapImageDevice(imageName) ? "true" : "false");
		fprintf(stderr, "Deleting backing image returned %s\n", imgManager->DeleteBackingImage(imageName) ? "true" : "false");
		auto backRes = imgManager->CreateBackingImage(imageName, 4*1024*1024*1024LL, IImageManager::CREATE_IMAGE_DEFAULT, nullptr);
		if(backRes.is_ok()) {
			fprintf(stderr, "Creating system image succeeded\n");
		} else {
			fprintf(stderr, "Creating system image failed\n");
			return -1;
		}

		std::string blockDev;
		fprintf(stderr, "Mapping backing image returned %s\n", imgManager->MapImageDevice(imageName, 0ms, &blockDev) ? "true" : "false");
		fprintf(stderr, "blockdev is %s\n", blockDev.c_str());
		printf("%s\n", blockDev.c_str());
		return 0;
	}
	if(argc>=2 && strcmp(argv[1], "delete-other-slot") == 0) {
		const char* current_slot = getenv("PHH_OTA_SLOT");
		if(current_slot == NULL) {
			imgManager->UnmapImageDevice("system_otaphh_a");
			imgManager->DeleteBackingImage("system_otaphh_a");
			imgManager->UnmapImageDevice("system_otaphh_b");
			imgManager->DeleteBackingImage("system_otaphh_b");
			return 0;
		}
		if(current_slot[0] == 'a') {
			imgManager->UnmapImageDevice("system_otaphh_b");
			imgManager->DeleteBackingImage("system_otaphh_b");
			return 0;
		}
		if(current_slot[0] == 'b') {
			imgManager->UnmapImageDevice("system_otaphh_a");
			imgManager->DeleteBackingImage("system_otaphh_a");
			return 0;
		}
		return 0;
	}

	return 1;
}
