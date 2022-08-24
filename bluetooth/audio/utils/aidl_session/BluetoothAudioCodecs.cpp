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

#define LOG_TAG "BTAudioCodecsAidl"

#include "BluetoothAudioCodecs.h"

#include <aidl/android/hardware/bluetooth/audio/AacCapabilities.h>
#include <aidl/android/hardware/bluetooth/audio/AacObjectType.h>
#include <aidl/android/hardware/bluetooth/audio/AptxCapabilities.h>
#include <aidl/android/hardware/bluetooth/audio/ChannelMode.h>
#include <aidl/android/hardware/bluetooth/audio/LdacCapabilities.h>
#include <aidl/android/hardware/bluetooth/audio/LdacChannelMode.h>
#include <aidl/android/hardware/bluetooth/audio/LdacQualityIndex.h>
#include <aidl/android/hardware/bluetooth/audio/LeAudioConfiguration.h>
#include <aidl/android/hardware/bluetooth/audio/OpusCapabilities.h>
#include <aidl/android/hardware/bluetooth/audio/OpusConfiguration.h>
#include <aidl/android/hardware/bluetooth/audio/SbcCapabilities.h>
#include <aidl/android/hardware/bluetooth/audio/SbcChannelMode.h>
#include <android-base/logging.h>

namespace aidl {
namespace android {
namespace hardware {
namespace bluetooth {
namespace audio {

static const PcmCapabilities kDefaultSoftwarePcmCapabilities = {
    .sampleRateHz = {16000, 24000, 32000, 44100, 48000, 88200, 96000},
    .channelMode = {ChannelMode::MONO, ChannelMode::STEREO},
    .bitsPerSample = {16, 24, 32},
    .dataIntervalUs = {},
};

static const SbcCapabilities kDefaultOffloadSbcCapability = {
    .sampleRateHz = {44100},
    .channelMode = {SbcChannelMode::MONO, SbcChannelMode::JOINT_STEREO},
    .blockLength = {4, 8, 12, 16},
    .numSubbands = {8},
    .allocMethod = {SbcAllocMethod::ALLOC_MD_L},
    .bitsPerSample = {16},
    .minBitpool = 2,
    .maxBitpool = 53};

static const AacCapabilities kDefaultOffloadAacCapability = {
    .objectType = {AacObjectType::MPEG2_LC},
    .sampleRateHz = {44100},
    .channelMode = {ChannelMode::STEREO},
    .variableBitRateSupported = true,
    .bitsPerSample = {16}};

static const LdacCapabilities kDefaultOffloadLdacCapability = {
    .sampleRateHz = {44100, 48000, 88200, 96000},
    .channelMode = {LdacChannelMode::DUAL, LdacChannelMode::STEREO},
    .qualityIndex = {LdacQualityIndex::HIGH},
    .bitsPerSample = {16, 24, 32}};

static const AptxCapabilities kDefaultOffloadAptxCapability = {
    .sampleRateHz = {44100, 48000},
    .channelMode = {ChannelMode::STEREO},
    .bitsPerSample = {16},
};

static const AptxCapabilities kDefaultOffloadAptxHdCapability = {
    .sampleRateHz = {44100, 48000},
    .channelMode = {ChannelMode::STEREO},
    .bitsPerSample = {24},
};

static const OpusCapabilities kDefaultOffloadOpusCapability = {
    .samplingFrequencyHz = {48000},
    .frameDurationUs = {10000, 20000},
    .channelMode = {ChannelMode::MONO, ChannelMode::STEREO},
};

const std::vector<CodecCapabilities> kDefaultOffloadA2dpCodecCapabilities = {
    {.codecType = CodecType::SBC, .capabilities = {}},
    {.codecType = CodecType::AAC, .capabilities = {}},
    {.codecType = CodecType::LDAC, .capabilities = {}},
    {.codecType = CodecType::APTX, .capabilities = {}},
    {.codecType = CodecType::APTX_HD, .capabilities = {}},
    {.codecType = CodecType::OPUS, .capabilities = {}}};

std::vector<LeAudioCodecCapabilitiesSetting> kDefaultOffloadLeAudioCapabilities;

static const UnicastCapability kInvalidUnicastCapability = {
    .codecType = CodecType::UNKNOWN};

static const BroadcastCapability kInvalidBroadcastCapability = {
    .codecType = CodecType::UNKNOWN};

// Default Supported Codecs
// LC3 16_1: sample rate: 16 kHz, frame duration: 7.5 ms, octets per frame: 30
static const Lc3Capabilities kLc3Capability_16_1 = {
    .samplingFrequencyHz = {16000},
    .frameDurationUs = {7500},
    .octetsPerFrame = {30}};

// Default Supported Codecs
// LC3 16_2: sample rate: 16 kHz, frame duration: 10 ms, octets per frame: 40
static const Lc3Capabilities kLc3Capability_16_2 = {
    .samplingFrequencyHz = {16000},
    .frameDurationUs = {10000},
    .octetsPerFrame = {40}};

// Default Supported Codecs
// LC3 24_2: sample rate: 24 kHz, frame duration: 10 ms, octets per frame: 60
static const Lc3Capabilities kLc3Capability_24_2 = {
    .samplingFrequencyHz = {24000},
    .frameDurationUs = {10000},
    .octetsPerFrame = {60}};

// Default Supported Codecs
// LC3 32_2: sample rate: 32 kHz, frame duration: 10 ms, octets per frame: 80
static const Lc3Capabilities kLc3Capability_32_2 = {
    .samplingFrequencyHz = {32000},
    .frameDurationUs = {10000},
    .octetsPerFrame = {80}};

// Default Supported Codecs
// LC3 48_4: sample rate: 48 kHz, frame duration: 10 ms, octets per frame: 120
static const Lc3Capabilities kLc3Capability_48_4 = {
    .samplingFrequencyHz = {48000},
    .frameDurationUs = {10000},
    .octetsPerFrame = {120}};

static const std::vector<Lc3Capabilities> supportedLc3CapabilityList = {
    kLc3Capability_48_4, kLc3Capability_32_2, kLc3Capability_24_2,
    kLc3Capability_16_2, kLc3Capability_16_1};

static AudioLocation stereoAudio = static_cast<AudioLocation>(
    static_cast<uint8_t>(AudioLocation::FRONT_LEFT) |
    static_cast<uint8_t>(AudioLocation::FRONT_RIGHT));
static AudioLocation monoAudio = AudioLocation::UNKNOWN;

// Stores the supported setting of audio location, connected device, and the
// channel count for each device
std::vector<std::tuple<AudioLocation, uint8_t, uint8_t>>
    supportedDeviceSetting = {
        // Stereo, two connected device, one for L one for R
        std::make_tuple(stereoAudio, 2, 1),
        // Stereo, one connected device for both L and R
        std::make_tuple(stereoAudio, 1, 2),
        // Mono
        std::make_tuple(monoAudio, 1, 1)};

template <class T>
bool BluetoothAudioCodecs::ContainedInVector(
    const std::vector<T>& vector, const typename identity<T>::type& target) {
  return std::find(vector.begin(), vector.end(), target) != vector.end();
}

bool BluetoothAudioCodecs::IsOffloadSbcConfigurationValid(
    const CodecConfiguration::CodecSpecific& codec_specific) {
  if (codec_specific.getTag() != CodecConfiguration::CodecSpecific::sbcConfig) {
    LOG(WARNING) << __func__
                 << ": Invalid CodecSpecific=" << codec_specific.toString();
    return false;
  }
  const SbcConfiguration sbc_data =
      codec_specific.get<CodecConfiguration::CodecSpecific::sbcConfig>();

  if (ContainedInVector(kDefaultOffloadSbcCapability.sampleRateHz,
                        sbc_data.sampleRateHz) &&
      ContainedInVector(kDefaultOffloadSbcCapability.blockLength,
                        sbc_data.blockLength) &&
      ContainedInVector(kDefaultOffloadSbcCapability.numSubbands,
                        sbc_data.numSubbands) &&
      ContainedInVector(kDefaultOffloadSbcCapability.bitsPerSample,
                        sbc_data.bitsPerSample) &&
      ContainedInVector(kDefaultOffloadSbcCapability.channelMode,
                        sbc_data.channelMode) &&
      ContainedInVector(kDefaultOffloadSbcCapability.allocMethod,
                        sbc_data.allocMethod) &&
      sbc_data.minBitpool <= sbc_data.maxBitpool &&
      kDefaultOffloadSbcCapability.minBitpool <= sbc_data.minBitpool &&
      kDefaultOffloadSbcCapability.maxBitpool >= sbc_data.maxBitpool) {
    return true;
  }
  LOG(WARNING) << __func__
               << ": Unsupported CodecSpecific=" << codec_specific.toString();
  return false;
}

bool BluetoothAudioCodecs::IsOffloadAacConfigurationValid(
    const CodecConfiguration::CodecSpecific& codec_specific) {
  if (codec_specific.getTag() != CodecConfiguration::CodecSpecific::aacConfig) {
    LOG(WARNING) << __func__
                 << ": Invalid CodecSpecific=" << codec_specific.toString();
    return false;
  }
  const AacConfiguration aac_data =
      codec_specific.get<CodecConfiguration::CodecSpecific::aacConfig>();

  if (ContainedInVector(kDefaultOffloadAacCapability.sampleRateHz,
                        aac_data.sampleRateHz) &&
      ContainedInVector(kDefaultOffloadAacCapability.bitsPerSample,
                        aac_data.bitsPerSample) &&
      ContainedInVector(kDefaultOffloadAacCapability.channelMode,
                        aac_data.channelMode) &&
      ContainedInVector(kDefaultOffloadAacCapability.objectType,
                        aac_data.objectType) &&
      (!aac_data.variableBitRateEnabled ||
       kDefaultOffloadAacCapability.variableBitRateSupported)) {
    return true;
  }
  LOG(WARNING) << __func__
               << ": Unsupported CodecSpecific=" << codec_specific.toString();
  return false;
}

bool BluetoothAudioCodecs::IsOffloadLdacConfigurationValid(
    const CodecConfiguration::CodecSpecific& codec_specific) {
  if (codec_specific.getTag() !=
      CodecConfiguration::CodecSpecific::ldacConfig) {
    LOG(WARNING) << __func__
                 << ": Invalid CodecSpecific=" << codec_specific.toString();
    return false;
  }
  const LdacConfiguration ldac_data =
      codec_specific.get<CodecConfiguration::CodecSpecific::ldacConfig>();

  if (ContainedInVector(kDefaultOffloadLdacCapability.sampleRateHz,
                        ldac_data.sampleRateHz) &&
      ContainedInVector(kDefaultOffloadLdacCapability.bitsPerSample,
                        ldac_data.bitsPerSample) &&
      ContainedInVector(kDefaultOffloadLdacCapability.channelMode,
                        ldac_data.channelMode) &&
      ContainedInVector(kDefaultOffloadLdacCapability.qualityIndex,
                        ldac_data.qualityIndex)) {
    return true;
  }
  LOG(WARNING) << __func__
               << ": Unsupported CodecSpecific=" << codec_specific.toString();
  return false;
}

bool BluetoothAudioCodecs::IsOffloadAptxConfigurationValid(
    const CodecConfiguration::CodecSpecific& codec_specific) {
  if (codec_specific.getTag() !=
      CodecConfiguration::CodecSpecific::aptxConfig) {
    LOG(WARNING) << __func__
                 << ": Invalid CodecSpecific=" << codec_specific.toString();
    return false;
  }
  const AptxConfiguration aptx_data =
      codec_specific.get<CodecConfiguration::CodecSpecific::aptxConfig>();

  if (ContainedInVector(kDefaultOffloadAptxCapability.sampleRateHz,
                        aptx_data.sampleRateHz) &&
      ContainedInVector(kDefaultOffloadAptxCapability.bitsPerSample,
                        aptx_data.bitsPerSample) &&
      ContainedInVector(kDefaultOffloadAptxCapability.channelMode,
                        aptx_data.channelMode)) {
    return true;
  }
  LOG(WARNING) << __func__
               << ": Unsupported CodecSpecific=" << codec_specific.toString();
  return false;
}

bool BluetoothAudioCodecs::IsOffloadAptxHdConfigurationValid(
    const CodecConfiguration::CodecSpecific& codec_specific) {
  if (codec_specific.getTag() !=
      CodecConfiguration::CodecSpecific::aptxConfig) {
    LOG(WARNING) << __func__
                 << ": Invalid CodecSpecific=" << codec_specific.toString();
    return false;
  }
  const AptxConfiguration aptx_data =
      codec_specific.get<CodecConfiguration::CodecSpecific::aptxConfig>();

  if (ContainedInVector(kDefaultOffloadAptxHdCapability.sampleRateHz,
                        aptx_data.sampleRateHz) &&
      ContainedInVector(kDefaultOffloadAptxHdCapability.bitsPerSample,
                        aptx_data.bitsPerSample) &&
      ContainedInVector(kDefaultOffloadAptxHdCapability.channelMode,
                        aptx_data.channelMode)) {
    return true;
  }
  LOG(WARNING) << __func__
               << ": Unsupported CodecSpecific=" << codec_specific.toString();
  return false;
}

bool BluetoothAudioCodecs::IsOffloadOpusConfigurationValid(
    const CodecConfiguration::CodecSpecific& codec_specific) {
  if (codec_specific.getTag() !=
      CodecConfiguration::CodecSpecific::opusConfig) {
    LOG(WARNING) << __func__
                 << ": Invalid CodecSpecific=" << codec_specific.toString();
    return false;
  }
  std::optional<OpusConfiguration> opus_data =
      codec_specific.get<CodecConfiguration::CodecSpecific::opusConfig>();

  if (opus_data.has_value() &&
      ContainedInVector(kDefaultOffloadOpusCapability.samplingFrequencyHz,
                        opus_data->samplingFrequencyHz) &&
      ContainedInVector(kDefaultOffloadOpusCapability.frameDurationUs,
                        opus_data->frameDurationUs) &&
      ContainedInVector(kDefaultOffloadOpusCapability.channelMode,
                        opus_data->channelMode)) {
    return true;
  }
  LOG(WARNING) << __func__
               << ": Unsupported CodecSpecific=" << codec_specific.toString();
  return false;
}

bool BluetoothAudioCodecs::IsOffloadLeAudioConfigurationValid(
    const SessionType& session_type, const LeAudioConfiguration&) {
  if (session_type !=
          SessionType::LE_AUDIO_HARDWARE_OFFLOAD_ENCODING_DATAPATH &&
      session_type !=
          SessionType::LE_AUDIO_HARDWARE_OFFLOAD_DECODING_DATAPATH &&
      session_type !=
          SessionType::LE_AUDIO_BROADCAST_HARDWARE_OFFLOAD_ENCODING_DATAPATH) {
    return false;
  }
  return true;
}

std::vector<PcmCapabilities>
BluetoothAudioCodecs::GetSoftwarePcmCapabilities() {
  return {kDefaultSoftwarePcmCapabilities};
}

std::vector<CodecCapabilities>
BluetoothAudioCodecs::GetA2dpOffloadCodecCapabilities(
    const SessionType& session_type) {
  if (session_type != SessionType::A2DP_HARDWARE_OFFLOAD_ENCODING_DATAPATH &&
      session_type != SessionType::A2DP_HARDWARE_OFFLOAD_DECODING_DATAPATH) {
    return {};
  }
  std::vector<CodecCapabilities> offload_a2dp_codec_capabilities =
      kDefaultOffloadA2dpCodecCapabilities;
  for (auto& codec_capability : offload_a2dp_codec_capabilities) {
    switch (codec_capability.codecType) {
      case CodecType::SBC:
        codec_capability.capabilities
            .set<CodecCapabilities::Capabilities::sbcCapabilities>(
                kDefaultOffloadSbcCapability);
        break;
      case CodecType::AAC:
        codec_capability.capabilities
            .set<CodecCapabilities::Capabilities::aacCapabilities>(
                kDefaultOffloadAacCapability);
        break;
      case CodecType::LDAC:
        codec_capability.capabilities
            .set<CodecCapabilities::Capabilities::ldacCapabilities>(
                kDefaultOffloadLdacCapability);
        break;
      case CodecType::APTX:
        codec_capability.capabilities
            .set<CodecCapabilities::Capabilities::aptxCapabilities>(
                kDefaultOffloadAptxCapability);
        break;
      case CodecType::APTX_HD:
        codec_capability.capabilities
            .set<CodecCapabilities::Capabilities::aptxCapabilities>(
                kDefaultOffloadAptxHdCapability);
        break;
      case CodecType::OPUS:
        codec_capability.capabilities
            .set<CodecCapabilities::Capabilities::opusCapabilities>(
                kDefaultOffloadOpusCapability);
        break;
      case CodecType::UNKNOWN:
      case CodecType::VENDOR:
      case CodecType::LC3:
      case CodecType::APTX_ADAPTIVE:
        break;
    }
  }
  return offload_a2dp_codec_capabilities;
}

bool BluetoothAudioCodecs::IsSoftwarePcmConfigurationValid(
    const PcmConfiguration& pcm_config) {
  if (ContainedInVector(kDefaultSoftwarePcmCapabilities.sampleRateHz,
                        pcm_config.sampleRateHz) &&
      ContainedInVector(kDefaultSoftwarePcmCapabilities.bitsPerSample,
                        pcm_config.bitsPerSample) &&
      ContainedInVector(kDefaultSoftwarePcmCapabilities.channelMode,
                        pcm_config.channelMode)
      // data interval is not checked for now
      // && pcm_config.dataIntervalUs != 0
  ) {
    return true;
  }
  LOG(WARNING) << __func__
               << ": Unsupported CodecSpecific=" << pcm_config.toString();
  return false;
}

bool BluetoothAudioCodecs::IsOffloadCodecConfigurationValid(
    const SessionType& session_type, const CodecConfiguration& codec_config) {
  if (session_type != SessionType::A2DP_HARDWARE_OFFLOAD_ENCODING_DATAPATH &&
      session_type != SessionType::A2DP_HARDWARE_OFFLOAD_DECODING_DATAPATH) {
    LOG(ERROR) << __func__
               << ": Invalid SessionType=" << toString(session_type);
    return false;
  }
  const CodecConfiguration::CodecSpecific& codec_specific = codec_config.config;
  switch (codec_config.codecType) {
    case CodecType::SBC:
      if (IsOffloadSbcConfigurationValid(codec_specific)) {
        return true;
      }
      break;
    case CodecType::AAC:
      if (IsOffloadAacConfigurationValid(codec_specific)) {
        return true;
      }
      break;
    case CodecType::LDAC:
      if (IsOffloadLdacConfigurationValid(codec_specific)) {
        return true;
      }
      break;
    case CodecType::APTX:
      if (IsOffloadAptxConfigurationValid(codec_specific)) {
        return true;
      }
      break;
    case CodecType::APTX_HD:
      if (IsOffloadAptxHdConfigurationValid(codec_specific)) {
        return true;
      }
      break;
    case CodecType::OPUS:
      if (IsOffloadOpusConfigurationValid(codec_specific)) {
        return true;
      }
      break;
    case CodecType::APTX_ADAPTIVE:
    case CodecType::LC3:
    case CodecType::UNKNOWN:
    case CodecType::VENDOR:
      break;
  }
  return false;
}

UnicastCapability composeUnicastLc3Capability(
    AudioLocation audioLocation, uint8_t deviceCnt, uint8_t channelCount,
    const Lc3Capabilities& capability) {
  return {
      .codecType = CodecType::LC3,
      .supportedChannel = audioLocation,
      .deviceCount = deviceCnt,
      .channelCountPerDevice = channelCount,
      .leAudioCodecCapabilities =
          UnicastCapability::LeAudioCodecCapabilities(capability),
  };
}

std::vector<LeAudioCodecCapabilitiesSetting>
BluetoothAudioCodecs::GetLeAudioOffloadCodecCapabilities(
    const SessionType& session_type) {
  if (session_type !=
          SessionType::LE_AUDIO_HARDWARE_OFFLOAD_ENCODING_DATAPATH &&
      session_type !=
          SessionType::LE_AUDIO_HARDWARE_OFFLOAD_DECODING_DATAPATH &&
      session_type !=
          SessionType::LE_AUDIO_BROADCAST_HARDWARE_OFFLOAD_ENCODING_DATAPATH) {
    return std::vector<LeAudioCodecCapabilitiesSetting>(0);
  }

  if (kDefaultOffloadLeAudioCapabilities.empty()) {
    for (auto [audioLocation, deviceCnt, channelCount] :
         supportedDeviceSetting) {
      for (auto capability : supportedLc3CapabilityList) {
        UnicastCapability lc3Capability = composeUnicastLc3Capability(
            audioLocation, deviceCnt, channelCount, capability);
        UnicastCapability lc3MonoDecodeCapability =
            composeUnicastLc3Capability(monoAudio, 1, 1, capability);

        // Adds the capability for encode only
        kDefaultOffloadLeAudioCapabilities.push_back(
            {.unicastEncodeCapability = lc3Capability,
             .unicastDecodeCapability = kInvalidUnicastCapability,
             .broadcastCapability = kInvalidBroadcastCapability});

        // Adds the capability for decode only
        kDefaultOffloadLeAudioCapabilities.push_back(
            {.unicastEncodeCapability = kInvalidUnicastCapability,
             .unicastDecodeCapability = lc3Capability,
             .broadcastCapability = kInvalidBroadcastCapability});

        // Adds the capability for the case that encode and decode exist at the
        // same time
        kDefaultOffloadLeAudioCapabilities.push_back(
            {.unicastEncodeCapability = lc3Capability,
             .unicastDecodeCapability = lc3MonoDecodeCapability,
             .broadcastCapability = kInvalidBroadcastCapability});
      }
    }
  }

  return kDefaultOffloadLeAudioCapabilities;
}

}  // namespace audio
}  // namespace bluetooth
}  // namespace hardware
}  // namespace android
}  // namespace aidl
