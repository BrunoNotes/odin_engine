package vulkan_context

import "../utils"
import "core:encoding/uuid"
import "core:log"
import "core:math"
import "core:math/linalg"
import vk "vendor:vulkan"

BLANK_TEXTURE_KEY := "_blank"
BLANK_PIXELS := [4]u8{255, 255, 255, 255}

VkTexture :: struct {
	current_image:  string,
	uniform:        VkTextureUniform,
	texture_images: map[string]VkTextureImage,
	descriptor:     VkDescriptor,
	buffer:         VkBuffer,
}

VkTextureUniform :: struct {
	diffuse_color: linalg.Vector4f32,
}

VkTextureImage :: struct {
	id:                      uuid.Identifier,
	image:                   VkImage,
	sampler:                 vk.Sampler,
	descriptor_binding:      u32,
	width, height, channels: i32,
}

VkTextureImageType :: enum {
	blank,
	image,
}

initVkTexture :: proc(texture: ^VkTexture, allocator := context.allocator) {
	log.info("Vulkan: init texture")

	if texture.uniform.diffuse_color == 0 {
		texture.uniform.diffuse_color = 1
	}

	if len(texture.texture_images) <= 0 {
		texture.texture_images = make(map[string]VkTextureImage, 1, allocator)

		tex_img: VkTextureImage
		initVkTextureImage(&tex_img, type = .blank)

		texture.texture_images[BLANK_TEXTURE_KEY] = tex_img
	}

	texture_descriptor_pool_size := []vk.DescriptorPoolSize {
		{
			type = .UNIFORM_BUFFER,
			descriptorCount = len(texture.texture_images) <= 0 ? 1 : u32(len(texture.texture_images)),
		},
		{
			type = .COMBINED_IMAGE_SAMPLER,
			descriptorCount = len(texture.texture_images) <= 0 ? 1 : u32(len(texture.texture_images)),
		},
	}

	texture_descriptor_layout_binding: [dynamic]vk.DescriptorSetLayoutBinding
	defer delete(texture_descriptor_layout_binding)

	append(
		&texture_descriptor_layout_binding,
		vk.DescriptorSetLayoutBinding {
			binding = 0,
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
			stageFlags = {.FRAGMENT},
		},
	)

	// for i in 0 ..< len(texture.texture_images) {
	binding_idx := 0
	for _, &value in texture.texture_images {
		layout_binding := vk.DescriptorSetLayoutBinding {
			binding         = u32(binding_idx + 1),
			descriptorType  = .COMBINED_IMAGE_SAMPLER,
			descriptorCount = 1,
			stageFlags      = {.FRAGMENT},
		}

		append(&texture_descriptor_layout_binding, layout_binding)
		value.descriptor_binding = layout_binding.binding
		// texture.texture_images[key].descriptor_binding = layout_binding.binding
		binding_idx += 1
	}

	initVkDescriptor(
		&texture.descriptor,
		u32(len(g_vulkan_context.swapchain.images)),
		texture_descriptor_pool_size[:],
		texture_descriptor_layout_binding[:],
	)

	initVkBuffer(
		&texture.buffer,
		vk.DeviceSize(size_of(texture.uniform)),
		{.TRANSFER_DST, .UNIFORM_BUFFER},
		{.DEVICE_LOCAL},
	)
}

destroyVkTexture :: proc(texture: ^VkTexture) {
	log.info("Vulkan: destroy texture")
	for _, &texture in texture.texture_images {
		destroyVkTextureImage(&texture)
	}
	destroyVkBuffer(&texture.buffer)
	destroyVkDescriptor(&texture.descriptor)
}

createVkTextureImageFromImage :: proc {
	createVkTextureImageFromImageByte,
	createVkTextureImageFromImageFile,
	createVkTextureImageFromStbImage,
}

createVkTextureImageFromImageByte :: proc(
	image_byte: []byte,
	allocator := context.allocator,
) -> VkTextureImage {
	img := utils.loadStbImage(image_byte)

	tex_img: VkTextureImage
	initVkTextureImage(&tex_img, u32(img.width), u32(img.height), u32(img.channels), img.data)

	utils.freeStbImage(img)

	return tex_img
}

createVkTextureImageFromImageFile :: proc(
	image_path: string,
	allocator := context.allocator,
) -> VkTextureImage {
	img := utils.loadStbImage(image_path)

	tex_img: VkTextureImage
	initVkTextureImage(&tex_img, u32(img.width), u32(img.height), u32(img.channels), img.data)

	utils.freeStbImage(img)

	return tex_img
}

createVkTextureImageFromStbImage :: proc(
	img: utils.StbImage,
	allocator := context.allocator,
) -> VkTextureImage {
	tex_img: VkTextureImage
	initVkTextureImage(&tex_img, u32(img.width), u32(img.height), u32(img.channels), img.data)

	utils.freeStbImage(img)

	return tex_img
}

initVkTextureImage :: proc(
	tex_image: ^VkTextureImage,
	img_width: u32 = 0,
	img_height: u32 = 0,
	img_channels: u32 = 0,
	img_data: [^]byte = nil,
	type: VkTextureImageType = VkTextureImageType.image,
) {
	tex_image.id = uuid.generate_v7()

	switch type {
	case .image:
		assert(img_width > 0, "Vulkan: image width must be grater than 0")
		assert(img_height > 0, "Vulkan: image height must be grater than 0")
		assert(img_data != nil, "Vulkan: image data must not be nil")

		createVkTextureImage(
			tex_image,
			u32(img_width),
			u32(img_height),
			u32(img_channels),
			img_data,
		)
	case .blank:
		createVkTextureImage(tex_image, 1, 1, 4, raw_data(&BLANK_PIXELS))
	}
}

destroyVkTextureImage :: proc(tex_image: ^VkTextureImage) {
	log.infof("vulkan: destroy texture image")
	// vk.DeviceWaitIdle(ctx.logic_device.handle)
	vk.DestroySampler(
		g_vulkan_context.logic_device.handle,
		tex_image.sampler,
		g_vulkan_context.vk_allocator,
	)
	vk.DestroyImageView(
		g_vulkan_context.logic_device.handle,
		tex_image.image.view,
		g_vulkan_context.vk_allocator,
	)
	vk.DestroyImage(
		g_vulkan_context.logic_device.handle,
		tex_image.image.handle,
		g_vulkan_context.vk_allocator,
	)
	vk.FreeMemory(
		g_vulkan_context.logic_device.handle,
		tex_image.image.memory,
		g_vulkan_context.vk_allocator,
	)
}

createVkTextureImage :: proc(
	tex_image: ^VkTextureImage,
	img_width, img_height, img_channels: u32,
	img_data: [^]byte,
) {
	tex_image.image.extent = vk.Extent2D {
		width  = img_width,
		height = img_height,
	}

	mip_levels := u32(math.floor(math.log2(f32(max(img_width, img_height))))) + 1

	createVkImage(
		&tex_image.image,
		img_width,
		img_height,
		mip_levels,
		.R8G8B8A8_UNORM,
		.OPTIMAL,
		{.SAMPLED, .TRANSFER_SRC, .TRANSFER_DST},
		{.DEVICE_LOCAL},
	)

	channels := img_channels < 4 ? 4 : img_channels
	img_size := img_width * img_height * channels

	// size := size_of(img_data)
	staging_buffer := vkInitStagingBuffer(vk.DeviceSize(img_size))
	defer destroyVkBuffer(&staging_buffer)

	vkMapBufferMemory(&staging_buffer, img_data, vk.DeviceSize(img_size))

	cmd := vkInitSingleTimeCmd()
	defer vkDestroySingleTimeCmd(&cmd)

	vkTransitionImage(cmd, tex_image.image.handle, .UNDEFINED, .TRANSFER_DST_OPTIMAL, mip_levels)

	copy_region := []vk.BufferImageCopy {
		{
			bufferOffset = 0,
			bufferRowLength = 0,
			bufferImageHeight = 0,
			imageSubresource = vk.ImageSubresourceLayers {
				aspectMask = {.COLOR},
				mipLevel = 0,
				baseArrayLayer = 0,
				layerCount = 1,
			},
			imageOffset = {x = 0, y = 0, z = 0},
			imageExtent = {width = img_width, height = img_height, depth = 1},
		},
	}

	vk.CmdCopyBufferToImage(
		cmd,
		staging_buffer.handle,
		tex_image.image.handle,
		.TRANSFER_DST_OPTIMAL,
		u32(len(copy_region)),
		raw_data(copy_region),
	)

	// transitionImage(
	//     cmd,
	//     tex_image.image.handle,
	//     .TRANSFER_DST_OPTIMAL,
	//     .SHADER_READ_ONLY_OPTIMAL,
	// )

	{
		format_properties: vk.FormatProperties
		vk.GetPhysicalDeviceFormatProperties(
			g_vulkan_context.physical_device.handle,
			.R8G8B8A8_SRGB,
			&format_properties,
		)

		if (format_properties.optimalTilingFeatures & {.SAMPLED_IMAGE_FILTER_LINEAR}) !=
		   {.SAMPLED_IMAGE_FILTER_LINEAR} {
			log.errorf("texture image format does not support linear blitting")
		}

		barrier := vk.ImageMemoryBarrier2 {
			sType = .IMAGE_MEMORY_BARRIER_2,
			image = tex_image.image.handle,
			srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
			dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
			subresourceRange = {
				aspectMask = {.COLOR},
				baseArrayLayer = 0,
				layerCount = 1,
				levelCount = 1,
			},
		}

		dep_info := vk.DependencyInfo {
			sType                   = vk.StructureType.DEPENDENCY_INFO,
			imageMemoryBarrierCount = 1,
			pImageMemoryBarriers    = &barrier,
		}

		mip_width := i32(img_width)
		mip_height := i32(img_height)

		src_stage_access: VkPipelineStageAccess
		dst_stage_access: VkPipelineStageAccess

		for i in 1 ..< mip_levels {
			barrier.subresourceRange.baseMipLevel = i - 1
			barrier.oldLayout = .TRANSFER_DST_OPTIMAL
			barrier.newLayout = .TRANSFER_SRC_OPTIMAL

			src_stage_access = vkGetPipelineStageAccess(barrier.oldLayout)
			barrier.srcAccessMask = src_stage_access.access
			barrier.srcStageMask = src_stage_access.stage
			dst_stage_access = vkGetPipelineStageAccess(barrier.newLayout)
			barrier.dstAccessMask = dst_stage_access.access
			barrier.dstStageMask = dst_stage_access.stage

			vk.CmdPipelineBarrier2(cmd, &dep_info)

			blit := vk.ImageBlit2 {
				sType = .IMAGE_BLIT_2,
				srcSubresource = {
					aspectMask = {.COLOR},
					mipLevel = i - 1,
					baseArrayLayer = 0,
					layerCount = 1,
				},
				dstSubresource = {
					aspectMask = {.COLOR},
					mipLevel = i,
					baseArrayLayer = 0,
					layerCount = 1,
				},
			}
			blit.srcOffsets[0] = {0, 0, 0}
			blit.srcOffsets[1] = {mip_width, mip_height, 1}
			blit.dstOffsets[0] = {0, 0, 0}
			blit.dstOffsets[1] = {
				mip_width > 1 ? mip_width / 2 : 1,
				mip_height > 1 ? mip_height / 2 : 1,
				1,
			}

			blit_info := vk.BlitImageInfo2 {
				sType          = .BLIT_IMAGE_INFO_2,
				srcImage       = tex_image.image.handle,
				srcImageLayout = .TRANSFER_SRC_OPTIMAL,
				dstImage       = tex_image.image.handle,
				dstImageLayout = .TRANSFER_DST_OPTIMAL,
				regionCount    = 1,
				pRegions       = &blit,
				filter         = .LINEAR,
			}

			vk.CmdBlitImage2(cmd, &blit_info)

			barrier.oldLayout = .TRANSFER_SRC_OPTIMAL
			barrier.newLayout = .SHADER_READ_ONLY_OPTIMAL

			src_stage_access = vkGetPipelineStageAccess(barrier.oldLayout)
			barrier.srcAccessMask = src_stage_access.access
			barrier.srcStageMask = src_stage_access.stage
			dst_stage_access = vkGetPipelineStageAccess(barrier.newLayout)
			barrier.dstAccessMask = dst_stage_access.access
			barrier.dstStageMask = dst_stage_access.stage

			vk.CmdPipelineBarrier2(cmd, &dep_info)

			if mip_width > 1 {
				mip_width /= 2
			}

			if mip_height > 1 {
				mip_height /= 2
			}
		}

		barrier.subresourceRange.baseMipLevel = mip_levels - 1
		barrier.oldLayout = .TRANSFER_DST_OPTIMAL
		barrier.newLayout = .SHADER_READ_ONLY_OPTIMAL

		src_stage_access = vkGetPipelineStageAccess(barrier.oldLayout)
		barrier.srcAccessMask = src_stage_access.access
		barrier.srcStageMask = src_stage_access.stage
		dst_stage_access = vkGetPipelineStageAccess(barrier.newLayout)
		barrier.dstAccessMask = dst_stage_access.access
		barrier.dstStageMask = dst_stage_access.stage

		vk.CmdPipelineBarrier2(cmd, &dep_info)
	}

	tex_image.image.view = createVkImageView(
		tex_image.image.handle,
		.R8G8B8A8_UNORM,
		{.COLOR},
		mip_levels,
	)

	sampler_info := vk.SamplerCreateInfo {
		sType                   = .SAMPLER_CREATE_INFO,
		magFilter               = .LINEAR,
		minFilter               = .LINEAR,
		addressModeU            = .REPEAT,
		addressModeV            = .REPEAT,
		addressModeW            = .REPEAT,
		anisotropyEnable        = true,
		maxAnisotropy           = 16,
		borderColor             = .FLOAT_OPAQUE_BLACK,
		unnormalizedCoordinates = false,
		compareEnable           = true,
		mipmapMode              = .LINEAR,
		mipLodBias              = 0,
		minLod                  = 0,
		maxLod                  = vk.LOD_CLAMP_NONE,
		// maxLod                  = 0,
	}

	vkCheck(
		vk.CreateSampler(
			g_vulkan_context.logic_device.handle,
			&sampler_info,
			g_vulkan_context.vk_allocator,
			&tex_image.sampler,
		),
	)
}
