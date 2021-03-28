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

#ifndef LPTOOLS_STATIC
#include <android/hardware/boot/1.1/IBootControl.h>
#include <android/hardware/boot/1.1/types.h>
#endif

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

inline bool ends_with(std::string const & value, std::string const & ending)
{
    if (ending.size() > value.size()) return false;
    return std::equal(ending.rbegin(), ending.rend(), value.rbegin());
}

std::string findGroup(std::unique_ptr<MetadataBuilder>& builder) {
    auto groups = builder->ListGroups();

    auto partitionName = "system" + ::android::base::GetProperty("ro.boot.slot_suffix", "");
    for(auto groupName: groups) {
        auto partitions = builder->ListPartitionsInGroup(groupName);
        for (const auto& partition : partitions) {
            if(partition->name() == partitionName) {
                return groupName;
            }
        }
    }

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
        auto result = builder->ResizePartition(partition, size);
        std::cout << "Growing partition " << result << std::endl;
        if(!result) return 1;
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
        if(srcPartition == nullptr) {
            srcPartition = builder->FindPartition(src + ::android::base::GetProperty("ro.boot.slot_suffix", ""));
        }
        auto dstPartition = builder->FindPartition(dst);
        if(dstPartition == nullptr) {
            dstPartition = builder->FindPartition(dst + ::android::base::GetProperty("ro.boot.slot_suffix", ""));
        }
        std::string dstPartitionName = dst;
        if(dstPartition != nullptr) {
            dstPartitionName = dstPartition->name();
        }
        std::vector<std::unique_ptr<Extent>> originalExtents;

        const auto& extents = srcPartition->extents();
        for(unsigned i=0; i<extents.size(); i++) {
            const auto& extend = extents[i];
            auto linear = extend->AsLinearExtent();
            if(linear != nullptr) {
                auto copyLinear = std::make_unique<LinearExtent>(linear->num_sectors(), linear->device_index(), linear->physical_sector());
                originalExtents.push_back(std::move(copyLinear));
            } else {
                auto copyZero = std::make_unique<ZeroExtent>(extend->num_sectors());
                originalExtents.push_back(std::move(copyZero));
            }
        }
        builder->RemovePartition(srcPartition->name());
        builder->RemovePartition(dstPartitionName);
        auto newDstPartition = builder->AddPartition(dstPartitionName, group, 0);
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
    } else if(strcmp(argv[1], "free") == 0) {
        if(argc != 2) {
            std::cerr << "Usage: " << argv[0] << " free" << std::endl;
            exit(1);
        }
        auto groupO = builder->FindGroup(group);
        uint64_t maxSize = groupO->maximum_size();

        uint64_t total = 0;
        auto partitions = builder->ListPartitionsInGroup(group);
        for (const auto& partition : partitions) {
            total += partition->BytesOnDisk();
        }

        uint64_t groupAllocatable = maxSize - total;
        uint64_t superFreeSpace = builder->AllocatableSpace() - builder->UsedSpace();
        if(groupAllocatable > superFreeSpace || maxSize == 0)
            groupAllocatable = superFreeSpace;

        printf("Free space: %" PRIu64 "\n", groupAllocatable);

        exit(0);
    } else if(strcmp(argv[1], "unlimited-group") == 0) {
        builder->ChangeGroupSize(group, 0);
        saveToDisk(std::move(builder));
        return 0;
    } else if(strcmp(argv[1], "clear-cow") == 0) {
#ifndef LPTOOLS_STATIC
        // Ensure this is a V AB device, and that no merging is taking place (merging? in gsi? uh)
        auto svc1_1 = ::android::hardware::boot::V1_1::IBootControl::tryGetService();
        if(svc1_1 == nullptr) {
            std::cerr << "Couldn't get a bootcontrol HAL. You can clear cow only on V AB devices" << std::endl;
            return 1;
        }
        auto mergeStatus = svc1_1->getSnapshotMergeStatus();
        if(mergeStatus != ::android::hardware::boot::V1_1::MergeStatus::NONE) {
            std::cerr << "Merge status is NOT none, meaning a merge is pending. Clearing COW isn't safe" << std::endl;
            return 1;
        }
#endif

        uint64_t superFreeSpace = builder->AllocatableSpace() - builder->UsedSpace();
        std::cerr << "Super allocatable " << superFreeSpace << std::endl;

        uint64_t total = 0;
        auto partitions = builder->ListPartitionsInGroup("cow");
        for (const auto& partition : partitions) {
            std::cout << "Deleting partition? " << partition->name() << std::endl;
            if(ends_with(partition->name(), "-cow")) {
                std::cout << "Deleting partition " << partition->name() << std::endl;
                builder->RemovePartition(partition->name());
            }
        }
        saveToDisk(std::move(builder));
        return 0;
    }

    return 0;
}
