#include <vulkan/vulkan.h>

#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <string.h>
#ifndef __FreeBSD__
#include <alloca.h>
#endif
#include <errno.h>
#include <stdio.h>
#include <assert.h>
#include <math.h>
#include <time.h>

#include <spa/utils/result.h>
#include <spa/support/log.h>
#include <spa/debug/mem.h>

#include "vulkan-utils.h"

#define VULKAN_INSTANCE_FUNCTION(name)						\
	PFN_##name name = (PFN_##name)vkGetInstanceProcAddr(s->instance, #name)

static int vkresult_to_errno(VkResult result)
{
	switch (result) {
	case VK_SUCCESS:
	case VK_EVENT_SET:
	case VK_EVENT_RESET:
		return 0;
	case VK_NOT_READY:
	case VK_INCOMPLETE:
	case VK_ERROR_NATIVE_WINDOW_IN_USE_KHR:
		return EBUSY;
	case VK_TIMEOUT:
		return ETIMEDOUT;
	case VK_ERROR_OUT_OF_HOST_MEMORY:
	case VK_ERROR_OUT_OF_DEVICE_MEMORY:
	case VK_ERROR_MEMORY_MAP_FAILED:
	case VK_ERROR_OUT_OF_POOL_MEMORY:
	case VK_ERROR_FRAGMENTED_POOL:
#ifdef VK_ERROR_FRAGMENTATION_EXT
	case VK_ERROR_FRAGMENTATION_EXT:
#endif
		return ENOMEM;
	case VK_ERROR_INITIALIZATION_FAILED:
		return EIO;
	case VK_ERROR_DEVICE_LOST:
	case VK_ERROR_SURFACE_LOST_KHR:
#ifdef VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT
	case VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT:
#endif
		return ENODEV;
	case VK_ERROR_LAYER_NOT_PRESENT:
	case VK_ERROR_EXTENSION_NOT_PRESENT:
	case VK_ERROR_FEATURE_NOT_PRESENT:
		return ENOENT;
	case VK_ERROR_INCOMPATIBLE_DRIVER:
	case VK_ERROR_FORMAT_NOT_SUPPORTED:
	case VK_ERROR_INCOMPATIBLE_DISPLAY_KHR:
		return ENOTSUP;
	case VK_ERROR_TOO_MANY_OBJECTS:
		return ENFILE;
	case VK_SUBOPTIMAL_KHR:
	case VK_ERROR_OUT_OF_DATE_KHR:
		return EIO;
	case VK_ERROR_INVALID_EXTERNAL_HANDLE:
	case VK_ERROR_INVALID_SHADER_NV:
#ifdef VK_ERROR_VALIDATION_FAILED_EXT
	case VK_ERROR_VALIDATION_FAILED_EXT:
#endif
#ifdef VK_ERROR_INVALID_DRM_FORMAT_MODIFIER_PLANE_LAYOUT_EXT
	case VK_ERROR_INVALID_DRM_FORMAT_MODIFIER_PLANE_LAYOUT_EXT:
#endif
#ifdef VK_ERROR_INVALID_DEVICE_ADDRESS_EXT
	case VK_ERROR_INVALID_DEVICE_ADDRESS_EXT:
#endif
		return EINVAL;
#ifdef VK_ERROR_NOT_PERMITTED_EXT
	case VK_ERROR_NOT_PERMITTED_EXT:
		return EPERM;
#endif
	default:
		return EIO;
	}
}

#define VK_CHECK_RESULT(f)								\
{											\
	VkResult _result = (f);								\
	int _res = -vkresult_to_errno(_result);						\
	if (_result != VK_SUCCESS) {							\
		spa_log_debug(s->log, "error: %d (%s)", _result, spa_strerror(_res));	\
		return _res;								\
	}										\
}

static int createInstance(struct vulkan_state *s)
{
	const VkApplicationInfo applicationInfo = {
		.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
		.pApplicationName = "PipeWire",
		.applicationVersion = 0,
		.pEngineName = "PipeWire Vulkan Engine",
		.engineVersion = 0,
		.apiVersion = VK_API_VERSION_1_1
	};
	const char *extensions[] = {
		VK_KHR_EXTERNAL_MEMORY_CAPABILITIES_EXTENSION_NAME
	};
        VkInstanceCreateInfo createInfo = {
		.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
		.pApplicationInfo = &applicationInfo,
		.enabledExtensionCount = 1,
		.ppEnabledExtensionNames = extensions,
	};

	VK_CHECK_RESULT(vkCreateInstance(&createInfo, NULL, &s->instance));

	return 0;
}

static uint32_t getComputeQueueFamilyIndex(struct vulkan_state *s)
{
	uint32_t i, queueFamilyCount;
	VkQueueFamilyProperties *queueFamilies;

	vkGetPhysicalDeviceQueueFamilyProperties(s->physicalDevice, &queueFamilyCount, NULL);

	queueFamilies = alloca(queueFamilyCount * sizeof(VkQueueFamilyProperties));
	vkGetPhysicalDeviceQueueFamilyProperties(s->physicalDevice, &queueFamilyCount, queueFamilies);

	for (i = 0; i < queueFamilyCount; i++) {
		VkQueueFamilyProperties props = queueFamilies[i];

		if (props.queueCount > 0 && (props.queueFlags & VK_QUEUE_COMPUTE_BIT))
			break;
	}
	if (i == queueFamilyCount)
		return -ENODEV;

	return i;
}

static int findPhysicalDevice(struct vulkan_state *s)
{
	uint32_t deviceCount;
        VkPhysicalDevice *devices;

	vkEnumeratePhysicalDevices(s->instance, &deviceCount, NULL);
	if (deviceCount == 0)
		return -ENODEV;

	devices = alloca(deviceCount * sizeof(VkPhysicalDevice));
        vkEnumeratePhysicalDevices(s->instance, &deviceCount, devices);

	s->physicalDevice = devices[0];

	s->queueFamilyIndex = getComputeQueueFamilyIndex(s);

	return 0;
}

static int createDevice(struct vulkan_state *s)
{
	VkDeviceQueueCreateInfo queueCreateInfo = {
		.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
		.queueFamilyIndex = s->queueFamilyIndex,
		.queueCount = 1,
		.pQueuePriorities = (const float[]) { 1.0f }
	};
	const char *extensions[] = {
		VK_KHR_EXTERNAL_MEMORY_EXTENSION_NAME,
		VK_KHR_EXTERNAL_MEMORY_FD_EXTENSION_NAME
	};
	VkDeviceCreateInfo deviceCreateInfo = {
		.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
		.queueCreateInfoCount = 1,
		.pQueueCreateInfos = &queueCreateInfo,
		.enabledExtensionCount = 2,
		.ppEnabledExtensionNames = extensions,
	};

	VK_CHECK_RESULT(vkCreateDevice(s->physicalDevice, &deviceCreateInfo, NULL, &s->device));

	vkGetDeviceQueue(s->device, s->queueFamilyIndex, 0, &s->queue);

	VkFenceCreateInfo fenceCreateInfo = {
		.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
		.flags = 0,
	};
	VK_CHECK_RESULT(vkCreateFence(s->device, &fenceCreateInfo, NULL, &s->fence));

	return 0;
}

static uint32_t findMemoryType(struct vulkan_state *s,
		uint32_t memoryTypeBits, VkMemoryPropertyFlags properties)
{
	uint32_t i;
	VkPhysicalDeviceMemoryProperties memoryProperties;

	vkGetPhysicalDeviceMemoryProperties(s->physicalDevice, &memoryProperties);

	for (i = 0; i < memoryProperties.memoryTypeCount; i++) {
		if ((memoryTypeBits & (1 << i)) &&
		    ((memoryProperties.memoryTypes[i].propertyFlags & properties) == properties))
			return i;
	}
	return -1;
}

static int createDescriptors(struct vulkan_state *s)
{
	VkDescriptorPoolSize descriptorPoolSize = {
		.type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
		.descriptorCount = 1
	};
	VkDescriptorPoolCreateInfo descriptorPoolCreateInfo = {
		.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
		.maxSets = 1,
		.poolSizeCount = 1,
		.pPoolSizes = &descriptorPoolSize,
	};

        VK_CHECK_RESULT(vkCreateDescriptorPool(s->device,
				&descriptorPoolCreateInfo, NULL,
				&s->descriptorPool));

	VkDescriptorSetLayoutBinding descriptorSetLayoutBinding = {
		.binding = 0,
		.descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
		.descriptorCount = 1,
		.stageFlags = VK_SHADER_STAGE_COMPUTE_BIT
	};
	VkDescriptorSetLayoutCreateInfo descriptorSetLayoutCreateInfo = {
		.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		.bindingCount = 1,
		.pBindings = &descriptorSetLayoutBinding
	};
	VK_CHECK_RESULT(vkCreateDescriptorSetLayout(s->device,
				&descriptorSetLayoutCreateInfo, NULL,
				&s->descriptorSetLayout));

	VkDescriptorSetAllocateInfo descriptorSetAllocateInfo = {
		.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
		.descriptorPool = s->descriptorPool,
		.descriptorSetCount = 1,
		.pSetLayouts = &s->descriptorSetLayout
	};

	VK_CHECK_RESULT(vkAllocateDescriptorSets(s->device,
				&descriptorSetAllocateInfo,
				&s->descriptorSet));
	return 0;
}

static int createBuffer(struct vulkan_state *s, uint32_t id)
{
	VkBufferCreateInfo bufferCreateInfo = {
		.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
		.size = s->bufferSize,
		.usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
		.sharingMode = VK_SHARING_MODE_EXCLUSIVE,
	};
	VkMemoryRequirements memoryRequirements;

	VK_CHECK_RESULT(vkCreateBuffer(s->device,
				&bufferCreateInfo, NULL, &s->buffers[id].buffer));

	vkGetBufferMemoryRequirements(s->device,
			s->buffers[id].buffer, &memoryRequirements);

	VkMemoryAllocateInfo allocateInfo = {
		.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
		.allocationSize = memoryRequirements.size
	};
	allocateInfo.memoryTypeIndex = findMemoryType(s,
			memoryRequirements.memoryTypeBits,
			VK_MEMORY_PROPERTY_HOST_COHERENT_BIT |
			VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);

	VK_CHECK_RESULT(vkAllocateMemory(s->device,
				&allocateInfo, NULL, &s->buffers[id].memory));
	VK_CHECK_RESULT(vkBindBufferMemory(s->device,
				s->buffers[id].buffer, s->buffers[id].memory, 0));

	return 0;
}

static int updateDescriptors(struct vulkan_state *s, uint32_t buffer_id)
{
	if (s->current_buffer_id == buffer_id)
		return 0;

	VkDescriptorBufferInfo descriptorBufferInfo = {
		.buffer = s->buffers[buffer_id].buffer,
		.offset = 0,
		.range = s->bufferSize,
	};
	VkWriteDescriptorSet writeDescriptorSet = {
		.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
		.dstSet = s->descriptorSet,
		.dstBinding = 0,
		.descriptorCount = 1,
		.descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
		.pBufferInfo = &descriptorBufferInfo,
	};
	vkUpdateDescriptorSets(s->device, 1, &writeDescriptorSet, 0, NULL);
	s->current_buffer_id = buffer_id;

	return 0;
}

static VkShaderModule createShaderModule(struct vulkan_state *s, const char* shaderFile)
{
	VkShaderModule shaderModule = VK_NULL_HANDLE;
	VkResult result;
	void *data;
	int fd;
	struct stat stat;

	if ((fd = open(shaderFile, 0, O_RDONLY)) == -1) {
		spa_log_error(s->log, "can't open %s: %m", shaderFile);
		return VK_NULL_HANDLE;
	}
	if (fstat(fd, &stat) < 0) {
		spa_log_error(s->log, "can't stat %s: %m", shaderFile);
		close(fd);
		return VK_NULL_HANDLE;
	}

	data = mmap(NULL, stat.st_size, PROT_READ, MAP_PRIVATE, fd, 0);

	VkShaderModuleCreateInfo shaderModuleCreateInfo = {
		.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
		.codeSize = stat.st_size,
		.pCode = data,
	};
	result = vkCreateShaderModule(s->device,
			&shaderModuleCreateInfo, 0, &shaderModule);

	munmap(data, stat.st_size);
	close(fd);

	if (result != VK_SUCCESS) {
		spa_log_error(s->log, "can't create shader %s: %m", shaderFile);
		return VK_NULL_HANDLE;
	}
	return shaderModule;
}

static int createComputePipeline(struct vulkan_state *s, const char *shader_file)
{
	const VkPushConstantRange range = {
		.stageFlags = VK_PIPELINE_STAGE_VERTEX_SHADER_BIT,
		.offset = 0,
		.size = sizeof(struct push_constants)
	};

	VkPipelineLayoutCreateInfo pipelineLayoutCreateInfo = {
		.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
		.setLayoutCount = 1,
		.pSetLayouts = &s->descriptorSetLayout,
		.pushConstantRangeCount = 1,
		.pPushConstantRanges = &range,
	};
	VK_CHECK_RESULT(vkCreatePipelineLayout(s->device,
				&pipelineLayoutCreateInfo, NULL,
				&s->pipelineLayout));

        s->computeShaderModule = createShaderModule(s, shader_file);
	if (s->computeShaderModule == VK_NULL_HANDLE)
		return -ENOENT;

	VkPipelineShaderStageCreateInfo shaderStageCreateInfo = {
		.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
		.stage = VK_SHADER_STAGE_COMPUTE_BIT,
		.module = s->computeShaderModule,
		.pName = "main",
	};
	VkComputePipelineCreateInfo pipelineCreateInfo = {
		.sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
		.stage = shaderStageCreateInfo,
		.layout = s->pipelineLayout,
	};
	VK_CHECK_RESULT(vkCreateComputePipelines(s->device, VK_NULL_HANDLE,
				1, &pipelineCreateInfo, NULL,
				&s->pipeline));
	return 0;
}

static int createCommandBuffer(struct vulkan_state *s)
{
	VkCommandPoolCreateInfo commandPoolCreateInfo = {
		.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
		.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
		.queueFamilyIndex = s->queueFamilyIndex,
	};
        VK_CHECK_RESULT(vkCreateCommandPool(s->device,
				&commandPoolCreateInfo, NULL,
				&s->commandPool));

	VkCommandBufferAllocateInfo commandBufferAllocateInfo = {
		.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
		.commandPool = s->commandPool,
		.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		.commandBufferCount = 1,
	};
        VK_CHECK_RESULT(vkAllocateCommandBuffers(s->device,
				&commandBufferAllocateInfo,
				&s->commandBuffer));

	return 0;
}

static int runCommandBuffer(struct vulkan_state *s)
{
	VkCommandBufferBeginInfo beginInfo = {
		.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
		.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
	};
	VK_CHECK_RESULT(vkBeginCommandBuffer(s->commandBuffer, &beginInfo));

	vkCmdBindPipeline(s->commandBuffer, VK_PIPELINE_BIND_POINT_COMPUTE, s->pipeline);
	vkCmdPushConstants (s->commandBuffer,
			s->pipelineLayout, VK_SHADER_STAGE_COMPUTE_BIT,
			0, sizeof(struct push_constants), (const void *) &s->constants);
	vkCmdBindDescriptorSets(s->commandBuffer, VK_PIPELINE_BIND_POINT_COMPUTE,
			s->pipelineLayout, 0, 1, &s->descriptorSet, 0, NULL);

	vkCmdDispatch(s->commandBuffer,
			(uint32_t)ceil(s->constants.width / (float)WORKGROUP_SIZE),
			(uint32_t)ceil(s->constants.height / (float)WORKGROUP_SIZE), 1);

	VK_CHECK_RESULT(vkEndCommandBuffer(s->commandBuffer));

	VK_CHECK_RESULT(vkResetFences(s->device, 1, &s->fence));

	VkSubmitInfo submitInfo = {
		.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
		.commandBufferCount = 1,
		.pCommandBuffers = &s->commandBuffer,
	};
        VK_CHECK_RESULT(vkQueueSubmit(s->queue, 1, &submitInfo, s->fence));
	s->busy_buffer_id = s->current_buffer_id;

	return 0;
}

static void clear_buffers(struct vulkan_state *s)
{
	uint32_t i;

	for (i = 0; i < s->n_buffers; i++) {
		close(s->buffers[i].buf->datas[0].fd);
		vkFreeMemory(s->device, s->buffers[i].memory, NULL);
		vkDestroyBuffer(s->device, s->buffers[i].buffer, NULL);
	}
	s->n_buffers = 0;
}

int spa_vulkan_use_buffers(struct vulkan_state *s, uint32_t flags,
		uint32_t n_buffers, struct spa_buffer **buffers)
{
	uint32_t i;
	VULKAN_INSTANCE_FUNCTION(vkGetMemoryFdKHR);

	clear_buffers(s);

	s->bufferSize = s->constants.width * s->constants.height * sizeof(struct pixel);

	for (i = 0; i < n_buffers; i++) {
		createBuffer(s, i);

		VkMemoryGetFdInfoKHR getFdInfo = {
			.sType = VK_STRUCTURE_TYPE_MEMORY_GET_FD_INFO_KHR,
			.memory = s->buffers[i].memory,
			.handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT
		};
		int fd;

		s->buffers[i].buf = buffers[i];

	        VK_CHECK_RESULT(vkGetMemoryFdKHR(s->device, &getFdInfo, &fd));

		buffers[i]->datas[0].type = SPA_DATA_DmaBuf;
		buffers[i]->datas[0].flags = SPA_DATA_FLAG_READABLE;
		buffers[i]->datas[0].fd = fd;
		buffers[i]->datas[0].mapoffset = 0;
		buffers[i]->datas[0].maxsize = s->bufferSize;
	}
	s->n_buffers = n_buffers;

	return 0;
}

int spa_vulkan_prepare(struct vulkan_state *s)
{
	if (!s->prepared) {
		createInstance(s);
		findPhysicalDevice(s);
		createDevice(s);
		createDescriptors(s);
		createComputePipeline(s, "spa/plugins/vulkan/shaders/main.spv");
		createCommandBuffer(s);
		s->prepared = true;
	}
	return 0;
}

int spa_vulkan_unprepare(struct vulkan_state *s)
{
	if (s->prepared) {
		vkDestroyShaderModule(s->device, s->computeShaderModule, NULL);
		vkDestroyDescriptorPool(s->device, s->descriptorPool, NULL);
		vkDestroyDescriptorSetLayout(s->device, s->descriptorSetLayout, NULL);
		vkDestroyPipelineLayout(s->device, s->pipelineLayout, NULL);
		vkDestroyPipeline(s->device, s->pipeline, NULL);
		vkDestroyCommandPool(s->device, s->commandPool, NULL);
		vkDestroyDevice(s->device, NULL);
		vkDestroyInstance(s->instance, NULL);
		s->prepared = false;
	}
	return 0;
}

int spa_vulkan_start(struct vulkan_state *s)
{
	s->current_buffer_id = SPA_ID_INVALID;
	s->busy_buffer_id = SPA_ID_INVALID;
	s->ready_buffer_id = SPA_ID_INVALID;
	return 0;
}

int spa_vulkan_stop(struct vulkan_state *s)
{
        VK_CHECK_RESULT(vkDeviceWaitIdle(s->device));
	return 0;
}

int spa_vulkan_ready(struct vulkan_state *s)
{
	VkResult result;

	if (s->busy_buffer_id == SPA_ID_INVALID)
		return 0;

	result = vkGetFenceStatus(s->device, s->fence);
	if (result == VK_NOT_READY)
		return -EBUSY;
	VK_CHECK_RESULT(result);

	s->ready_buffer_id = s->busy_buffer_id;
	s->busy_buffer_id = SPA_ID_INVALID;

	return 0;
}

int spa_vulkan_process(struct vulkan_state *s, uint32_t buffer_id)
{
	updateDescriptors(s, buffer_id);
	runCommandBuffer(s);

	return 0;
}
