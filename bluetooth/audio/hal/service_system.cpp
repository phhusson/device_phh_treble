/*
 * Copyright (C) 2022 The Android Open Source Project
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

#define LOG_TAG "BtAudioAIDLServiceSystem"

#include <signal.h>

#include <android/binder_manager.h>
#include <android/binder_process.h>
#include <utils/Log.h>
#include <hidl/HidlTransportSupport.h>
#include <hidl/LegacySupport.h>
#include <hwbinder/ProcessState.h>
#include <binder/ProcessState.h>

#include PATH(android/hardware/audio/FILE_VERSION/IDevicesFactory.h)

#include <hardware/audio.h>

#include "BluetoothAudioProviderFactory.h"
#include "DevicesFactory.h"

//using namespace android::hardware;
using ::aidl::android::hardware::bluetooth::audio::
    BluetoothAudioProviderFactory;

using ::android::hardware::audio::CPP_VERSION::implementation::DevicesFactory;
using namespace ::android::hardware::audio::CPP_VERSION;

int main() {
  signal(SIGPIPE, SIG_IGN);

  ::android::hardware::configureRpcThreadpool(16, true);
  ::android::ProcessState::initWithDriver("/dev/binder");
  // start a threadpool for binder / hwbinder interactions
  ::android::ProcessState::self()->startThreadPool();
  ::android::hardware::ProcessState::self()->startThreadPool();

  auto factory = ::ndk::SharedRefBase::make<BluetoothAudioProviderFactory>();
  const std::string instance_name =
      std::string() + BluetoothAudioProviderFactory::descriptor + "/sysbta";
  binder_status_t aidl_status = AServiceManager_addService(
      factory->asBinder().get(), instance_name.c_str());
  ALOGW_IF(aidl_status != STATUS_OK, "Could not register %s, status=%d",
           instance_name.c_str(), aidl_status);

  ::android::sp<IDevicesFactory> audio_factory = new DevicesFactory();
  ::android::status_t hidl_status = audio_factory->registerAsService("sysbta");
  ALOGW_IF(hidl_status != STATUS_OK, "Could not register sysbta, status=%d", hidl_status);

  ::android::hardware::joinRpcThreadpool();
}
