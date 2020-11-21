DEVELOPER?=	$(shell xcode-select -print-path)
PLATFORMS?=	$(DEVELOPER)/Platforms/
CFLAGS?=	-Os -std=c99
LDFLAGS?=	-dynamiclib

DEVICE_SDK?=		iPhoneOS6.1
DEVICE_PLATFORM?=	$(PLATFORMS)/iPhoneOS.platform
DEVICE_ROOT?=		$(DEVICE_PLATFORM)/Developer/SDKs/$(DEVICE_SDK).sdk
DEVICE_CC?=		$(shell xcrun -sdk `echo ${DEVICE_SDK} | tr '[A-Z]' '[a-z]'` -f clang)
DEVICE_CFLAGS?=		-arch armv7 -arch armv7s -isysroot "$(DEVICE_ROOT)" -gdwarf-2 -miphoneos-version-min=3.0 $(CFLAGS)

SIM_SDK?=		iPhoneSimulator6.1
SIM_PLATFORM?=		$(PLATFORMS)/iPhoneSimulator.platform
SIM_ROOT?=		$(SIM_PLATFORM)/Developer/SDKs/$(SIM_SDK).sdk
SIM_CC?=		$(shell xcrun -sdk `echo ${SIM_SDK} | tr '[A-Z]' '[a-z]'` -f clang)
SIM_CFLAGS?=		-arch i386 -isysroot "$(SIM_ROOT)" -mmacosx-version-min=10.6 -gdwarf-2 $(CFLAGS)

MAC_SDK?=		MacOSX10.8
MAC_PLATFORM?=		$(PLATFORMS)/MacOSX.platform
MAC_ROOT?=		$(MAC_PLATFORM)/Developer/SDKs/$(MAC_SDK).sdk
MAC_CC?=		$(shell xcrun -sdk `echo ${MAC_SDK} | tr '[A-Z]' '[a-z]'` -f clang)
MAC_CFLAGS?=		-arch x86_64 -arch i386 -isysroot "$(MAC_ROOT)" -mmacosx-version-min=10.6 -gdwarf-2 $(CFLAGS)

IOS_OBJS=		test-ios.o
SIM_OBJS=		test-sim.o
MAC_OBJS=		test-macosx.o

PRODUCTS=		$(IOS_PRODUCT) $(MAC_PRODUCT) $(SIM_PRODUCT)
IOS_PRODUCT=		test.ios
SIM_PRODUCT=		test.sim
MAC_PRODUCT=		test.macosx

all: $(PRODUCTS)

test-sim.o: test.c
	$(SIM_CC) $(SIM_CFLAGS) -c $< -o $@

test-ios.o: test.c
	$(DEVICE_CC) $(DEVICE_CFLAGS) -c $< -o $@

test-macosx.o: test.c
	$(MAC_CC) $(MAC_CFLAGS) -c $< -o $@

$(MAC_PRODUCT): $(MAC_OBJS)
	$(MAC_CC) $(LDFLAGS) $(MAC_CFLAGS) $+ -o $@

$(IOS_PRODUCT): $(IOS_OBJS)
	$(DEVICE_CC) $(LDFLAGS) $(DEVICE_CFLAGS) $+ -o $@

$(SIM_PRODUCT): $(SIM_OBJS)
	$(SIM_CC) $(LDFLAGS) $(SIM_CFLAGS) $+ -o $@

clean-objs:
	rm -f $(IOS_OBJS) $(MAC_OBJS) $(SIM_OBJS)

clean: clean-objs
	rm -f $(PRODUCTS)
