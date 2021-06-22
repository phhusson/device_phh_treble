/*
 * Copyright (C) 2017 The Android Open Source Project
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
#define LOG_TAG "android.hardware.vibrator@1.3-service.meizu"

#include <android/hardware/vibrator/1.3/IVibrator.h>
#include <hidl/HidlSupport.h>
#include <hidl/HidlTransportSupport.h>
#include <utils/Errors.h>
#include <utils/StrongPointer.h>

#include "Vibrator.h"

using android::hardware::configureRpcThreadpool;
using android::hardware::joinRpcThreadpool;
using android::hardware::vibrator::V1_3::IVibrator;
using android::hardware::vibrator::V1_3::implementation::Vibrator;
using namespace android;

static const char *CONTROL_PATH_TIMEOUT = "/sys/class/timed_output/vibrator/enable";
static const char *PATH_WAVE_NUMBER = "/sys/class/meizu/motor/waveform";
static const char *CONTROL_PATH_EFFECT = "/sys/class/meizu/motor/on_off";

status_t registerVibratorService() {
    std::ofstream timeoutAndAmplitude{CONTROL_PATH_TIMEOUT};
    if (!timeoutAndAmplitude) {
        int error = errno;
        ALOGE("Failed to open %s (%d): %s", CONTROL_PATH_TIMEOUT, error, strerror(error));
        return -error;
    }

    std::ofstream waveNumber{PATH_WAVE_NUMBER};
    if (!waveNumber) {
        int error = errno;
        ALOGE("Failed to open %s (%d): %s", PATH_WAVE_NUMBER, error, strerror(error));
        return -error;
    }

    std::ofstream effectTrigger{CONTROL_PATH_EFFECT};
    if (!effectTrigger) {
        int error = errno;
        ALOGE("Failed to open %s (%d): %s", CONTROL_PATH_EFFECT, error, strerror(error));
        return -error;
    }

    sp<IVibrator> vibrator = new Vibrator(std::move(timeoutAndAmplitude), std::move(waveNumber), std::move(effectTrigger));
    (void) vibrator->registerAsService(); // suppress unused-result warning
    return OK;
}

int main() {
    configureRpcThreadpool(1, true);
    status_t status = registerVibratorService();

    if (status != OK) {
        return status;
    }

    joinRpcThreadpool();
}
