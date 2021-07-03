const std = @import("std");
const glfw = @import("glfw.zig");
const vk = @import("vulkan.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){.backing_allocator = std.heap.c_allocator};
    defer _ = gpa.deinit();
    const allocator: *std.mem.Allocator = &gpa.allocator; _ = allocator;

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
        
        var required_extensions = try std.ArrayListUnmanaged([*]const u8).initCapacity(allocator, glfw.requiredVulkanExtensions().len);
        defer required_extensions.deinit(allocator);
        try required_extensions.appendSlice(allocator, glfw.requiredVulkanExtensions());
        
        var create_info: vk.Instance.CreateInfo = .{
            .flags = 0,
            .enabled_layer_names = @as([]const [*]const u8, ([_]([*]const u8){})[0..]),
            .enabled_extension_names = required_extensions.items,
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
        
        graphics_queue: vk.Queue,
        present_queue: vk.Queue,
        
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
        // Block output variable
        var blk_out: VulkanComponents = .{
            .surface = undefined,
            .device = undefined,
            
            .swapchain = undefined,
            .swapchain_format = undefined,
            .swapchain_extent = undefined,
            
            .graphics_queue = undefined,
            .present_queue = undefined,
        };
        
        // Initialize surface
        blk_out.surface = .{ .handle = try window.createVulkanSurface(null, instance.handle) };
        
        // List physical devices, and select one.
        const physical_devices_slice = try instance.enumeratePhysicalDevicesAlloc(allocator);
        defer allocator.free(physical_devices_slice);
        const physical_device = VulkanComponents.selectPhysicalDevice(physical_devices_slice); // Selected physical device.
        
        // Ensure that selected device has surface formats and present modes.
        if (blk_out.surface.formatCount(physical_device) == 0) { return error.SelectedGpuSupportsNoSurfaceFormats; }
        if (blk_out.surface.presentModeCount(physical_device) == 0) { return error.SelectedGpuSupportsNoPresentModes; }
        
        const queue_family_properties = try physical_device.getQueueFamilyPropertiesAlloc(allocator);
        defer allocator.free(queue_family_properties);
        
        const graphics_queue_idx = VulkanComponents.selectGraphicsQueueIdx(queue_family_properties);
        const present_queue_idx = try VulkanComponents.selectPresentQueueIdx(physical_device, blk_out.surface, queue_family_properties);
        
        // List of required device extensions
        const required_device_extensions = &[_][*]const u8{
            vk.c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
        };
        
        // Ensure all required extensions are present
        ensure_required_extensions_present: {
            
            const available_device_extensions = try physical_device.enumerateExtensionPropertiesAlloc(allocator, null);
            defer allocator.free(available_device_extensions);
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
            .queue_create_infos = &[_]vk.Queue.CreateInfo{
                .{ // Graphics queue
                    .flags = 0,
                    .queue_family_index = graphics_queue_idx,
                    .queue_count = 1,
                    .queue_priorities = &[_]f32{1.0},
                },
                .{ // Present queue
                    .flags = 0,
                    .queue_family_index = present_queue_idx,
                    .queue_count = 1,
                    .queue_priorities = &[_]f32{1.0},
                },
            },
            .enabled_extension_names = required_device_extensions,
            .enabled_features = &physical_device.getFeatures(),
        };
        
        blk_out.device = try physical_device.createDevice(null, device_create_info);
        
        blk_out.graphics_queue = blk_out.device.getQueue(0, graphics_queue_idx);
        blk_out.present_queue = blk_out.device.getQueue(0, present_queue_idx);
        
        const surface_capabilities = try blk_out.surface.getCapabilities(physical_device);
        
        const swap_surface_format: vk.SurfaceKHR.SurfaceFormat = try VulkanComponents.selectSwapchainSurfaceFormat(allocator, blk_out.surface, physical_device);
        const swap_surface_present_mode: vk.SurfaceKHR.PresentMode = try VulkanComponents.selectSwapchainSurfacePresentMode(allocator, blk_out.surface, physical_device);
        
        const swap_surface_extent: vk.Extent2D = VulkanComponents.selectSwapchainSurfaceExtent(window, surface_capabilities);
        const swap_surface_image_count =
        if ( (surface_capabilities.maxImageCount == 0) or (surface_capabilities.maxImageCount >= surface_capabilities.minImageCount + 1) )
        surface_capabilities.minImageCount + 1
        else surface_capabilities.minImageCount;
        
        blk_out.swapchain_format = swap_surface_format.format;
        blk_out.swapchain_extent = swap_surface_extent;
        
        const swapchain_create_info = vk.SwapchainKHR.CreateInfo {
            .flags = 0,
            .surface = blk_out.surface,
            .min_image_count = swap_surface_image_count,
            .image_format = swap_surface_format.format,
            .image_color_space = swap_surface_format.colorSpace,
            .image_extent = swap_surface_extent,
            .image_array_layers = 1,
            .image_usage = vk.c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .image_sharing_mode = if (graphics_queue_idx == present_queue_idx) vk.c.VK_SHARING_MODE_EXCLUSIVE else vk.c.VK_SHARING_MODE_CONCURRENT,
            .queue_family_indexes = if (graphics_queue_idx == present_queue_idx) &[_]u32{ graphics_queue_idx, present_queue_idx } else null,
            .pre_transform = surface_capabilities.currentTransform,
            .present_mode = swap_surface_present_mode,
            .clipped = true,
            .old_swapchain = null,
        };
        
        blk_out.swapchain = try blk_out.device.createSwapchainKHR(null, swapchain_create_info);
        
        break :blk blk_out;
    };
    defer {
        vulkan_components.swapchain.deinit(null, vulkan_components.device);
        vulkan_components.device.deinit(null);
        vulkan_components.surface.deinit(null, instance);
    }
    
    const swap_images: []const vk.Image = blk: {
        var image_buffer: [16]vk.Image = undefined;
        
        const image_count = vulkan_components.swapchain.imageCount(vulkan_components.device);
        const images_slice: []vk.Image = image_buffer[0..image_count];
        
        try vulkan_components.swapchain.getImages(vulkan_components.device, images_slice);
        break :blk images_slice;
    };
    
    const swap_image_views: []const vk.Image.View = blk: {
        var image_view_buffer: [16]vk.Image.View = undefined;
        
        const image_count = swap_images.len;
        const image_views_slice: []vk.Image.View = image_view_buffer[0..image_count];
        
        for (swap_images) |image, idx| {
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
    };
    defer for (swap_image_views) |img_view| { img_view.deinit(null, vulkan_components.device); };
    
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
        
        
        
    }
    
}
