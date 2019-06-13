#include <iostream>
#include <vendor/huawei/hardware/light/2.0/IHwLight.h>
#include <android/hardware/light/2.0/types.h>

using ::vendor::huawei::hardware::light::V2_0::IHwLight;
using ::android::sp;

int main(int argc, char **argv) {
	auto svc = IHwLight::getService();
	svc->HWgetSupportedTypes([](auto types) {
		for(const auto& type: types) {
			std::cout << "Got type " << type << std::endl;
		}
	});


	uint32_t a = (uint32_t)strtoll(argv[1], NULL, 10);
	uint32_t b = (uint32_t)strtoll(argv[2], NULL, 10);
	auto ret = svc->HWsetLightBrightness(a, b);
	std::cout << "Set light brightness returned " << toString(ret) << std::endl;
}
