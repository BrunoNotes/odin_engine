package vulkan_context

import "core:mem"
import vk "vendor:vulkan"

VkBuffer :: struct {
	handle:         vk.Buffer,
	memory:         vk.DeviceMemory,
	info:           vk.BufferCreateInfo,
	device_address: vk.DeviceAddress,
	loaded:         bool,
}

initVkBuffer :: proc(
	buf: ^VkBuffer,
	size: vk.DeviceSize,
	usage: vk.BufferUsageFlags,
	properties: vk.MemoryPropertyFlags,
	get_device_address := false,
) {
	buf.info = vk.BufferCreateInfo {
		sType       = .BUFFER_CREATE_INFO,
		size        = size,
		usage       = usage,
		sharingMode = .EXCLUSIVE,
	}

	vk.CreateBuffer(
		g_vulkan_context.logic_device.handle,
		&buf.info,
		g_vulkan_context.vk_allocator,
		&buf.handle,
	)

	mem_req: vk.MemoryRequirements

	vk.GetBufferMemoryRequirements(g_vulkan_context.logic_device.handle, buf.handle, &mem_req)

	alloc_info := vk.MemoryAllocateInfo {
		sType           = .MEMORY_ALLOCATE_INFO,
		allocationSize  = mem_req.size,
		memoryTypeIndex = vkFindMemoryType(mem_req.memoryTypeBits, properties),
	}

	vkCheck(
		vk.AllocateMemory(
			g_vulkan_context.logic_device.handle,
			&alloc_info,
			g_vulkan_context.vk_allocator,
			&buf.memory,
		),
	)

	vkCheck(vk.BindBufferMemory(g_vulkan_context.logic_device.handle, buf.handle, buf.memory, 0))

	if get_device_address {
		device_address_info := vk.BufferDeviceAddressInfo {
			sType  = .BUFFER_DEVICE_ADDRESS_INFO,
			buffer = buf.handle,
		}

		buf.device_address = vk.GetBufferDeviceAddress(
			g_vulkan_context.logic_device.handle,
			&device_address_info,
		)
	}
}

destroyVkBuffer :: proc(buf: ^VkBuffer) {
	vk.FreeMemory(g_vulkan_context.logic_device.handle, buf.memory, g_vulkan_context.vk_allocator)
	vk.DestroyBuffer(
		g_vulkan_context.logic_device.handle,
		buf.handle,
		g_vulkan_context.vk_allocator,
	)
}

vkMapBufferMemory :: proc(buf: ^VkBuffer, items: rawptr, size: vk.DeviceSize) {
	data: rawptr
	vkCheck(vk.MapMemory(g_vulkan_context.logic_device.handle, buf.memory, 0, size, {}, &data))

	mem.copy(data, items, int(size))

	vk.UnmapMemory(g_vulkan_context.logic_device.handle, buf.memory)
}

vkInitStagingBuffer :: proc(size: vk.DeviceSize) -> VkBuffer {
	buf: VkBuffer

	initVkBuffer(&buf, size, {.TRANSFER_SRC}, {.HOST_VISIBLE, .HOST_COHERENT})

	return buf
}

copyVkBuffer :: proc(
	src_buf, dst_buf: vk.Buffer,
	src_offset, dst_offset: u64,
	size: vk.DeviceSize,
) {
	cmd := vkInitSingleTimeCmd()
	defer vkDestroySingleTimeCmd(&cmd)

	copy_region := vk.BufferCopy {
		srcOffset = vk.DeviceSize(src_offset),
		dstOffset = vk.DeviceSize(dst_offset),
		size      = size,
	}

	vk.CmdCopyBuffer(cmd, src_buf, dst_buf, 1, &copy_region)
}

allocateVkBuffer :: proc(
	size: vk.DeviceSize,
	items: rawptr,
	usage: vk.BufferUsageFlags,
	properties: vk.MemoryPropertyFlags = {.DEVICE_LOCAL},
	get_device_address := false,
) -> VkBuffer {
	buffer: VkBuffer
	initVkBuffer(&buffer, size, usage, properties, get_device_address)

	staging_buffer := vkInitStagingBuffer(size)
	defer destroyVkBuffer(&staging_buffer)

	vkMapBufferMemory(&staging_buffer, items, size)

	copyVkBuffer(staging_buffer.handle, buffer.handle, 0, 0, size)

	buffer.loaded = true

	return buffer
}
