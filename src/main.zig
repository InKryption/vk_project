const std = @import("std");
const glfw = @import("glfw.zig");
const vk = @import("vulkan.zig");
const c = @import("c.zig");

const build_info = struct {
    pub const mode = @import("builtin").mode;
};

const triangle_shader_vert_bytecode = @embedFile("../zig-out/shader/triangle_vert.spv");
const triangle_shader_frag_bytecode = @embedFile("../zig-out/shader/triangle_frag.spv");



pub fn main() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){.backing_allocator = std.heap.c_allocator};
    defer _ = gpa.deinit();
    const main_allocator: *std.mem.Allocator = &gpa.allocator; _ = main_allocator;
    
    try glfw.init();
    defer glfw.deinit();

    glfw.c.glfwWindowHint(glfw.c.GLFW_CLIENT_API, glfw.c.GLFW_NO_API);
    glfw.c.glfwWindowHint(glfw.c.GLFW_RESIZABLE, glfw.c.GLFW_FALSE);

    const window = try glfw.Window.init("Title", null, .{ .w = 600, .h = 600 });
    defer window.deinit();
    
    const instance: vk.Instance = try blk: {
        
        const app_info: vk.Instance.ApplicationInfo = .{
            .application_name = "vk_project",
            .application_version = vk.makeVersion(1, 0, 0),
            .engine_name = "N/A",
            .engine_version = vk.makeVersion(0, 0, 0),
            .api_version = vk.c.VK_API_VERSION_1_2,
        };
        
        var required_instance_extensions = try std.ArrayListUnmanaged([*]const u8).initCapacity(main_allocator, glfw.requiredVulkanInstanceExtensions().len);
        defer required_instance_extensions.deinit(main_allocator);
        try required_instance_extensions.appendSlice(main_allocator, glfw.requiredVulkanInstanceExtensions());
        
        var create_info: vk.Instance.CreateInfo = .{
            .flags = 0,
            .enabled_layer_names = @as([]const [*]const u8, ([_]([*]const u8){})[0..]),
            .enabled_extension_names = required_instance_extensions.items,
        };
        
        break :blk
        vk.Instance.init(null, app_info, create_info);
        
    };
    defer instance.deinit(null);
    
    
    
    const VulkanComponents = struct {
        device: vk.Device,
        surface: vk.SurfaceKHR,
        
        swapchain: vk.SwapchainKHR,
        swapchain_format: vk.Format,
        swapchain_extent: vk.Extent2D,
        
        graphics_queue_idx: u32,
        present_queue_idx: u32,
        
        fn selectPhysicalDevice(pds: []const vk.PhysicalDevice) vk.PhysicalDevice {
            return pds[0];
        }
        
        
        
        fn selectGraphicsQueueIdx(queue_family_properties: []const vk.Queue.FamilyProperties) u32 {
            var best_index: usize = 0;
            var best_score: usize = 0;
            
            for (queue_family_properties) |qfp, idx| {
                var local_score: usize = 0;
                
                const has_graphics = qfp.queueFlags & vk.c.VK_QUEUE_GRAPHICS_BIT != 0;
                local_score += @boolToInt(has_graphics);
                local_score *= qfp.queueCount;
                
                if (local_score > best_score) {
                    best_index = idx;
                    best_score = local_score;
                }
                
            }
            
            std.debug.assert(best_score > 0);
            return @intCast(u32, best_index);
        }
        
        fn selectPresentQueueIdx(device: vk.PhysicalDevice, _surface: vk.SurfaceKHR, queue_family_properties: []const vk.Queue.FamilyProperties) !u32 {
            
            for (queue_family_properties) |_, idx| {
                if (device.getSurfaceSupportKHR(_surface, @intCast(u32, idx))) {
                    return @intCast(u32, idx);
                }
            }
            
            unreachable;
            
        }
        
        
        
        fn selectSwapchainSurfaceFormat(allctr: *std.mem.Allocator, surface: vk.SurfaceKHR, physical_device: vk.PhysicalDevice) !vk.SurfaceKHR.SurfaceFormat {
            const surface_formats = try surface.getFormatsAlloc(physical_device, allctr);
            defer allctr.free(surface_formats);
            
            for (surface_formats) |surface_format| {
                if (surface_format.format == vk.c.VK_FORMAT_B8G8R8A8_SRGB and surface_format.colorSpace == vk.c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
                    return surface_format;
            }
            
            return surface_formats[0];
        }
        
        fn selectSwapchainSurfacePresentMode(allctr: *std.mem.Allocator, surface: vk.SurfaceKHR, physical_device: vk.PhysicalDevice) !vk.SurfaceKHR.PresentMode {
            const surface_present_modes = try surface.getPresentModesAlloc(physical_device, allctr);
            defer allctr.free(surface_present_modes);
            
            for (surface_present_modes) |present_mode| {
                if (present_mode == vk.c.VK_PRESENT_MODE_MAILBOX_KHR)
                    return present_mode;
            }
            
            return vk.c.VK_PRESENT_MODE_FIFO_KHR;
        }
        
        fn selectSwapchainSurfaceExtent(wnd: glfw.Window, surface_capabilities: vk.SurfaceKHR.Capabilities) vk.Extent2D {
            if (surface_capabilities.currentExtent.width != std.math.maxInt(u32)) {
                return surface_capabilities.currentExtent;
            }
            
            const frame_buffer_size = wnd.frameBufferSize();
            var actual_extent = vk.Extent2D{
                .width = @intCast(u32, frame_buffer_size.w),
                .height = @intCast(u32, frame_buffer_size.h),
            };
            
            actual_extent.width = std.math.clamp(actual_extent.width, surface_capabilities.minImageExtent.width, surface_capabilities.maxImageExtent.width);
            actual_extent.height = std.math.clamp(actual_extent.height, surface_capabilities.minImageExtent.height, surface_capabilities.maxImageExtent.height);
            return actual_extent;
        }
        
    };
    
    const vulkan_components: VulkanComponents = blk: {
        
        // Initialize surface
        const surface: vk.SurfaceKHR = .{ .handle = try window.createVulkanSurface(null, instance.handle) };
        
        // Maximum number of physical devices before heap memory is allocated to store physical device handles (as opposed to stack memory).
        const physical_device_max_stack_buffer_size = 2;
        
        // List physical devices, and select one.
        const physical_devices_slice: []const vk.PhysicalDevice = pds_blk: {
            const pds_n = instance.physicalDeviceCount();
            var pds_buf: [physical_device_max_stack_buffer_size]vk.PhysicalDevice = undefined;
            if (pds_n > pds_buf.len) { break :pds_blk try instance.enumeratePhysicalDevicesAlloc(main_allocator); } else {
                try instance.enumeratePhysicalDevices(pds_buf[0..]);
                break :pds_blk pds_buf[0..pds_n];
            }
        };
        defer {
            if (physical_devices_slice.len > physical_device_max_stack_buffer_size)
            main_allocator.free(physical_devices_slice);
        }
        const physical_device = VulkanComponents.selectPhysicalDevice(physical_devices_slice); // Selected physical device.
        
        // Ensure that selected device has surface formats and present modes.
        if (surface.formatCount(physical_device) == 0) { return error.SelectedGpuSupportsNoSurfaceFormats; }
        if (surface.presentModeCount(physical_device) == 0) { return error.SelectedGpuSupportsNoPresentModes; }
        
        const queue_family_properties = try physical_device.getQueueFamilyPropertiesAlloc(main_allocator);
        defer main_allocator.free(queue_family_properties);
        
        const graphics_queue_idx = VulkanComponents.selectGraphicsQueueIdx(queue_family_properties);
        const present_queue_idx = try VulkanComponents.selectPresentQueueIdx(physical_device, surface, queue_family_properties);
        
        // List of required device extensions
        const required_device_extensions = &[_][*]const u8 {
            vk.c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
        };
        
        // Ensure all required extensions are present
        if (std.builtin.mode == .Debug) ensure_required_extensions_present: {
            
            const available_device_extensions = try physical_device.enumerateExtensionPropertiesAlloc(main_allocator, null);
            defer main_allocator.free(available_device_extensions);
            for (required_device_extensions) |rde| {
                var found: bool = false;
                middle: for (available_device_extensions) |ade| {
                    var i: usize = 1;
                    // Not very pretty, especially since it's three loops nested, but it's the best I can come up with, given the rift between the maximized array buffer, and the size-less pointer.
                    while (i < ade.extensionName.len) : (i += 1) {
                        found = std.mem.eql(u8, rde[0..i], ade.extensionName[0..i]);
                        if (found and ade.extensionName[i] == 0) { break :middle; }
                    }
                }
                if (!found) return error.UnsupportedExtensions;
                
            }
            break :ensure_required_extensions_present;
            
        }
        
        const device_create_info: vk.Device.CreateInfo = .{
            .flags = 0,
            .queue_create_infos = &[_]vk.Queue.CreateInfo {
                .{ // Graphics queue
                    .flags = 0,
                    .queue_family_index = graphics_queue_idx,
                    .queue_count = 1,
                    .queue_priorities = &[_]f32 {1.0},
                },
                .{ // Present queue
                    .flags = 0,
                    .queue_family_index = present_queue_idx,
                    .queue_count = 1,
                    .queue_priorities = &[_]f32 {1.0},
                },
            },
            .enabled_extension_names = required_device_extensions,
            .enabled_features = &physical_device.getFeatures(),
        };
        
        const device = try physical_device.createDevice(null, device_create_info);
        
        const surface_capabilities = try surface.getCapabilities(physical_device);
        
        const swap_surface_format: vk.SurfaceKHR.SurfaceFormat = try VulkanComponents.selectSwapchainSurfaceFormat(main_allocator, surface, physical_device);
        const swap_surface_present_mode: vk.SurfaceKHR.PresentMode = try VulkanComponents.selectSwapchainSurfacePresentMode(main_allocator, surface, physical_device);
        
        const swap_surface_extent: vk.Extent2D = VulkanComponents.selectSwapchainSurfaceExtent(window, surface_capabilities);
        const swap_surface_image_count =
        if ( (surface_capabilities.maxImageCount == 0) or (surface_capabilities.maxImageCount >= surface_capabilities.minImageCount + 1) )
        surface_capabilities.minImageCount + 1
        else surface_capabilities.minImageCount;
        
        const swapchain_create_info = vk.SwapchainKHR.CreateInfo {
            .flags = 0,
            .surface = surface,
            .min_image_count = swap_surface_image_count,
            .image_format = swap_surface_format.format,
            .image_color_space = swap_surface_format.colorSpace,
            .image_extent = swap_surface_extent,
            .image_array_layers = 1,
            .image_usage = vk.c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .image_sharing_mode = if (graphics_queue_idx == present_queue_idx) vk.c.VK_SHARING_MODE_EXCLUSIVE else vk.c.VK_SHARING_MODE_CONCURRENT,
            .queue_family_indexes = if (graphics_queue_idx == present_queue_idx) &[_]u32 { graphics_queue_idx, present_queue_idx } else null,
            .pre_transform = surface_capabilities.currentTransform,
            .present_mode = swap_surface_present_mode,
            .clipped = true,
            .old_swapchain = null,
        };
        
        const swapchain = try device.createSwapchainKHR(null, swapchain_create_info);
        const swapchain_format = swap_surface_format.format;
        const swapchain_extent = swap_surface_extent;
        
        const blk_out: VulkanComponents = .{
            .surface = surface,
            .device = device,
            
            .swapchain = swapchain,
            .swapchain_format = swapchain_format,
            .swapchain_extent = swapchain_extent,
            
            .graphics_queue_idx = graphics_queue_idx,
            .present_queue_idx = present_queue_idx,
        };
        
        break :blk blk_out;
    }; defer {
        vulkan_components.swapchain.deinit(null, vulkan_components.device);
        vulkan_components.device.deinit(null);
        vulkan_components.surface.deinit(null, instance);
    }
    
    const graphics_queue: vk.Queue = vulkan_components.device.getQueue(0, vulkan_components.graphics_queue_idx); _ = graphics_queue;
    const present_queue: vk.Queue = vulkan_components.device.getQueue(0, vulkan_components.present_queue_idx); _ = present_queue;
    
    const swapchain_images: []const vk.Image = blk: {
        var image_buffer: [16]vk.Image = undefined;
        
        const image_count = vulkan_components.swapchain.imageCount(vulkan_components.device);
        const images_slice: []vk.Image = image_buffer[0..image_count];
        
        try vulkan_components.swapchain.getImages(vulkan_components.device, images_slice);
        break :blk images_slice;
    };
    
    const swapchain_image_views: []const vk.Image.View = blk: {
        var image_view_buffer: [16]vk.Image.View = undefined;
        
        const image_count = swapchain_images.len;
        const image_views_slice: []vk.Image.View = image_view_buffer[0..image_count];
        
        for (swapchain_images) |image, idx| {
            image_views_slice[idx] = try image.view(null, vulkan_components.device, .{
                .flags = 0,
                .view_type = vk.c.VK_IMAGE_VIEW_TYPE_2D,
                .format = vulkan_components.swapchain_format,
                .components = .{
                    .r = vk.c.VK_COMPONENT_SWIZZLE_IDENTITY, .g = vk.c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .b = vk.c.VK_COMPONENT_SWIZZLE_IDENTITY, .a = vk.c.VK_COMPONENT_SWIZZLE_IDENTITY,
                },
                .subresource_range = .{
                    .aspectMask = vk.c.VK_IMAGE_ASPECT_COLOR_BIT,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                }
            });
        }
        
        break :blk image_views_slice;
    }; defer for (swapchain_image_views) |img_view| { img_view.deinit(null, vulkan_components.device); };
    
    
    
    const pipeline_layout: vk.c.VkPipelineLayout = blk: {
        const pipeline_layout_create_info = vk.c.VkPipelineLayoutCreateInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .setLayoutCount = 0,
            .pSetLayouts = null,
            .pushConstantRangeCount = 0,
            .pPushConstantRanges = null,
        };
        
        var blk_out: vk.c.VkPipelineLayout = undefined;
        const pipeline_layout_result = vk.c.vkCreatePipelineLayout(vulkan_components.device.handle, &pipeline_layout_create_info, null, &blk_out);
        
        const try_pipeline_layout_result = try vk.resultToError(pipeline_layout_result);
        if ( try_pipeline_layout_result != .success ) return error.FailedToCreatePipelineLayout;
        
        break :blk blk_out;
        
    }; defer vk.c.vkDestroyPipelineLayout(vulkan_components.device.handle, pipeline_layout, null);
    
    const render_pass: vk.c.VkRenderPass = blk: {
        const attachment_descriptions = [_]vk.c.VkAttachmentDescription {
            .{
                .flags = 0,
                .format = vulkan_components.swapchain_format,
                .samples = vk.c.VK_SAMPLE_COUNT_1_BIT,
                .loadOp = vk.c.VK_ATTACHMENT_LOAD_OP_CLEAR,
                .storeOp = vk.c.VK_ATTACHMENT_STORE_OP_STORE,
                .stencilLoadOp = vk.c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
                .stencilStoreOp = vk.c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
                .initialLayout = vk.c.VK_IMAGE_LAYOUT_UNDEFINED,
                .finalLayout = vk.c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            },
        };
        
        const subpass_descriptions = [_]vk.c.VkSubpassDescription {
            .{
                .flags = 0,
                .pipelineBindPoint = vk.c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                
                .colorAttachmentCount = @intCast(u32, attachment_descriptions.len),
                
                .pColorAttachments = &[_]vk.c.VkAttachmentReference {
                    .{
                        .attachment = 0,
                        .layout = vk.c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                    },
                },
                .pResolveAttachments = @as(?[*]vk.c.VkAttachmentReference, null),
                .pDepthStencilAttachment = @as(?[*]vk.c.VkAttachmentReference, null),
                
                .inputAttachmentCount = 0,
                .pInputAttachments = @as(?[*]vk.c.VkAttachmentReference, null),
                
                .preserveAttachmentCount = 0,
                .pPreserveAttachments = @as(?[*]u32, null),
            }
        };
        
        const subpass_dependencies: []const vk.c.VkSubpassDependency = &[_]vk.c.VkSubpassDependency {
            .{
                .srcSubpass = vk.c.VK_SUBPASS_EXTERNAL,
                .dstSubpass = 0,
                
                .srcStageMask = vk.c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                .dstStageMask = vk.c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                
                .srcAccessMask = 0,
                .dstAccessMask = vk.c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
                
                .dependencyFlags = vk.c.VK_DEPENDENCY_BY_REGION_BIT,
            },
        };
        
        const render_pass_create_info = vk.c.VkRenderPassCreateInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .dependencyCount = @intCast(u32, subpass_dependencies.len),
            .pDependencies = subpass_dependencies.ptr,
            
            .attachmentCount = @intCast(u32, attachment_descriptions.len),
            .pAttachments = @as([]const vk.c.VkAttachmentDescription, attachment_descriptions[0..]).ptr,
            
            .subpassCount = @intCast(u32, subpass_descriptions.len),
            .pSubpasses = @as([]const vk.c.VkSubpassDescription, subpass_descriptions[0..]).ptr,
        };
        
        var blk_out: vk.c.VkRenderPass = undefined;
        const result = vk.c.vkCreateRenderPass(vulkan_components.device.handle, &render_pass_create_info, null, &blk_out);
        
        _ = try vk.resultToError(result);
        
        break :blk blk_out;
    }; defer vk.c.vkDestroyRenderPass(vulkan_components.device.handle, render_pass, null);
    
    const graphics_pipeline: vk.c.VkPipeline = blk: {
        
        const triangle_shader_vert = try vulkan_components.device.createShaderModule(null, .{
            .code = @ptrCast([*]const u32, triangle_shader_vert_bytecode)[0..triangle_shader_vert_bytecode.len],
            .flags = 0,
        }); defer triangle_shader_vert.deinit(null, vulkan_components.device);
        
        const triangle_shader_frag = try vulkan_components.device.createShaderModule(null, .{
            .code = @ptrCast([*]const u32, triangle_shader_frag_bytecode)[0..triangle_shader_frag_bytecode.len],
            .flags = 0,
        }); defer triangle_shader_frag.deinit(null, vulkan_components.device);
        
        const shader_stages = [_]vk.c.VkPipelineShaderStageCreateInfo {
            .{ // Vertex Stage
                .sType = vk.c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .pNext = null,
                .flags = 0,
                .stage = vk.c.VK_SHADER_STAGE_VERTEX_BIT,
                .module = triangle_shader_vert.handle,
                .pName = "main",
                .pSpecializationInfo = @as(?[*]const vk.c.VkSpecializationInfo, null),
            },
            .{ // Fragment stage
                .sType = vk.c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .pNext = null,
                .flags = 0,
                .stage = vk.c.VK_SHADER_STAGE_FRAGMENT_BIT,
                .module = triangle_shader_frag.handle,
                .pName = "main",
                .pSpecializationInfo = @as(?[*]const vk.c.VkSpecializationInfo, null),
            }
        };
        
        const vertex_input_state = vk.c.VkPipelineVertexInputStateCreateInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            
            .vertexBindingDescriptionCount = 0,
            .pVertexBindingDescriptions = null,
            
            .vertexAttributeDescriptionCount = 0,
            .pVertexAttributeDescriptions = null,
        };
        
        const input_assembly_state = vk.c.VkPipelineInputAssemblyStateCreateInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .topology = vk.c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            .primitiveRestartEnable = vk.c.VK_FALSE,
        };
        
        const viewport = vk.c.VkViewport {
            .x = 0,
            .y = 0,
            .width = @intToFloat(f32, vulkan_components.swapchain_extent.width),
            .height = @intToFloat(f32, vulkan_components.swapchain_extent.height),
            .minDepth = 0.0,
            .maxDepth = 1.0,
        };
        
        const scissor = vk.Rect2D {
            .offset = .{.x = 0, .y = 0},
            .extent = vulkan_components.swapchain_extent,
        };
        
        const viewport_state = vk.c.VkPipelineViewportStateCreateInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .viewportCount = 1,
            .pViewports = @ptrCast([*]vk.c.VkViewport, &[_]vk.c.VkViewport { viewport }),
            
            .scissorCount = 1,
            .pScissors = @ptrCast([*]vk.Rect2D, &[_]vk.Rect2D { scissor }),
        };
        
        const rasterization_state = vk.c.VkPipelineRasterizationStateCreateInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .depthClampEnable = vk.c.VK_FALSE,
            .rasterizerDiscardEnable = vk.c.VK_FALSE,
            .polygonMode = vk.c.VK_POLYGON_MODE_FILL,
            .lineWidth = 1.0,
            .cullMode = vk.c.VK_CULL_MODE_BACK_BIT,
            .frontFace = vk.c.VK_FRONT_FACE_CLOCKWISE,
            .depthBiasEnable = vk.c.VK_FALSE,
            .depthBiasConstantFactor = 0,
            .depthBiasClamp = 0,
            .depthBiasSlopeFactor = 0,
        };
        
        // Might have to remove this, in case I fucked it up, and just leave it as `null`.
        const depth_stencil_state = vk.c.VkPipelineDepthStencilStateCreateInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .depthTestEnable = vk.c.VK_FALSE,
            .depthWriteEnable = vk.c.VK_FALSE,
            .depthCompareOp = vk.c.VK_COMPARE_OP_NEVER,
            .depthBoundsTestEnable = vk.c.VK_FALSE,
            .stencilTestEnable = vk.c.VK_FALSE,
            .front = .{
                .failOp = vk.c.VK_STENCIL_OP_ZERO,
                .passOp = vk.c.VK_STENCIL_OP_ZERO,
                .depthFailOp = vk.c.VK_STENCIL_OP_ZERO,
                .compareOp = vk.c.VK_COMPARE_OP_NEVER,
                .compareMask = 0,
                .writeMask = 0,
                .reference = 0,
            },
            .back = .{
                .failOp = vk.c.VK_STENCIL_OP_ZERO,
                .passOp = vk.c.VK_STENCIL_OP_ZERO,
                .depthFailOp = vk.c.VK_STENCIL_OP_ZERO,
                .compareOp = vk.c.VK_COMPARE_OP_NEVER,
                .compareMask = 0,
                .writeMask = 0,
                .reference = 0,
            },
            .minDepthBounds = 0.0,
            .maxDepthBounds = 1.0,
        };
        
        const color_blend_attachment_state = vk.c.VkPipelineColorBlendAttachmentState {
            .blendEnable         = vk.c.VK_TRUE,
            .srcColorBlendFactor = vk.c.VK_BLEND_FACTOR_SRC_ALPHA,
            .dstColorBlendFactor = vk.c.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
            .colorBlendOp        = vk.c.VK_BLEND_OP_ADD,
            .srcAlphaBlendFactor = vk.c.VK_BLEND_FACTOR_ONE,
            .dstAlphaBlendFactor = vk.c.VK_BLEND_FACTOR_ZERO,
            .alphaBlendOp        = vk.c.VK_BLEND_OP_ADD,
            .colorWriteMask      = vk.c.VK_COLOR_COMPONENT_R_BIT | vk.c.VK_COLOR_COMPONENT_G_BIT | vk.c.VK_COLOR_COMPONENT_B_BIT | vk.c.VK_COLOR_COMPONENT_A_BIT,
        };
        
        const color_blend_state = vk.c.VkPipelineColorBlendStateCreateInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .logicOpEnable = vk.c.VK_FALSE,
            .logicOp = vk.c.VK_LOGIC_OP_COPY,
            .attachmentCount = 1,
            .pAttachments = @ptrCast([*]const vk.c.VkPipelineColorBlendAttachmentState, &[_]vk.c.VkPipelineColorBlendAttachmentState { color_blend_attachment_state }),
            .blendConstants = [_]f32{ 0.0, 0.0, 0.0, 0.0, },
        };
        
        const multisampling_state_create_info = vk.c.VkPipelineMultisampleStateCreateInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .sampleShadingEnable = vk.c.VK_FALSE,
            .rasterizationSamples = vk.c.VK_SAMPLE_COUNT_1_BIT,
            .minSampleShading = 1.0, // Optional
            .pSampleMask = null, // Optional
            .alphaToCoverageEnable = vk.c.VK_FALSE, // Optional
            .alphaToOneEnable = vk.c.VK_FALSE, // Optional
        };
        
        const graphics_pipeline_create_info = vk.c.VkGraphicsPipelineCreateInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            
            .stageCount = @intCast(u32, shader_stages.len),
            .pStages = &shader_stages,
            
            .pVertexInputState = &vertex_input_state,
            .pInputAssemblyState = &input_assembly_state,
            .pTessellationState = null,
            .pViewportState = &viewport_state,
            .pRasterizationState = &rasterization_state,
            .pMultisampleState = &multisampling_state_create_info,
            .pDepthStencilState = &depth_stencil_state,
            .pColorBlendState = &color_blend_state,
            .pDynamicState = null,
            .layout = pipeline_layout,
            .renderPass = render_pass,
            .subpass = 0,
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
        };
        
        var blk_out: vk.c.VkPipeline = undefined;
        const result = vk.c.vkCreateGraphicsPipelines(vulkan_components.device.handle, null, 1, &graphics_pipeline_create_info, null, &blk_out);
        
        const try_result = try vk.resultToError(result);
        if (try_result != .success) return error.FailedToCreateGraphicsPipeline;
        
        break :blk blk_out;
    }; defer vk.c.vkDestroyPipeline(vulkan_components.device.handle, graphics_pipeline, null);
    
    const swapchain_framebuffers: []const vk.c.VkFramebuffer = blk: {
        var framebuffer_stack: [16]vk.c.VkFramebuffer = undefined;
        
        var framebuffer_slice: []vk.c.VkFramebuffer = undefined;
        framebuffer_slice.len = swapchain_image_views.len;
        framebuffer_slice.ptr = &framebuffer_stack;
        
        for (swapchain_image_views) |sciv, idx| {
            const attachments = [_]vk.c.VkImageView {
                sciv.handle,
            };
            
            const framebuffer_create_info = vk.c.VkFramebufferCreateInfo {
                .sType = vk.c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .pNext = null,
                .flags = 0,
                .renderPass = render_pass,
                .attachmentCount = attachments.len,
                .pAttachments = &attachments,
                .width = vulkan_components.swapchain_extent.width,
                .height = vulkan_components.swapchain_extent.height,
                .layers = 1,
            };
            
            const result = vk.c.vkCreateFramebuffer(vulkan_components.device.handle, &framebuffer_create_info, null, &framebuffer_slice[idx]);
            _ = try vk.resultToError(result);
        }
        
        break :blk framebuffer_slice;
        
    }; defer for (swapchain_framebuffers) |fb| vk.c.vkDestroyFramebuffer(vulkan_components.device.handle, fb, null);
    
    const command_pool: vk.c.VkCommandPool = blk: {
        
        const command_pool_create_info = vk.c.VkCommandPoolCreateInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .pNext = null,
            .queueFamilyIndex = vulkan_components.graphics_queue_idx,
            .flags = 0,
        };
        
        var blk_out: vk.c.VkCommandPool = undefined;
        const result = vk.c.vkCreateCommandPool(vulkan_components.device.handle, &command_pool_create_info, null, &blk_out);
        _ = try vk.resultToError(result);
        
        break :blk blk_out;
        
    }; defer vk.c.vkDestroyCommandPool(vulkan_components.device.handle, command_pool, null);
    
    var command_buffers: std.ArrayListUnmanaged(vk.c.VkCommandBuffer) = try std.ArrayListUnmanaged(vk.c.VkCommandBuffer).initCapacity(main_allocator, swapchain_framebuffers.len);
    defer command_buffers.deinit(main_allocator);
    allocate_command_buffers: {
        const alloc_info = vk.c.VkCommandBufferAllocateInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .pNext = null,
            .level = vk.c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandPool = command_pool,
            .commandBufferCount = @intCast(u32, swapchain_framebuffers.len),
        };
        
        try command_buffers.resize(main_allocator, swapchain_framebuffers.len);
        const result = vk.c.vkAllocateCommandBuffers(vulkan_components.device.handle, &alloc_info, command_buffers.items.ptr);
        _ = try vk.resultToError(result);
        
        break :allocate_command_buffers;
    }
    
    // Setting up the draw commands.
    for (command_buffers.items) |cb, idx| {
        const command_buffer_begin_info = vk.c.VkCommandBufferBeginInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pNext = null,
            .flags = 0,
            .pInheritanceInfo = null,
        };
        
        const result = vk.c.vkBeginCommandBuffer(cb, &command_buffer_begin_info);
        _ = try vk.resultToError(result);
        
        const clear_colors: []const vk.c.VkClearValue = &[_]vk.c.VkClearValue {
            .{.color = .{.float32 = .{0.0, 0.0, 0.0, 1.0} }},
        };
        
        const render_pass_begin_info = vk.c.VkRenderPassBeginInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .pNext = null,
            .renderPass = render_pass,
            .framebuffer = swapchain_framebuffers[idx],
            .renderArea = .{ .offset = .{.x = 0, .y = 0}, .extent = vulkan_components.swapchain_extent },
            .clearValueCount = clear_colors.len,
            .pClearValues = clear_colors.ptr,
            
        };
        
        vk.c.vkCmdBeginRenderPass(cb, &render_pass_begin_info, vk.c.VK_SUBPASS_CONTENTS_INLINE);
        vk.c.vkCmdBindPipeline(cb, vk.c.VK_PIPELINE_BIND_POINT_GRAPHICS, graphics_pipeline);
        vk.c.vkCmdDraw(cb, 3, 1, 0, 0);
        vk.c.vkCmdEndRenderPass(cb);
        
        if (vk.c.vkEndCommandBuffer(cb) != vk.c.VK_SUCCESS)
        return error.FailedToEndCommandBuffer;
        
    }
    
    const Semaphores = struct {
        image_available: vk.c.VkSemaphore,
        render_finished: vk.c.VkSemaphore,
    };
    
    const semaphore: Semaphores = blk: {
        
        const create_info = vk.c.VkSemaphoreCreateInfo {
            .sType = vk.c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
        };
        
        var blk_out_image_available: vk.c.VkSemaphore = undefined;
        var blk_out_render_finished: vk.c.VkSemaphore = undefined;
        
        const result_image_available = vk.c.vkCreateSemaphore(vulkan_components.device.handle, &create_info, null, &blk_out_image_available);
        const try_result_image_available = try vk.resultToError(result_image_available);
        
        const result_render_finished = vk.c.vkCreateSemaphore(vulkan_components.device.handle, &create_info, null, &blk_out_render_finished);
        const try_result_render_finished = try vk.resultToError(result_render_finished);
        
        if (try_result_image_available != .success or try_result_render_finished != .success)
        return error.FailedToCreateSemaphore;
        
        break :blk .{
            .image_available = blk_out_image_available,
            .render_finished = blk_out_render_finished,
        };
        
    }; defer {
        vk.c.vkDestroySemaphore(vulkan_components.device.handle, semaphore.render_finished, null);
        vk.c.vkDestroySemaphore(vulkan_components.device.handle, semaphore.image_available, null);
    }
    
    
    mainloop: while (!window.shouldClose()) {
        glfw.pollEvents();

        const Time = struct {
            var begin: i64 = 0;
            var end: i64 = 0;
        };
        Time.end = std.time.milliTimestamp();
        if (Time.end - Time.begin < 16) {
            continue :mainloop; // Go back and poll events if time step isn't in sync.
        } else Time.begin = std.time.milliTimestamp();
        
        const image_index: u32 = blk: {
            var blk_out: u32 = undefined;
            const result = vk.c.vkAcquireNextImageKHR(
                vulkan_components.device.handle,
                vulkan_components.swapchain.handle,
                1000_000,
                semaphore.image_available,
                null,
                &blk_out
            );
            
            const try_result = try vk.resultToError(result);
            if (try_result == .timeout) {
                if (build_info.mode == .Debug) {
                    const TimeOutHandling = struct {
                        var time_out_counter: usize = 0;
                    };
                    TimeOutHandling.time_out_counter += 1;
                    if (TimeOutHandling.time_out_counter >= 0) return error.AcquireNextImageKHRTimeOut;
                }
                continue :mainloop;
            }
            
            break :blk blk_out;
        };
        
        submit_info_blk: {
            const wait_stages: []const vk.c.VkPipelineStageFlags = &[_]vk.c.VkPipelineStageFlags { vk.c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, };
            const wait_semaphores: []const vk.c.VkSemaphore = &[_]vk.c.VkSemaphore { semaphore.image_available, };
            const signal_semaphores: []const vk.c.VkSemaphore = &[_]vk.c.VkSemaphore { semaphore.render_finished, };
            
            const submit_command_buffers: []const vk.c.VkCommandBuffer = &[_]vk.c.VkCommandBuffer { command_buffers.items[image_index] };
            
            const submit_info = vk.c.VkSubmitInfo {
                .sType = vk.c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
                .pNext = null,
                
                .waitSemaphoreCount = @intCast(u32, wait_semaphores.len),
                .pWaitSemaphores = wait_semaphores.ptr,
                .pWaitDstStageMask = wait_stages.ptr,
                
                .commandBufferCount = @intCast(u32, submit_command_buffers.len),
                .pCommandBuffers = submit_command_buffers.ptr,
                
                .signalSemaphoreCount = @intCast(u32, signal_semaphores.len),
                .pSignalSemaphores = signal_semaphores.ptr,
            };
            
            const result = vk.c.vkQueueSubmit(graphics_queue.handle, 1, &submit_info, null);
            _ = try vk.resultToError(result);
            
            break :submit_info_blk;
        }
        
        presentation_blk: {
            
            const wait_semaphores: []const vk.c.VkSemaphore = &[_]vk.c.VkSemaphore { semaphore.render_finished, };
            const swapchains: []const vk.c.VkSwapchainKHR = &[_]vk.c.VkSwapchainKHR { vulkan_components.swapchain.handle };
            const image_indices: []const u32 = &[_]u32{ image_index };
            
            const present_info = vk.c.VkPresentInfoKHR {
                .sType = vk.c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
                .pNext = null,
                
                .pImageIndices = image_indices.ptr,
                
                .swapchainCount = @intCast(u32, swapchains.len),
                .pSwapchains = swapchains.ptr,
                
                .waitSemaphoreCount = @intCast(u32, wait_semaphores.len),
                .pWaitSemaphores = wait_semaphores.ptr,
                
                .pResults = null,
            };
            const result = vk.c.vkQueuePresentKHR(graphics_queue.handle, &present_info);
            _ = vk.resultToError(result) catch continue :mainloop;
            
            break :presentation_blk;
        }
        
    }
    
}
