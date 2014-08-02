RUSTC ?= rustc
RUSTFLAGS ?=
OUTDIR ?= ./build
CARGODIR ?= ./target

BINDIR = $(OUTDIR)/bin
LIBDIR = $(OUTDIR)/lib
BUILD_TMPDIR = $(OUTDIR)/tmp

SDL_LIBDIR = $(shell sdl2-config --prefix)/lib

RUST_SRC = $(shell find src/. -type f -name '*.rs') \
	src/sdl2/generated/keycode.rs                   \
	src/sdl2/generated/scancode.rs

.PHONY: all gen-lib
all: $(BUILD_TMPDIR)/libsdl2.dummy

sdl_native_libs:
	cp -r $(SDL_LIBDIR)/* $$OUT_DIR

UNAME=$(shell uname)

ifeq ($(UNAME),Darwin)
  # If the user wasn't explicit, see if SDL2 library exists
  ifeq ("$(strip $(SDL_MODE))","")
    SDL_CHECK=$(shell pkg-config --exists sdl2 && echo $$?)
    ifeq ($(SDL_CHECK),0)
      SDL_MODE = dylib
    else
      SDL_MODE = framework
    endif
  endif

  # $(info UNAME,$(UNAME),SDL_MODE,$(SDL_MODE))

  ifeq ($(SDL_MODE),framework)
    RUSTFLAGS+=--cfg mac_framework
  else
    RUSTFLAGS+=--cfg mac_dylib
  endif
endif

$(BINDIR) $(LIBDIR) $(BUILD_TMPDIR):
	mkdir -p '$@'

$(BUILD_TMPDIR)/codegen: $(wildcard src/codegen/*.rs) $(BUILD_TMPDIR)
	$(RUSTC) -o '$(BUILD_TMPDIR)/codegen' src/codegen/main.rs $(RUSTFLAGS)

src/sdl2/generated/%.rs: $(BUILD_TMPDIR)/codegen
	'$(BUILD_TMPDIR)/codegen' $(patsubst src/sdl2/generated/%,%,$@) src/sdl2/generated/

gen-lib: src/sdl2/lib.rs $(RUST_SRC) | $(LIBDIR) $(BUILD_TMPDIR)
	$(RUSTC) --out-dir '$(LIBDIR)' src/sdl2/lib.rs $(RUSTFLAGS)

$(BUILD_TMPDIR)/libsdl2.dummy: src/sdl2/lib.rs $(RUST_SRC) | $(LIBDIR) $(BUILD_TMPDIR)
	$(RUSTC) --out-dir '$(LIBDIR)' src/sdl2/lib.rs $(RUSTFLAGS)
	touch $@

compile_demo: src/demo/main.rs src/demo/video.rs $(BUILD_TMPDIR)/libsdl2.dummy | $(BINDIR)
	$(RUSTC) -o '$(BINDIR)/demo' -L '$(SDL_LIBDIR)' -L '$(LIBDIR)' src/demo/main.rs

demo: compile_demo
	'$(BINDIR)/demo'

.PHONY: cargo
cargo:
	cargo build

.PHONY: clean
clean:
	rm -rf src/sdl2/generated
	rm -rf '$(OUTDIR)'
	rm -rf '$(CARGODIR)'
