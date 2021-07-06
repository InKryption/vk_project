pub const c = @import("c.zig");
pub const vk = @import("vulkan.zig");

pub fn init() !void {
    return if (c.glfwInit() != c.GLFW_TRUE) error.GlfwCantInit;
}

pub fn deinit() void {
    return c.glfwTerminate();
}

pub fn pollEvents() void {
    return c.glfwPollEvents();
}

pub const Window = struct {
    const Self = @This();
    handle: Handle,
    
    pub fn init(title: []const u8, position: ?struct {x: usize, y: usize}, size: struct {w: usize, h: usize}) !Self {
        const user_set_position = position != null;
        
        if (user_set_position) c.glfwWindowHint(c.GLFW_VISIBLE, c.GLFW_FALSE);
        const window_handle = c.glfwCreateWindow(
            @intCast(c_int, size.w),
            @intCast(c_int, size.h),
            title.ptr,
            null,
            null
        );
        
        
        
        if (window_handle) |handle| {
            
            if (user_set_position) {
                const pos = position.?;
                c.glfwSetWindowPos(handle, @intCast(c_int, pos.x), @intCast(c_int, pos.y));
                c.glfwShowWindow(handle);
            }
            
            return Self {
                .handle = handle,
            };
            
        } else {
            return error.CantCreateWindow;
        }
    }
    
    pub fn deinit(self: Self) void {
        c.glfwDestroyWindow(self.handle);
    }
    
    pub fn shouldClose(self: Self) bool {
        return c.glfwWindowShouldClose(self.handle) != 0;
    }
    
    pub fn createVulkanSurface(self: Self, vk_allocator: ?*const c.VkAllocationCallbacks, instance: c.VkInstance) !c.VkSurfaceKHR {
        var out: c.VkSurfaceKHR = undefined;
        const result = c.glfwCreateWindowSurface(instance, self.handle, vk_allocator, &out);
        
        const try_result = try vk.resultToError(@intToEnum(vk.Result, result));
        if (try_result != .success)
        return error.FailedToCreateVulkanSurface;
        
        return out;
    }
    
    pub fn frameBufferSize(self: Self) struct {w: c_int, h: c_int} {
        var w: c_int = undefined;
        var h: c_int = undefined;
        c.glfwGetFramebufferSize(self.handle, &w, &h);
        return .{ .w = w, .h = h };
    }
    
    pub const Handle = *c.GLFWwindow;
};

pub fn requiredVulkanInstanceExtensions() []const [*]const u8 {
    var len: u32 = undefined;
    const out = c.glfwGetRequiredInstanceExtensions(&len);
    
    var slice: [][*]const u8 = undefined;
    slice.ptr = @ptrCast([*][*]const u8, out);
    slice.len = len;
    
    return slice;
}

