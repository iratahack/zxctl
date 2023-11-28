cmake_minimum_required(VERSION 3.13.4)
project(zxctl)

#set(CMAKE_C_FLAGS "-Wall -O0 -fsanitize=address -fno-omit-frame-pointer -g")
set(CMAKE_C_FLAGS "-Wall -O3")

add_executable(zxctl
	bin2rem.cpp
	compress.c
	memory.c
	optimize.c
	wave.c
	zxctl.c
	)

add_custom_target(LOADER DEPENDS loader.h ld_bytes.h turbo1.h)

add_custom_command(OUTPUT ${PROJECT_SOURCE_DIR}/loader.h
					COMMAND z88dk-z80asm -mz80 -m -b -oloader.bin ${PROJECT_SOURCE_DIR}/loader.asm
					COMMAND xxd -i loader.bin > ${PROJECT_SOURCE_DIR}/loader.h
					DEPENDS ${PROJECT_SOURCE_DIR}/loader.asm
					BYPRODUCTS loader.bin loader.map
					)
add_custom_command(OUTPUT ${PROJECT_SOURCE_DIR}/ld_bytes.h
					COMMAND z88dk-z80asm -mz80 -m -b -old_bytes.bin ${PROJECT_SOURCE_DIR}/ld_bytes.asm
					COMMAND xxd -i ld_bytes.bin > ${PROJECT_SOURCE_DIR}/ld_bytes.h
					DEPENDS ${PROJECT_SOURCE_DIR}/ld_bytes.asm
					BYPRODUCTS ld_bytes.bin ld_bytes.map
					)
add_custom_command(OUTPUT ${PROJECT_SOURCE_DIR}/turbo1.h
					COMMAND z88dk-z80asm -mz80 -m -b -oturbo1.bin ${PROJECT_SOURCE_DIR}/turbo1.asm
					COMMAND xxd -i turbo1.bin > ${PROJECT_SOURCE_DIR}/turbo1.h
					DEPENDS ${PROJECT_SOURCE_DIR}/turbo1.asm
					BYPRODUCTS turbo1.bin turbo1.map
					)

add_dependencies(${PROJECT_NAME} LOADER)
