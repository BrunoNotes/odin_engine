package utils_context

import stbi "../../../vendor/stb/image"
import "core:c"
import "core:log"
import "core:strings"

DEFAULT_TEXTURE := #load("../../../assets/textures/default.png")

StbImage :: struct {
	width, height, channels: i32,
	data:                    [^]byte,
}

loadStbImage :: proc {
	loadStbImageByte,
	loadStbImageFile,
}

loadStbImageByte :: proc(img_byte: []byte, allocator := context.allocator) -> StbImage {
	img := StbImage{}

	stbi.set_flip_vertically_on_load(1)

	img.data = stbi.load_from_memory(
		raw_data(img_byte),
		i32(len(img_byte)),
		&img.width,
		&img.height,
		&img.channels,
		cast(c.int)stbi.Channels.rgb_alpha,
	)
	// defer stbi.image_free(img.data)

	if img.data == nil {
		log.errorf("Error loading texture byte: %v", stbi.failure_reason())

		img.data = stbi.load_from_memory(
			raw_data(DEFAULT_TEXTURE),
			i32(len(DEFAULT_TEXTURE)),
			&img.width,
			&img.height,
			&img.channels,
			cast(c.int)stbi.Channels.rgb_alpha,
		)
	}

	return img
}

loadStbImageFile :: proc(file_path: string, allocator := context.allocator) -> StbImage {
	img := StbImage{}

	stbi.set_flip_vertically_on_load(1)

	img.data = stbi.load(
		strings.clone_to_cstring(file_path, context.temp_allocator),
		&img.width,
		&img.height,
		&img.channels,
		cast(c.int)stbi.Channels.rgb_alpha,
	)
	// defer stbi.image_free(img.data)

	if img.data == nil {
		log.errorf("Error loading texture %v: %v", file_path, stbi.failure_reason())

		img.data = stbi.load_from_memory(
			raw_data(DEFAULT_TEXTURE),
			i32(len(DEFAULT_TEXTURE)),
			&img.width,
			&img.height,
			&img.channels,
			cast(c.int)stbi.Channels.rgb_alpha,
		)
	}

	return img
}

freeImage :: proc(img: StbImage) {
	stbi.image_free(img.data)
}
