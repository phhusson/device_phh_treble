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

#define LOG_TAG "VibratorService"

#include <log/log.h>

#include <hardware/hardware.h>
#include <hardware/vibrator.h>

#include "Vibrator.h"

#include <cinttypes>
#include <cmath>
#include <iostream>
#include <fstream>
#include <thread>
#include <unistd.h>

namespace android {
namespace hardware {
namespace vibrator {
namespace V1_3 {
namespace implementation {

Vibrator::Vibrator(std::ofstream&& timeoutAndAmplitude, std::ofstream&& waveNumber, std::ofstream&& effectTrigger) :
        mTimeoutAndAmplitude(std::move(timeoutAndAmplitude)),
        mWaveNumber(std::move(waveNumber)),
        mEffectTrigger(std::move(effectTrigger)) {}

Return<Status> Vibrator::on(uint32_t timeout_ms) {
    // Wave number 12 for vibrations slightly stronger than stock (13)
    mWaveNumber << 12 << std::endl;
    mTimeoutAndAmplitude << timeout_ms << std::endl;
    if (!mTimeoutAndAmplitude) {
        ALOGE("Failed to turn vibrator on (%d): %s", errno, strerror(errno));
        return Status::UNKNOWN_ERROR;
    }
    return Status::OK;
}

Return<Status> Vibrator::off()  {
    mTimeoutAndAmplitude << 0 << std::endl;
    if (!mTimeoutAndAmplitude) {
        ALOGE("Failed to turn vibrator off (%d): %s", errno, strerror(errno));
        return Status::UNKNOWN_ERROR;
    }
    return Status::OK;
}

Return<bool> Vibrator::supportsAmplitudeControl()  {
    return false;
}

Return<Status> Vibrator::setAmplitude(uint8_t) {
    return Status::UNSUPPORTED_OPERATION;
}

Return<void> Vibrator::perform(V1_0::Effect effect, EffectStrength strength, perform_cb _hidl_cb) {
    return perform<decltype(effect)>(effect, strength, _hidl_cb);
}

Return<void> Vibrator::perform_1_1(V1_1::Effect_1_1 effect, EffectStrength strength, perform_cb _hidl_cb) {
    return perform<decltype(effect)>(effect, strength, _hidl_cb);
}

Return<void> Vibrator::perform_1_2(V1_2::Effect effect, EffectStrength strength, perform_cb _hidl_cb) {
    return perform<decltype(effect)>(effect, strength, _hidl_cb);
}

Return<void> Vibrator::perform_1_3(Effect effect, EffectStrength strength, perform_cb _hidl_cb) {
    return perform<decltype(effect)>(effect, strength, _hidl_cb);
}

Return<bool> Vibrator::supportsExternalControl() {
    return false;
}

Return<Status> Vibrator::setExternalControl(bool) {
    return Status::UNSUPPORTED_OPERATION;
}

Return<void> Vibrator::perform(Effect effect, EffectStrength, perform_cb _hidl_cb) {
    uint32_t id;
    switch (effect) {
        case Effect::CLICK:
            id = 31008;
            break;
        case Effect::DOUBLE_CLICK:
            id = 31003;
            break;
        case Effect::TICK:
        case Effect::TEXTURE_TICK:
            id = 21000;
            break;
        case Effect::THUD:
            id = 30900;
            break;
        case Effect::POP:
            id = 22520;
            break;
        case Effect::HEAVY_CLICK:
            id = 30900;
            break;
        default:
            _hidl_cb(Status::UNSUPPORTED_OPERATION, 0);
            return Void();
    }
    mEffectTrigger << id << std::endl;
    _hidl_cb(Status::OK, 200);
    return Void();
}

template <typename T> Return<void> Vibrator::perform(T effect, EffectStrength strength, perform_cb _hidl_cb) {
    auto validRange = hidl_enum_range<T>();
    if (effect < *validRange.begin() || effect > *std::prev(validRange.end())) {
        _hidl_cb(Status::UNSUPPORTED_OPERATION, 0);
        return Void();
    }
    return perform(static_cast<Effect>(effect), strength, _hidl_cb);
}

}  // namespace implementation
}  // namespace V1_3
}  // namespace vibrator
}  // namespace hardware
}  // namespace android
