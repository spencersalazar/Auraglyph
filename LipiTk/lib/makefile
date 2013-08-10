
LIBS=libactivedtw.a libboxfld.a libcommon.a libfeatureextractorcommon.a \
    libl7.a liblipiengine.a liblogger.a libneuralnet.a libnn.a libnpen.a \
    libpointfloat.a libpreproc.a libshaperecommon.a libsubstroke.a \
    libutil.a libwordreccommon.a

all: $(LIBS)

$(LIBS): %.a: armv7/%.a i386/%.a
	lipo -create -arch i386 i386/$@ -arch armv7 armv7/$@ -output $@

