COMPILER?=~/dev/install/linux/bin64/dmd
# COMPILER?=dmd
PREVIEWS=-preview=rvaluerefparam -preview=bitfields




ifeq ($(OS), Windows_NT)
	exe = .exe
	dll = .dll
	FLAGS_DEBUG   += -L/OPT:REF
	FLAGS_RELEASE += -L/OPT:REF
else
	exe =
	dll = .so
	LD_LIBRARY_PATH=.
	FLAGS_RELEASE += -O3
endif

MODE ?= DEBUG
ifeq ($(MODE), DEBUG)
    OPTIMIZE=$(FLAGS_DEBUG)
else ifeq ($(MODE), RELEASE)
    OPTIMIZE=$(FLAGS_RELEASE)
endif


CHECK ?= 0

ifeq ($(CHECK), 1)
	OPTIMIZE += -c -o-
endif


build-dcd-dls: build-dcd build-dls

build-dls:
	@$(COMPILER) -of=bin/dls$(exe) $(OPTIMIZE) $(PREVIEWS) -i -Iserver/ \
    server/cjson/cJSON.c server/dls/main.d server/dls/libdcd.a

run-dls: build-dls
	cd bin && ./dls

build-dcd:
	cd dcd_templates/ && dub build -c library
	mv dcd_templates/libdcd.a server/dls/

build-dls-release:
	ldmd2 -of=bin/dls$(exe) $(FLAGS_RELEASE) $(PREVIEWS) -i -Iserver/ \
    server/cjson/cJSON.c server/dls/main.d server/dls/libdcd.a

build-dcd-release:
	cd dcd_templates/ && dub build -c library --compiler=ldc2 -b release
	mv dcd_templates/libdcd.a server/dls/

build-vscode:
	cd editors/vscode && npm install
	cd editors/vscode && npm run compile
	cd editors/vscode && vsce package
	mv editors/vscode/*.vsix bin/
# 	vsce publish
