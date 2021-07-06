const std = @import("std");
pub const c = @import("c.zig");

pub inline fn makeVersion(major: u32, minor: u32, patch: u32) u32 {
    return (major << 22) | (minor << 12) | (patch);
}

pub inline fn makeApiVersion(variant: u32, major: u32, minor: u32, patch: u32) u32 {
    return (variant << 29) | (major << 22) | (minor << 12) | (patch);
}

pub const ExtensionProperties = c.VkExtensionProperties;

pub const Extent2D = c.VkExtent2D;
pub const Excent3D = c.VkExtent3D;

pub const Offset2D = c.VkOffset2D;
pub const Offset3D = c.VkOffset3D;

pub const Rect2D = c.VkRect2D;

pub const Format = c.VkFormat;
pub const ColorSpaceKHR = c.VkColorSpaceKHR;

/// Vulkan Result Enum
pub const Result: type = blk: {
    const TypeInfo = std.builtin.TypeInfo;
    const c_namespace = c;
    
    var blk_out: TypeInfo = .{ .Enum = undefined };
    
    const vulkan_result_name_prefix = "VK_";
    const vulkan_result_names = &[_][]const u8{
        // (c name)                                              // (zig name)
        "VK_SUCCESS",                                            // success
        "VK_NOT_READY",                                          // not_ready
        "VK_TIMEOUT",                                            // timeout
        "VK_EVENT_SET",                                          // event_set
        "VK_EVENT_RESET",                                        // event_reset
        "VK_INCOMPLETE",                                         // incomplete
        "VK_ERROR_OUT_OF_HOST_MEMORY",                           // error_out_of_host_memory
        "VK_ERROR_OUT_OF_DEVICE_MEMORY",                         // error_out_of_device_memory
        "VK_ERROR_INITIALIZATION_FAILED",                        // error_initialization_failed
        "VK_ERROR_DEVICE_LOST",                                  // error_device_lost
        "VK_ERROR_MEMORY_MAP_FAILED",                            // error_memory_map_failed
        "VK_ERROR_LAYER_NOT_PRESENT",                            // error_layer_not_present
        "VK_ERROR_EXTENSION_NOT_PRESENT",                        // error_extension_not_present
        "VK_ERROR_FEATURE_NOT_PRESENT",                          // error_feature_not_present
        "VK_ERROR_INCOMPATIBLE_DRIVER",                          // error_incompatible_driver
        "VK_ERROR_TOO_MANY_OBJECTS",                             // error_too_many_objects
        "VK_ERROR_FORMAT_NOT_SUPPORTED",                         // error_format_not_supported
        "VK_ERROR_FRAGMENTED_POOL",                              // error_fragmented_pool
        "VK_ERROR_UNKNOWN",                                      // error_unknown
        "VK_ERROR_OUT_OF_POOL_MEMORY",                           // error_out_of_pool_memory
        "VK_ERROR_INVALID_EXTERNAL_HANDLE",                      // error_invalid_external_handle
        "VK_ERROR_FRAGMENTATION",                                // error_fragmentation
        "VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS",               // error_invalid_opaque_capture_address
        "VK_ERROR_SURFACE_LOST_KHR",                             // error_surface_lost_khr
        "VK_ERROR_NATIVE_WINDOW_IN_USE_KHR",                     // error_native_window_in_use_khr
        "VK_SUBOPTIMAL_KHR",                                     // suboptimal_khr
        "VK_ERROR_OUT_OF_DATE_KHR",                              // error_out_of_date_khr
        "VK_ERROR_INCOMPATIBLE_DISPLAY_KHR",                     // error_incompatible_display_khr
        "VK_ERROR_VALIDATION_FAILED_EXT",                        // error_validation_failed_ext
        "VK_ERROR_INVALID_SHADER_NV",                            // error_invalid_shader_nv
        "VK_ERROR_INVALID_DRM_FORMAT_MODIFIER_PLANE_LAYOUT_EXT", // error_invalid_drm_format_modifier_plane_layout_ext
        "VK_ERROR_NOT_PERMITTED_EXT",                            // error_not_permitted_ext
        "VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT",          // error_full_screen_exclusive_mode_lost_ext
        "VK_THREAD_IDLE_KHR",                                    // thread_idle_khr
        "VK_THREAD_DONE_KHR",                                    // thread_done_khr
        "VK_OPERATION_DEFERRED_KHR",                             // operation_deferred_khr
        "VK_OPERATION_NOT_DEFERRED_KHR",                         // operation_not_deferred_khr
        "VK_PIPELINE_COMPILE_REQUIRED_EXT",                      // pipeline_compile_required_ext
        "VK_ERROR_OUT_OF_POOL_MEMORY_KHR",                       // error_out_of_pool_memory_khr
        "VK_ERROR_INVALID_EXTERNAL_HANDLE_KHR",                  // error_invalid_external_handle_khr
        "VK_ERROR_FRAGMENTATION_EXT",                            // error_fragmentation_ext
        "VK_ERROR_INVALID_DEVICE_ADDRESS_EXT",                   // error_invalid_device_address_ext
        "VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS_KHR",           // error_invalid_opaque_capture_address_khr
        "VK_ERROR_PIPELINE_COMPILE_REQUIRED_EXT",                // error_pipeline_compile_required_ext
        "VK_RESULT_MAX_ENUM",                                    // result_max_enum
    };
    
    blk_out.Enum.layout = .Auto;
    blk_out.Enum.tag_type = c.VkResult;
    blk_out.Enum.decls = &[_]TypeInfo.Declaration{};
    blk_out.Enum.is_exhaustive = true;
    blk_out.Enum.fields = undefined;
    
    var fields_buf: [vulkan_result_names.len]TypeInfo.EnumField = undefined;
    var fields: []TypeInfo.EnumField = fields_buf[0..];
    fields.len = 0;
    
    for (vulkan_result_names) |vk_result_name| {
        @setEvalBranchQuota(vk_result_name.len * 60);
        if (!@hasDecl(c_namespace, vk_result_name)) continue;
        
        var zig_name: [vk_result_name.len - vulkan_result_name_prefix.len]u8 = undefined;
        _ = std.ascii.lowerString(zig_name[0..], vk_result_name[vulkan_result_name_prefix.len..]);
        
        fields.len += 1;
        fields[fields.len - 1] = .{
            .name = zig_name[0..],
            .value = @field(c_namespace, vk_result_name),
        };
    }
    
    blk_out.Enum.fields = fields;
    
    break :blk @Type(blk_out);
};

/// Error Set reflecting all error values in the Vulkan Result Enum.
pub const Error: type = blk: {
    const TypeInfo = std.builtin.TypeInfo;
    
    var blk_out: TypeInfo = .{ .ErrorSet = undefined };
    
    const result_enum_info = @typeInfo(Result).Enum;
    var error_arr: [result_enum_info.fields.len]TypeInfo.Error = undefined;
    
    var error_slice: []TypeInfo.Error = error_arr[0..];
    error_slice.len = 0;
    
    for (result_enum_info.fields) |efield| {
        const is_error = efield.value < 0;
        if (!is_error) continue;
        
        error_slice.len += 1;
        error_slice[error_slice.len - 1].name = efield.name[6..];
    }
    
    blk_out.ErrorSet = error_slice;
    
    break :blk @Type(blk_out);
    
};

/// If the given Vulkan Result is an error value, returns an equivalent error. Otherwise, returns the result value.
pub fn resultToError(result: anytype) Error!Result {
    const T = @TypeOf(result);
    
    std.debug.assert(T == Result or T == @typeInfo(Result).Enum.tag_type);
    
    const enum_tag = if (T == Result) result else @intToEnum(Result, result);
    const value = if (T == Result) @enumToInt(result) else result;
    if (value >= 0) return enum_tag;
    
    const equivalent_errname = @tagName(enum_tag)[6..];
    
    inline for(@typeInfo(Error).ErrorSet.?) |errfield| {
        if (std.mem.eql(u8, equivalent_errname, errfield.name)) {
            return @field(Error, errfield.name);
        }
    }
    
    unreachable; // This shouldn't be reached. vulkan.Error or vulkan.Result is likely not fully populated to mirror the C API due to an update or something.\n
}

pub const LayerProperties = extern struct {
    properties: c.VkLayerProperties,
    
    pub fn count() u32 {
        var len: u32 = undefined;
        const result = c.vkEnumerateInstanceLayerProperties(&len, null);
        // This should return successfully, since all we're doing is querying the length. Otherwise, I presume something is very wrong.
        std.debug.assert(@intToEnum(Result, result) == .success);
        return len;
    }
    
    pub fn enumerate(out: []LayerProperties) !void {
        var len = count();
        std.debug.assert(out.len >= len);
        
        const result = c.vkEnumerateInstanceLayerProperties(&len, @ptrCast(c.VkLayerProperties, out.ptr));
        const try_result = resultToError(@intToEnum(Result, result));
        
        if (try_result != .success)
        return error.FailedToQueryInstanceLayerProperties;
    }
    
    pub fn enumerateAlloc(allocator: *std.mem.Allocator) ![]LayerProperties {
        const n = count();
        const out = try allocator.allocAdvanced(LayerProperties, null, n, .exact);
        try enumerate(out);
        return out;
    }
    
};

pub const Instance = struct {
    const Self = @This();
    handle: Handle,
    
    pub fn init(vk_allocator: ?*const c.VkAllocationCallbacks, app_info: ApplicationInfo, instance_create_info: CreateInfo) !Instance {
        const vk_app_info = app_info.toVkApplicationInfo();
        const vk_instance_create_info = instance_create_info.toVkInstanceCreateInfo(&vk_app_info);
        
        var instance: Instance = undefined;
        
        const result = c.vkCreateInstance(&vk_instance_create_info, vk_allocator, &instance.handle);
        const try_result = try resultToError(result);
        
        if (try_result == .success) return instance
        else return error.FailedToCreateVulkanInstance;
        
    }
    
    pub fn deinit(self: Self, vk_allocator: ?*const c.VkAllocationCallbacks) void {
        c.vkDestroyInstance(self.handle, vk_allocator);
    }
    
    
    
    pub fn physicalDeviceCount(self: Self) u32 {
        var count: u32 = undefined;
        const result = @intToEnum(Result, c.vkEnumeratePhysicalDevices(self.handle, &count, null));
        // Since we're just querying the number of devices, this shouldn't fail. Otherwise, I presume something is very wrong.
        std.debug.assert(result == .success);
        return count;
    }
    
    pub fn enumeratePhysicalDevices(self: Self, out: []PhysicalDevice) !void {
        // The output buffer should have a length greater than or equal to the number of physical devices,
        // queried via `instance.physicalDeviceCount`
        var count = self.physicalDeviceCount();
        std.debug.assert(out.len >= count);
        
        const result = c.vkEnumeratePhysicalDevices(self.handle, &count, @ptrCast([*]PhysicalDevice.Handle, out.ptr));
        const try_result = try resultToError(@intToEnum(Result, result));
        
        if (try_result != .success)
        return error.FailedToQueryPhysicalDevices;
    }
    
    pub fn enumeratePhysicalDevicesAlloc(self: Self, allocator: *std.mem.Allocator) ![]PhysicalDevice {
        const n = self.physicalDeviceCount();
        const out = try allocator.allocAdvanced(PhysicalDevice, null, n, .exact);
        errdefer allocator.free(out);
        try self.enumeratePhysicalDevices(out);
        return out;
    }
    
    
    
    pub fn physicalDeviceGroupCount(self: Self) u32 {
        var count: u32 = undefined;
        const result = c.vkEnumeratePhysicalDeviceGroups(self.handle, &count, null);
        // Since we're just querying the number of devices, this shouldn't fail. Otherwise, I presume something is very wrong.
        std.debug.assert(@intToEnum(Result, result) == .success);
        return count;
    }
    
    pub fn enumeratePhysicalDeviceGroups(self: Self, out: []PhysicalDevice.GroupProperties) !void {
        var count = self.physicalDeviceGroupCount();
        std.debug.assert(out.len >= count);
        
        const result = c.vkEnumeratePhysicalDeviceGroups(self.handle, &count, out.ptr);
        const try_result = try resultToError(@intToEnum(Result, result));
        
        if (try_result != .success)
        return error.FailedToQueryPhysicalDeviceGroups;
    }
    
    pub fn enumeratePhysicalDeviceGroupsAlloc(self: Self, allocator: *std.mem.Allocator) ![]PhysicalDevice.GroupProperties {
        const n = self.physicalDeviceGroupCount();
        const out = try allocator.allocAdvanced(PhysicalDevice.GroupProperties, null, n, .exact);
        try self.enumeratePhysicalDeviceGroups(out);
        return out;
    }
    
    
    
    pub fn extensionCount(_: Self, layer_name: ?[]const u8) u32 {
        var count: u32 = undefined;
        const result = @intToEnum(Result, c.vkEnumerateInstanceExtensionProperties(if (layer_name) |ln| ln.ptr else null, &count, null));
        // Since we're just querying the number of extensions, this shouldn't fail. Otherwise, I presume something is very wrong.
        std.debug.assert(result == .success);
        return count;
    }
    
    pub fn enumerateExtensionProperties(self: Self, out: []ExtensionProperties, layer_name: ?[]const u8) !void {
        // The output buffer should have a length greater than or equal to the number of physical devices,
        // queried via `instance.extensionCount`
        var count = self.extensionCount(layer_name);
        std.debug.assert(out.len >= count);
        
        const result = c.vkEnumerateInstanceExtensionProperties(if (layer_name) |ln| ln.ptr else null, &count, out.ptr);
        const try_result = try resultToError(@intToEnum(Result, result));
        
        if (try_result != .success)
        return error.FailedToQueryInstanceExtensions;
    }
    
    pub fn enumerateExtensionPropertiesAlloc(self: Self, allocator: *std.mem.Allocator, layer_name: ?[]const u8) ![]ExtensionProperties {
        const n = self.extensionCount(layer_name);
        const out = try allocator.allocAdvanced(ExtensionProperties, null, n, .exact);
        try self.enumerateExtensionProperties(out, layer_name);
        return out;
    }
    
    
    
    pub const ApplicationInfo = struct {
        next: ?*const c_void = null,
        
        application_name: [*]const u8,
        application_version: u32,
        
        engine_name: [*c]const u8,
        engine_version: u32,
        
        api_version: u32,
        
        fn toVkApplicationInfo(self: ApplicationInfo) c.VkApplicationInfo {
            return c.VkApplicationInfo {
                .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
                .pNext = self.next,
                
                .pApplicationName = self.application_name,
                .applicationVersion = self.application_version,
                
                .pEngineName = self.engine_name,
                .engineVersion = self.engine_version,
                
                .apiVersion = self.engine_version,
            };
        }
        
    };
    
    pub const CreateInfo = struct {
        next: ?*const c_void = null,
        flags: c.VkInstanceCreateFlags,
        
        enabled_layer_names: []const [*]const u8,
        enabled_extension_names: []const [*]const u8,
        
        fn toVkInstanceCreateInfo(self: CreateInfo, vk_app_info: *const c.VkApplicationInfo) c.VkInstanceCreateInfo {
            return c.VkInstanceCreateInfo {
                .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                
                .pNext = self.next,
                .flags = self.flags,
                
                .pApplicationInfo = vk_app_info,
                
                .enabledLayerCount = @intCast(u32, self.enabled_layer_names.len),
                .ppEnabledLayerNames = self.enabled_layer_names.ptr,
                
                .enabledExtensionCount = @intCast(u32, self.enabled_extension_names.len),
                .ppEnabledExtensionNames = self.enabled_extension_names.ptr,
            };
        }
        
    };
    
    pub const Handle = c.VkInstance;
};

pub const SurfaceKHR = struct {
    pub const Self = @This();
    handle: Handle,
    
    pub fn deinit(self: Self, vk_allocator: ?*const c.VkAllocationCallbacks, instance: Instance) void {
        c.vkDestroySurfaceKHR(instance.handle, self.handle, vk_allocator);
    }
    
    pub fn getCapabilities(self: Self, physical_device: PhysicalDevice) !SurfaceKHR.Capabilities {
        var out: SurfaceKHR.Capabilities = undefined;
        const result = c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device.handle, self.handle, &out);
        
        const try_result = try resultToError(@intToEnum(Result, result));
        if (try_result != .success)
        return error.FailedToQueryPhysicalDeviceSurfaceCapabilitiesKHR;
        
        return out;
    }
    
    
    
    pub fn formatCount(self: Self, physical_device: PhysicalDevice) u32 {
        var out: u32 = undefined;
        const result = c.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device.handle, self.handle, &out, null);
        // Since we're just querying the number of surface formats, this invariant should never occur.
        std.debug.assert(@intToEnum(Result, result) == .success);
        return out;
    }
    
    pub fn getFormats(self: Self, physical_device: PhysicalDevice, out: []SurfaceFormat) !void {
        // The output buffer should have a length equal to or greater than the number of surface formats,
        // queried via `surface.formatCount`
        var count = self.formatCount(physical_device);
        std.debug.assert(out.len >= count);
        
        const result = c.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device.handle, self.handle, &count, out.ptr);
        const try_result = try resultToError(@intToEnum(Result, result));
        
        if (try_result != .success)
        return error.FailedToQueryPhysicalDeviceSurfaceFormatsKHR;
    }
    
    pub fn getFormatsAlloc(self: Self, physical_device: PhysicalDevice, allocator: *std.mem.Allocator) ![]SurfaceFormat {
        const n = self.formatCount(physical_device);
        const out = try allocator.allocAdvanced(SurfaceFormat, null, n, .exact);
        errdefer allocator.free(out);
        try self.getFormats(physical_device, out);
        return out;
    }
    
    
    
    pub fn presentModeCount(self: Self, physical_device: PhysicalDevice) u32 {
        var out: u32 = undefined;
        const result = c.vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device.handle, self.handle, &out, null);
        // Since we're just querying the number of present modes, this invariant should never occur.
        std.debug.assert(@intToEnum(Result, result) == .success);
        return out;
    }
    
    pub fn getPresentModes(self: Self, physical_device: PhysicalDevice, out: []PresentMode) !void {
        // The output buffer should have a length equal to or greater than the number of surface present modes,
        // queried via `surface.presentModeCount`
        var count = self.presentModeCount(physical_device);
        std.debug.assert(out.len >= count);
        
        const result = c.vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device.handle, self.handle, &count, out.ptr);
        const try_result = try resultToError(@intToEnum(Result, result));
        
        if (try_result != .success)
        return error.FailedToQueryPhysicalDeviceSurfacePresentModesKHR;
    }
    
    pub fn getPresentModesAlloc(self: Self, physical_device: PhysicalDevice, allocator: *std.mem.Allocator) ![]PresentMode {
        const n = self.presentModeCount(physical_device);
        const out = try allocator.allocAdvanced(PresentMode, null, n, .exact);
        errdefer allocator.free(out);
        try self.getPresentModes(physical_device, out);
        return out;
    }
    
    
    
    pub const PresentMode = c.VkPresentModeKHR;
    pub const Capabilities = c.VkSurfaceCapabilitiesKHR;
    pub const SurfaceFormat = c.VkSurfaceFormatKHR;
    
    pub const Handle = c.VkSurfaceKHR;
};

pub const PhysicalDevice = struct {
    const Self = @This();
    handle: Handle,
    
    pub fn createDevice(self: Self, vk_allocator: ?*const c.VkAllocationCallbacks, create_info: Device.CreateInfo) !Device {
        var out: Device = undefined;
        
        const vk_create_info = create_info.toVkDeviceCreateInfo();
        const result = c.vkCreateDevice(self.handle, &vk_create_info, vk_allocator, &out.handle);
        
        const try_result = try resultToError(@intToEnum(Result, result));
        if (try_result != .success)
        return error.FailedToCreateLogicalDevice;
        
        return out;
    }
    
    pub fn getProperties(self: Self) Properties {
        var out: Properties = undefined;
        c.vkGetPhysicalDeviceProperties(self.handle, &out);
        return out;
    }
    
    pub fn getFeatures(self: Self) Features {
        var out: Features = undefined;
        c.vkGetPhysicalDeviceFeatures(self.handle, &out);
        return out;
    }
    
    
    
    pub fn extensionCount(self: Self, layer_name: ?[]const u8) u32 {
        var count: u32 = undefined;
        const result = @intToEnum(Result, c.vkEnumerateDeviceExtensionProperties(self.handle, if (layer_name) |ln| ln.ptr else null, &count, null));
        // Since we're just querying the number of extensions, this shouldn't fail. Otherwise, I presume something is very wrong.
        std.debug.assert(result == .success);
        return count;
    }
    
    pub fn enumerateExtensionProperties(self: Self, out: []ExtensionProperties, layer_name: ?[]const u8) !void {
        // The output buffer should have a length greater than or equal to the number of physical devices,
        // queried via `instance.extensionCount`
        var count = self.extensionCount(layer_name);
        std.debug.assert(out.len >= count);
        
        const result = c.vkEnumerateDeviceExtensionProperties(self.handle, if (layer_name) |ln| ln.ptr else null, &count, out.ptr);
        const try_result = try resultToError(@intToEnum(Result, result));
        
        if (try_result != .success)
        return error.FailedToQueryPhysicalDeviceExtensions;
    }
    
    pub fn enumerateExtensionPropertiesAlloc(self: Self, allocator: *std.mem.Allocator, layer_name: ?[]const u8) ![]ExtensionProperties {
        const n = self.extensionCount(layer_name);
        const out = try allocator.allocAdvanced(ExtensionProperties, null, n, .exact);
        errdefer allocator.free(out);
        try self.enumerateExtensionProperties(out, layer_name);
        return out;
    }
    
    
    
    pub fn queueFamilyCount(self: Self) u32 {
        var count: u32 = undefined;
        c.vkGetPhysicalDeviceQueueFamilyProperties(self.handle, &count, null);
        return count;
    }
    
    pub fn getQueueFamilyProperties(self: Self, out: []Queue.FamilyProperties) void {
        // The output buffer should have a length greater than or equal to the number of queue families,
        // queried via `physica_device.queueFamilyCount`
        var count: u32 = self.queueFamilyCount();
        std.debug.assert(out.len >= count);
        c.vkGetPhysicalDeviceQueueFamilyProperties(self.handle, &count, out.ptr);
    }
    
    pub fn getQueueFamilyPropertiesAlloc(self: Self, allocator: *std.mem.Allocator) ![]Queue.FamilyProperties {
        const n = self.queueFamilyCount();
        const out = try allocator.allocAdvanced(Queue.FamilyProperties, null, n, .exact);
        self.getQueueFamilyProperties(out);
        return out;
    }
    
    
    
    pub fn getMemoryProperties(self: Self) MemoryProperties {
        var out: MemoryProperties = undefined;
        c.vkGetPhysicalDeviceMemoryProperties(self.handle, &out);
        return out;
    }
    
    
    
    pub fn getSurfaceSupportKHR(self: Self, surface: SurfaceKHR, queue_family_index: u32) bool {
        var surface_support: c.VkBool32 = undefined;
        const result = c.vkGetPhysicalDeviceSurfaceSupportKHR(self.handle, queue_family_index, surface.handle, &surface_support);
        
        // This should succeed. If it doesn't, it likely means that the given surface didn't come from the same instance as the
        // physical device.
        std.debug.assert(@intToEnum(Result, result) == .success);
        
        return surface_support != 0;
    }
    
    
    
    pub const Features = c.VkPhysicalDeviceFeatures;
    pub const Properties = c.VkPhysicalDeviceProperties;
    
    pub const GroupProperties = c.VkPhysicalDeviceGroupProperties;
    pub const MemoryProperties = c.VkPhysicalDeviceMemoryProperties;
    
    pub const Handle = c.VkPhysicalDevice;
};

pub const Device = struct {
    const Self = @This();
    handle: Handle,
    
    pub fn deinit(self: Self, vk_allocator: ?*const c.VkAllocationCallbacks) void {
        c.vkDestroyDevice(self.handle, vk_allocator);
    }
    
    pub fn createShaderModule(self: Self, vk_allocator: ?*const c.VkAllocationCallbacks, create_info: ShaderModule.CreateInfo) !ShaderModule {
        var out: ShaderModule = undefined;
        
        const result = c.vkCreateShaderModule(self.handle, &create_info.toVkShaderModuleCreateInfo(), vk_allocator, &out.handle);
        const try_result = try resultToError(result);
        
        if (try_result != .success)
        return error.FailedToCreateShaderModule;
        
        return out;
    }
    
    pub fn getQueue(self: Self, family_index: u32, queue_index: u32) Queue {
        var out: Queue = undefined;
        c.vkGetDeviceQueue(self.handle, family_index, queue_index, &out.handle);
        std.debug.assert(out.handle != null);
        return out;
    }
    
    pub fn createSwapchainKHR(self: Self, vk_allocator: ?*const c.VkAllocationCallbacks, create_info: SwapchainKHR.CreateInfo) !SwapchainKHR {
        var out: SwapchainKHR = undefined;
        const result = c.vkCreateSwapchainKHR(self.handle, &create_info.toVkSwapchainCreateInfoKHR(), vk_allocator, &out.handle);
        
        const try_result = try resultToError(@intToEnum(Result, result));
        if (try_result != .success)
        return error.FailedToCreateVulkanSwapchainKHR;
        
        return out;
    }
    
    pub const CreateInfo = struct {
        next: ?*const c_void = null,
        flags: c.VkDeviceCreateFlags,
        queue_create_infos: []const Queue.CreateInfo,
        enabled_extension_names: []const [*]const u8,
        enabled_features: *const PhysicalDevice.Features,
        
        fn toVkDeviceCreateInfo(self: CreateInfo) c.VkDeviceCreateInfo {
            return c.VkDeviceCreateInfo {
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                
                .pNext = self.next,
                .flags = self.flags,
                
                .queueCreateInfoCount = @intCast(u32, self.queue_create_infos.len),
                .pQueueCreateInfos = Queue.CreateInfo.toVkDeviceQueueCreateInfoArray(self.queue_create_infos),
                
                .enabledLayerCount = undefined,
                .ppEnabledLayerNames = undefined,
                
                .enabledExtensionCount = @intCast(u32, self.enabled_extension_names.len),
                .ppEnabledExtensionNames = self.enabled_extension_names.ptr,
                
                .pEnabledFeatures = self.enabled_features,
            };
        }
        
    };
    
    pub const Handle = c.VkDevice;
};

pub const Queue = struct {
    const Self = @This();
    handle: Handle,
    
    pub const CreateInfo = extern struct {
        @"0": c.VkStructureType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        next: ?*const c_void = null,
        flags: c.VkDeviceQueueCreateFlags,
        queue_family_index: u32,
        queue_count: u32,
        queue_priorities: [*]const f32,
        
        fn toVkDeviceQueueCreateInfo(self: *const CreateInfo) c.VkDeviceQueueCreateInfo {
            std.debug.assert(self.queue_count > 0);
            return @ptrCast(*const c.VkDeviceQueueCreateInfo, self).*;
        }
        
        fn toVkDeviceQueueCreateInfoArray(self: []const CreateInfo) [*]const c.VkDeviceQueueCreateInfo {
            std.debug.assert(self.len > 0);
            return @ptrCast([*]const c.VkDeviceQueueCreateInfo, self);
        }
        
    };
    
    pub const FamilyProperties = c.VkQueueFamilyProperties;
    pub const Handle = c.VkQueue;
};



pub const SwapchainKHR = struct {
    const Self = @This();
    handle: Handle,
    
    pub fn deinit(self: Self, vk_allocator: ?*const c.VkAllocationCallbacks, device: Device) void {
        c.vkDestroySwapchainKHR(device.handle, self.handle, vk_allocator);
    }
    
    pub fn imageCount(self: Self, device: Device) u32 {
        var out_count: u32 = undefined;
        const result = c.vkGetSwapchainImagesKHR(device.handle, self.handle, &out_count, null);
        std.debug.assert(@intToEnum(Result, result) == .success);
        return out_count;
    }
    
    pub fn getImages(self: Self, device: Device, out: []Image) !void {
        var count = self.imageCount(device);
        std.debug.assert(count >= out.len);
        
        const result = c.vkGetSwapchainImagesKHR(device.handle, self.handle, &count, @ptrCast([*]Image.Handle, out.ptr));
        const try_result = try resultToError(@intToEnum(Result, result));
        
        if (try_result != .success)
        return error.FailedToQueryDeviceSwapchainImagesKHR;
    }
    
    pub fn getImagesAlloc(self: Self, device: Device, allocator: *std.mem.Allocator) ![]Image {
        const n = self.imageCount(device);
        const out = try allocator.allocAdvanced(Image, null, n, .exact);
        errdefer allocator.free(out);
        try self.getImages(device, out);
        return out;
    }
    
    pub const CreateInfo = struct {
        next: ?*const c_void = null,
        flags: c.VkSwapchainCreateFlagsKHR,
        surface: SurfaceKHR,
        min_image_count: u32,
        image_format: Format,
        image_color_space: ColorSpaceKHR,
        image_extent: Extent2D,
        image_array_layers: u32,
        image_usage: c.VkImageUsageFlags,
        image_sharing_mode: c.VkSharingMode,
        queue_family_indexes: ?[]const u32,
        pre_transform: c.VkSurfaceTransformFlagBitsKHR,
        composite_alpha: c.VkCompositeAlphaFlagBitsKHR = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR, // reasonable default
        present_mode: SurfaceKHR.PresentMode,
        clipped: bool,
        old_swapchain: ?SwapchainKHR,
        
        fn toVkSwapchainCreateInfoKHR(self: CreateInfo) c.VkSwapchainCreateInfoKHR {
            return c.VkSwapchainCreateInfoKHR {
                .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
                .pNext = self.next,
                .flags = self.flags,
                .surface = self.surface.handle,
                .minImageCount = self.min_image_count,
                .imageFormat = self.image_format,
                .imageColorSpace = self.image_color_space,
                .imageExtent = self.image_extent,
                .imageArrayLayers = self.image_array_layers,
                .imageUsage = self.image_usage,
                .imageSharingMode = self.image_sharing_mode,
                .queueFamilyIndexCount = if (self.queue_family_indexes) |qfi| @intCast(u32, qfi.len) else 0,
                .pQueueFamilyIndices = if (self.queue_family_indexes) |qfi| qfi.ptr else null,
                .preTransform = self.pre_transform,
                .compositeAlpha = self.composite_alpha,
                .presentMode = self.present_mode,
                .clipped = @boolToInt(self.clipped),
                .oldSwapchain = if (self.old_swapchain) |osc| osc.handle else null,
            };
        }
    };
    
    pub const Handle = c.VkSwapchainKHR;
};

pub const Image = struct {
    const Self = @This();
    handle: Handle,
    
    pub fn view(self: Self, vk_allocator: ?*const c.VkAllocationCallbacks, device: Device, create_info: View.CreateInfo) !View {
        var out: View = undefined;
        const result = c.vkCreateImageView(device.handle, &create_info.toVkImageViewCreateInfo(self), vk_allocator, &out.handle);
        
        const try_result = try resultToError(@intToEnum(Result, result));
        if (try_result != .success)
        return error.FailedToCreateImageView;
        
        return out;
    }
    
    pub const View = ImageView;
    pub const Handle = c.VkImage;
};

const ImageView = struct {
    const Self = @This();
    handle: Handle,
    
    pub fn deinit(self: Self, vk_allocator: ?*const c.VkAllocationCallbacks, device: Device) void {
        c.vkDestroyImageView(device.handle, self.handle, vk_allocator);
    }
    
    pub const CreateInfo = struct {
        next: ?*const c_void = null,
        flags: c.VkImageViewCreateFlags,
        view_type: c.VkImageViewType,
        format: Format,
        components: c.VkComponentMapping,
        subresource_range: c.VkImageSubresourceRange,
        
        fn toVkImageViewCreateInfo(self: CreateInfo, image: Image) c.VkImageViewCreateInfo {
            return c.VkImageViewCreateInfo {
                .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .pNext = self.next,
                .flags = self.flags,
                .image = image.handle,
                .viewType = self.view_type,
                .format = self.format,
                .components = self.components,
                .subresourceRange = self.subresource_range,
            };
        }
    };
    
    pub const Handle = c.VkImageView;
};

/// Created by `Device.createShaderModule`;
pub const ShaderModule = struct {
    const Self = @This();
    handle: Handle,
    
    pub fn deinit(self: Self, vk_allocator: ?*const c.VkAllocationCallbacks, device: Device) void {
        c.vkDestroyShaderModule(device.handle, self.handle, vk_allocator);
    }
    
    pub const CreateInfo = struct {
        next: ?*const c_void = null,
        code: []const u32,
        flags: c.VkShaderModuleCreateFlags,
        
        fn toVkShaderModuleCreateInfo(create_info: CreateInfo) c.VkShaderModuleCreateInfo {
            return c.VkShaderModuleCreateInfo {
                .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                .pNext = create_info.next, 
                .codeSize = create_info.code.len,
                .pCode = create_info.code.ptr,
                .flags = create_info.flags,
            };
        }
        
    };
    
    pub const Handle = c.VkShaderModule;
};
