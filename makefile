app_name := game_1

default: run_debug

run:
	@odin run src

run_debug:
	@odin run src -debug -vet

build:
	@-mkdir bin
	@odin build src -build-mode:exe -out:bin/$(app_name)

build_debug:
	@-mkdir bin
	@odin build src -build-mode:exe -debug -out:bin/$(app_name)

shaders: build_compile_shaders
	@./bin/compile_shaders

build_compile_shaders:
	@-rm -rf shaders/bin
	@odin build shaders/compile_shaders -build-mode:exe -out:bin/compile_shaders

sdl:
	@cmake -S ./vendor/sdl3/src -B ./vendor/sdl3/src/build -DSDL_SHARED=OFF -DSDL_STATIC=ON -DCMAKE_BUILD_TYPE=Release
	@cmake --build ./vendor/sdl3/src/build --config Release
	@-mkdir ./vendor/sdl3/lib
	@-cp ./vendor/sdl3/src/build/libSDL3.a ./vendor/sdl3/lib

sdl_image:
	@cmake -S ./vendor/sdl3/image/src -B ./vendor/sdl3/image/src/build -DSDL3_ROOT=./vendor/sdl3/src/build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
	@cmake --build ./vendor/sdl3/image/src/build --config Release
	@-mkdir ./vendor/sdl3/image/lib
	@-cp ./vendor/sdl3/image/src/build/libSDL3_image.a ./vendor/sdl3/image/lib

sdl_ttf:
	@cmake -S ./vendor/sdl3/ttf/src -B ./vendor/sdl3/ttf/src/build -DSDL3_ROOT=./vendor/sdl3/src/build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
	@cmake --build ./vendor/sdl3/ttf/src/build --config Release
	@-mkdir ./vendor/sdl3/ttf/lib
	@-cp ./vendor/sdl3/ttf/src/build/libSDL3_ttf.a ./vendor/sdl3/ttf/lib


