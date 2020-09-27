/*
 * Copyright (C) 2018 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <getopt.h>
#include <inttypes.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/types.h>
#include <sysexits.h>
#include <unistd.h>

#include <iostream>
#include <optional>
#include <regex>
#include <string>
#include <vector>
#include <chrono>

#include <android-base/parseint.h>
#include <android-base/properties.h>
#include <android-base/strings.h>
#include <cutils/android_get_control_file.h>
#include <fs_mgr.h>
#include <liblp/builder.h>
#include <liblp/liblp.h>
#include <fs_mgr_dm_linear.h>
#include <libdm/dm.h>

using namespace android;
using namespace android::fs_mgr;

class FileOrBlockDeviceOpener final : public PartitionOpener {
public:
    android::base::unique_fd Open(const std::string& path, int flags) const override {
        // Try a local file first.
        android::base::unique_fd fd;

#ifdef __ANDROID__
        fd.reset(android_get_control_file(path.c_str()));
        if (fd >= 0) return fd;
#endif
        fd.reset(open(path.c_str(), flags));
        if (fd >= 0) return fd;

        return PartitionOpener::Open(path, flags);
    }
};

static FileOrBlockDeviceOpener opener;
std::unique_ptr<MetadataBuilder> makeBuilder() {
    auto builder = MetadataBuilder::New(opener, "super", 0);
    if(builder == nullptr) {
        std::cout << "Failed creating super builder" << std::endl;
    }
    return builder;
}

void saveToDisk(std::unique_ptr<MetadataBuilder> builder) {
    auto newMetadata = builder->Export();
    int nSlots = 2;//pt->geometry.metadata_slot_count;
    for(int slot=0; slot < nSlots; slot++) {
        std::cout << "Saving the updated partition table " << UpdatePartitionTable(opener, "super", *newMetadata, slot) << " for slot " << slot << std::endl;
    }
}

std::string findGroup(std::unique_ptr<MetadataBuilder>& builder) {
    auto groups = builder->ListGroups();
    std::string maxGroup = "";
    uint64_t maxGroupSize = 0;
    for(auto groupName: groups) {
        auto group = builder->FindGroup(groupName);
        if(group->maximum_size() > maxGroupSize) {
            maxGroup = groupName;
            maxGroupSize = group->maximum_size();
        }
    }

    return maxGroup;
}



int main(int argc, char **argv) {
    if(argc<=1) {
        std::cerr << "Usage: " << argv[0] << " <create|remove|resize|rename>" << std::endl;
        exit(1);
    }
    auto builder = makeBuilder();
    auto group = findGroup(builder);
    std::cout << "Best group seems to be " << group << std::endl;

    if(strcmp(argv[1], "create") == 0) {
        if(argc != 4) {
            std::cerr << "Usage: " << argv[0] << " create <partition name> <partition size>" << std::endl;
            exit(1);
        }
        auto partName = argv[2];
        auto size = strtoll(argv[3], NULL, 0);
        auto partition = builder->FindPartition(partName);
        if(partition != nullptr) {
            std::cerr << "Partition " << partName << " already exists." << std::endl;
            exit(1);
        }
        partition = builder->AddPartition(partName, group, 0);
        std::cout << "Growing partition " << builder->ResizePartition(partition, size) << std::endl;
        saveToDisk(std::move(builder));

        std::string dmPath;
        CreateLogicalPartitionParams params {
                .block_device = "/dev/block/by-name/super",
                .metadata_slot = 0,
                .partition_name = partName,
                .timeout_ms = std::chrono::milliseconds(10000),
                .force_writable = true,
        };
        auto dmCreateRes = android::fs_mgr::CreateLogicalPartition(params, &dmPath);
        std::cout << "Creating dm partition for " << partName << " answered " << dmCreateRes << " at " << dmPath << std::endl;
        exit(0);
    } else if(strcmp(argv[1], "remove") == 0) {
        if(argc != 3) {
            std::cerr << "Usage: " << argv[0] << " remove <partition name>" << std::endl;
            exit(1);
        }
        auto partName = argv[2];
        auto dmState = android::dm::DeviceMapper::Instance().GetState(partName);
        if(dmState == android::dm::DmDeviceState::ACTIVE) {
            android::fs_mgr::DestroyLogicalPartition(partName);
        }
        builder->RemovePartition(partName);
        saveToDisk(std::move(builder));
        exit(0);
    } else if(strcmp(argv[1], "resize") == 0) {
        if(argc != 4) {
            std::cerr << "Usage: " << argv[0] << " resize <partition name> <newsize>" << std::endl;
            exit(1);
        }
        auto partName = argv[2];
        auto size = strtoll(argv[3], NULL, 0);
        auto partition = builder->FindPartition(partName);
        std::cout << "Resizing partition " << builder->ResizePartition(partition, size) << std::endl;
        saveToDisk(std::move(builder));
        exit(0);
    } else if(strcmp(argv[1], "replace") == 0) {
        if(argc != 4) {
            std::cerr << "Usage: " << argv[0] << " replace <original partition name> <new partition name>" << std::endl;
            std::cerr << "This will delete <new partition name> and rename <original partition name> to <new partition name>" << std::endl;
            exit(1);
        }
        auto src = argv[2];
        auto dst = argv[3];
        auto srcPartition = builder->FindPartition(src);
        std::vector<std::unique_ptr<Extent>> originalExtents;

        const auto& extents = srcPartition->extents();
        for(unsigned i=0; i<extents.size(); i++) {
            const auto& extend = extents[i];
            auto linear = extend->AsLinearExtent();
            std::cerr << (linear != nullptr) << std::endl;
            if(linear != nullptr) {
                auto copyLinear = std::make_unique<LinearExtent>(linear->num_sectors(), linear->device_index(), linear->physical_sector());
                originalExtents.push_back(std::move(copyLinear));
            } else {
                auto copyZero = std::make_unique<ZeroExtent>(extend->num_sectors());
                originalExtents.push_back(std::move(copyZero));
            }
        }
        builder->RemovePartition(src);
        builder->RemovePartition(dst);
        auto newDstPartition = builder->AddPartition(dst, group, 0);
        for(auto&& extent: originalExtents) {
            newDstPartition->AddExtent(std::move(extent));
        }
        saveToDisk(std::move(builder));
        exit(0);
    } else if(strcmp(argv[1], "map") == 0) {
        if(argc != 3) {
            std::cerr << "Usage: " << argv[0] << " map <partition name>" << std::endl;
            exit(1);
        }
        auto partName = argv[2];
        std::string dmPath;
        CreateLogicalPartitionParams params {
                .block_device = "/dev/block/by-name/super",
                .metadata_slot = 0,
                .partition_name = partName,
                .timeout_ms = std::chrono::milliseconds(10000),
                .force_writable = true,
        };
        auto dmCreateRes = android::fs_mgr::CreateLogicalPartition(params, &dmPath);
        std::cout << "Creating dm partition for " << partName << " answered " << dmCreateRes << " at " << dmPath << std::endl;
        exit(0);
    } else if(strcmp(argv[1], "unmap") == 0) {
        if(argc != 3) {
            std::cerr << "Usage: " << argv[0] << " unmap <partition name>" << std::endl;
            exit(1);
        }
        auto partName = argv[2];
        auto dmState = android::dm::DeviceMapper::Instance().GetState(partName);
        if(dmState == android::dm::DmDeviceState::ACTIVE) {
            android::fs_mgr::DestroyLogicalPartition(partName);
        }
        exit(0);
    }

    return 0;
}
