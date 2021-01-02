const std = @import("std");
const builtin = @import("builtin");

var libx11: *c_void = undefined;
var libx11_xcb: *c_void = undefined;
var libxcb: *c_void = undefined;

fn loadsym(comptime T: type, lib: *c_void, symbol: [*:0]const u8) !T {
    const fpopt = std.c.dlsym(lib, symbol);
    if (fpopt) |fp| {
        return @ptrCast(T, fp);
    } else return error.SymbolNotFound;
}

pub fn xcbInit(with_xlib: bool) !void {
    if (with_xlib) {
        if (std.c.dlopen("libX11.so", std.c.RTLD_NOW | std.c.RTLD_LOCAL)) |lib| {
            libx11 = lib;
        } else return error.XlibLibraryNotFound;
        errdefer _ = std.c.dlclose(libx11);

        if (std.c.dlopen("libX11-xcb.so", std.c.RTLD_NOW | std.c.RTLD_LOCAL)) |lib| {
            libx11_xcb = lib;
        } else return error.XlibXcbLibraryNotFound;
        errdefer _ = std.c.dlclose(libx11_xcb);

        XOpenDisplay = try loadsym(@TypeOf(XOpenDisplay), libx11, "XOpenDisplay");
        XCloseDisplay = try loadsym(@TypeOf(XCloseDisplay), libx11, "XCloseDisplay");
        XDefaultScreen = try loadsym(@TypeOf(XDefaultScreen), libx11, "XDefaultScreen");
        XFree = try loadsym(@TypeOf(XFree), libx11, "XFree");

        XGetXCBConnection = try loadsym(@TypeOf(XGetXCBConnection), libx11_xcb, "XGetXCBConnection");
        XSetEventQueueOwner = try loadsym(@TypeOf(XSetEventQueueOwner), libx11_xcb, "XSetEventQueueOwner");
    }
    errdefer {
        if (with_xlib) {
            _ = std.c.dlclose(libx11);
            _ = std.c.dlclose(libx11_xcb);
        }
    }

    if (std.c.dlopen("libxcb.so", std.c.RTLD_NOW | std.c.RTLD_LOCAL)) |lib| {
        libxcb = lib;
    } else return error.XCBLibraryNotFound;
    errdefer _ = std.c.dlclose(libxcb);

    xcb_connect = try loadsym(@TypeOf(xcb_connect), libxcb, "xcb_connect");
    xcb_disconnect = try loadsym(@TypeOf(xcb_disconnect), libxcb, "xcb_disconnect");
    xcb_connection_has_error = try loadsym(@TypeOf(xcb_connection_has_error), libxcb, "xcb_connection_has_error");
    xcb_get_setup = try loadsym(@TypeOf(xcb_get_setup), libxcb, "xcb_get_setup");
    xcb_setup_roots_iterator = try loadsym(@TypeOf(xcb_setup_roots_iterator), libxcb, "xcb_setup_roots_iterator");
    xcb_screen_allowed_depths_iterator = try loadsym(@TypeOf(xcb_screen_allowed_depths_iterator), libxcb, "xcb_screen_allowed_depths_iterator");
    xcb_depth_next = try loadsym(@TypeOf(xcb_depth_next), libxcb, "xcb_depth_next");
    xcb_depth_visuals_iterator = try loadsym(@TypeOf(xcb_depth_visuals_iterator), libxcb, "xcb_depth_visuals_iterator");
    xcb_visualtype_next = try loadsym(@TypeOf(xcb_visualtype_next), libxcb, "xcb_visualtype_next");
    xcb_screen_next = try loadsym(@TypeOf(xcb_screen_next), libxcb, "xcb_screen_next");
    xcb_generate_id = try loadsym(@TypeOf(xcb_generate_id), libxcb, "xcb_generate_id");
    xcb_create_window = try loadsym(@TypeOf(xcb_create_window), libxcb, "xcb_create_window");
    xcb_destroy_window = try loadsym(@TypeOf(xcb_destroy_window), libxcb, "xcb_destroy_window");
    xcb_map_window = try loadsym(@TypeOf(xcb_map_window), libxcb, "xcb_map_window");
    xcb_unmap_window = try loadsym(@TypeOf(xcb_unmap_window), libxcb, "xcb_unmap_window");
    xcb_flush = try loadsym(@TypeOf(xcb_flush), libxcb, "xcb_flush");
    xcb_create_colormap = try loadsym(@TypeOf(xcb_create_colormap), libxcb, "xcb_create_colormap");
    xcb_free_colormap = try loadsym(@TypeOf(xcb_free_colormap), libxcb, "xcb_free_colormap");
    xcb_change_property = try loadsym(@TypeOf(xcb_change_property), libxcb, "xcb_change_property");
    xcb_poll_for_event = try loadsym(@TypeOf(xcb_poll_for_event), libxcb, "xcb_poll_for_event");
    xcb_wait_for_event = try loadsym(@TypeOf(xcb_wait_for_event), libxcb, "xcb_wait_for_event");
}

pub fn xcbDeinit(with_xlib: bool) void {
    _ = std.c.dlclose(libxcb);

    if (with_xlib) {
        _ = std.c.dlclose(libx11_xcb);
        _ = std.c.dlclose(libx11);
    }
}

pub const Display = opaque {};

pub const BITMASK = u32;
pub const WINDOW = u32;
pub const PIXMAP = u32;
pub const CURSOR = u32;
pub const GCONTEXT = u32;
pub const DRAWABLE = extern union { window: WINDOW, pixmap: PIXMAP };
pub const ATOM = u32;
pub const COLORMAP = u32;
pub const VISUALID = u32;
pub const TIMESTAMP = u32;
pub const BOOL = u8;
pub const KEYSYM = u32;
pub const KEYCODE = u8;
pub const BUTTON = u8;
pub const VoidCookie = u32;

pub const XCB_ATOM_WM_NAME: ATOM = 39;
pub const XCB_ATOM_STRING: ATOM = 31;

var XOpenDisplay: fn (?[*:0]u8) callconv(.C) ?*Display = undefined;
pub fn xOpenDisplay(display_name: ?[*:0]u8) !*Display {
    return XOpenDisplay(display_name) orelse return error.XOpenDisplayFailed;
}

var XCloseDisplay: fn (*Display) callconv(.C) c_int = undefined;
pub fn xCloseDisplay(display: *Display) void {
    _ = XCloseDisplay(display);
}

var XDefaultScreen: fn (*Display) callconv(.C) c_int = undefined;
pub fn xDefaultScreen(display: *Display) c_int {
    return XDefaultScreen(display);
}

var XGetXCBConnection: fn (*Display) callconv(.C) *Connection = undefined;
pub fn xGetXCBConnection(display: *Display) *Connection {
    return XGetXCBConnection(display);
}

var XSetEventQueueOwner: fn (*Display, c_uint) callconv(.C) void = undefined;
pub fn xSetEventQueueOwner(display: *Display, xcb: bool) void {
    XSetEventQueueOwner(display, if (xcb) 1 else 0);
}

var XFree: fn (*c_void) callconv(.C) void = undefined;
pub fn xFree(data: *c_void) void {
    XFree(data);
}

pub const Connection = opaque {};

var xcb_connect: fn (?[*:0]const u8, ?*c_int) callconv(.C) *Connection = undefined;
pub fn xcbConnect(displayname: ?[*:0]const u8, screenp: ?*c_int) !*Connection {
    const connection = xcb_connect(displayname, screenp);
    errdefer xcbDisconnect(connection);
    try xcbConnectionHasError(connection);
    return connection;
}

var xcb_disconnect: fn (*Connection) callconv(.C) void = undefined;
pub fn xcbDisconnect(connection: *Connection) void {
    return xcb_disconnect(connection);
}

const XCB_CONN_ERROR = 1;
const XCB_CONN_CLOSED_EXT_NOTSUPPORTED = 2;
const XCB_CONN_CLOSED_MEM_INSUFFICIENT = 3;
const XCB_CONN_CLOSED_REQ_LEN_EXCEED = 4;
const XCB_CONN_CLOSED_PARSE_ERR = 5;
const XCB_CONN_CLOSED_INVALID_SCREEN = 6;
const XCB_CONN_CLOSED_FDPASSING_FAILED = 7;

var xcb_connection_has_error: fn (*Connection) callconv(.C) c_int = undefined;
pub fn xcbConnectionHasError(connection: *Connection) !void {
    const val = xcb_connection_has_error(connection);
    return switch (val) {
        0 => {},
        XCB_CONN_ERROR => error.Error,
        XCB_CONN_CLOSED_EXT_NOTSUPPORTED => error.NotSupported,
        XCB_CONN_CLOSED_MEM_INSUFFICIENT => error.OutOfMemory,
        XCB_CONN_CLOSED_REQ_LEN_EXCEED => error.LengthExceeded,
        XCB_CONN_CLOSED_PARSE_ERR => error.ParseError,
        XCB_CONN_CLOSED_INVALID_SCREEN => error.InvalidScreen,
        XCB_CONN_CLOSED_FDPASSING_FAILED => error.FdPassingFailed,
        else => unreachable,
    };
}

const Setup = extern struct {
    status: u8,
    pad0: u8,
    protocol_major_version: u16,
    protocol_minor_version: u16,
    length: u16,
    release_number: u32,
    resource_id_base: u32,
    resource_id_mask: u32,
    motion_buffer_size: u32,
    vendor_len: u16,
    maximum_request_length: u16,
    roots_len: u8,
    pixmap_formats_len: u8,
    image_byte_order: u8,
    bitmap_format_bit_order: u8,
    bitmap_format_scanline_unit: u8,
    bitmap_format_scanline_pad: u8,
    min_keycode: KEYCODE,
    max_keycode: KEYCODE,
    pad1: [4]u8,
};

var xcb_get_setup: fn (*Connection) callconv(.C) *Setup = undefined;
pub fn xcbGetSetup(connection: *Connection) *Setup {
    return xcb_get_setup(connection);
}

const Screen = extern struct {
    root: WINDOW,
    default_colormap: COLORMAP,
    white_pixel: u32,
    black_pixel: u32,
    current_input_masks: u32,
    width_in_pixels: u16,
    height_in_pixels: u16,
    width_in_millimeters: u16,
    height_in_millimeters: u16,
    min_installed_maps: u16,
    max_installed_maps: u16,
    root_visual: u32,
    backing_stores: u8,
    save_unders: u8,
    root_depth: u8,
    allowed_depths_len: u8,
};

const ScreenIterator = extern struct {
    data: *Screen,
    rem: c_int,
    index: c_int,
};

var xcb_setup_roots_iterator: fn (*Setup) callconv(.C) ScreenIterator = undefined;
pub fn xcbSetupRootsIterator(setup: *Setup) ScreenIterator {
    return xcb_setup_roots_iterator(setup);
}

var xcb_screen_next: fn (*ScreenIterator) callconv(.C) void = undefined;
pub fn xcbScreenNext(iterator: *ScreenIterator) void {
    xcb_screen_next(iterator);
}

pub const Depth = extern struct {
    depth: u8,
    pad0: u8,
    visuals_len: u16,
    pad1: [4]u8,
};

const DepthIterator = extern struct {
    data: *Depth,
    rem: c_int,
    index: c_int,
};

var xcb_screen_allowed_depths_iterator: fn (*Screen) callconv(.C) DepthIterator = undefined;
pub fn xcbScreenAllowedDepthsIterator(screen: *Screen) DepthIterator {
    return xcb_screen_allowed_depths_iterator(screen);
}

var xcb_depth_next: fn (*DepthIterator) callconv(.C) void = undefined;
pub fn xcbDepthNext(iterator: *DepthIterator) void {
    xcb_depth_next(iterator);
}

const Visualtype = extern struct {
    visual_id: VISUALID,
    class: u8,
    bits_per_rgb_value: u8,
    colormap_entries: u16,
    red_mask: u32,
    green_mask: u32,
    blue_mask: u32,
    pad0: [4]u8,
};

const VisualtypeIterator = extern struct {
    data: *Visualtype,
    rem: c_int,
    index: c_int,
};

var xcb_depth_visuals_iterator: fn (*Depth) callconv(.C) VisualtypeIterator = undefined;
pub fn xcbDepthVisualsIterator(depth: *Depth) VisualtypeIterator {
    return xcb_depth_visuals_iterator(depth);
}

var xcb_visualtype_next: fn (*VisualtypeIterator) callconv(.C) void = undefined;
pub fn xcbVisualtypeNext(iterator: *VisualtypeIterator) void {
    xcb_visualtype_next(iterator);
}

var xcb_generate_id: fn (*Connection) callconv(.C) u32 = undefined;
pub fn xcbGenerateId(connection: *Connection) u32 {
    return xcb_generate_id(connection);
}

pub const XCB_WINDOW_CLASS_COPY_FROM_PARENT = 0;
pub const XCB_WINDOW_CLASS_INPUT_OUTPUT = 1;
pub const XCB_WINDOW_CLASS_INPUT_ONLY = 2;

pub const XCB_CW_BACK_PIXMAP = 1;
pub const XCB_CW_BACK_PIXEL = 2;
pub const XCB_CW_BORDER_PIXMAP = 4;
pub const XCB_CW_BORDER_PIXEL = 8;
pub const XCB_CW_BIT_GRAVITY = 16;
pub const XCB_CW_WIN_GRAVITY = 32;
pub const XCB_CW_BACKING_STORE = 64;
pub const XCB_CW_BACKING_PLANES = 128;
pub const XCB_CW_BACKING_PIXEL = 256;
pub const XCB_CW_OVERRIDE_REDIRECT = 512;
pub const XCB_CW_SAVE_UNDER = 1024;
pub const XCB_CW_EVENT_MASK = 2048;
pub const XCB_CW_DONT_PROPAGATE = 4096;
pub const XCB_CW_COLORMAP = 8192;
pub const XCB_CW_CURSOR = 16384;

pub const XCB_EVENT_MASK_NO_EVENT = 0;
pub const XCB_EVENT_MASK_KEY_PRESS = 1;
pub const XCB_EVENT_MASK_KEY_RELEASE = 2;
pub const XCB_EVENT_MASK_BUTTON_PRESS = 4;
pub const XCB_EVENT_MASK_BUTTON_RELEASE = 8;
pub const XCB_EVENT_MASK_ENTER_WINDOW = 16;
pub const XCB_EVENT_MASK_LEAVE_WINDOW = 32;
pub const XCB_EVENT_MASK_POINTER_MOTION = 64;
pub const XCB_EVENT_MASK_POINTER_MOTION_HINT = 128;
pub const XCB_EVENT_MASK_BUTTON_1_MOTION = 256;
pub const XCB_EVENT_MASK_BUTTON_2_MOTION = 512;
pub const XCB_EVENT_MASK_BUTTON_3_MOTION = 1024;
pub const XCB_EVENT_MASK_BUTTON_4_MOTION = 2048;
pub const XCB_EVENT_MASK_BUTTON_5_MOTION = 4096;
pub const XCB_EVENT_MASK_BUTTON_MOTION = 8192;
pub const XCB_EVENT_MASK_KEYMAP_STATE = 16384;
pub const XCB_EVENT_MASK_EXPOSURE = 32768;
pub const XCB_EVENT_MASK_VISIBILITY_CHANGE = 65536;
pub const XCB_EVENT_MASK_STRUCTURE_NOTIFY = 131072;
pub const XCB_EVENT_MASK_RESIZE_REDIRECT = 262144;
pub const XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY = 524288;
pub const XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT = 1048576;
pub const XCB_EVENT_MASK_FOCUS_CHANGE = 2097152;
pub const XCB_EVENT_MASK_PROPERTY_CHANGE = 4194304;
pub const XCB_EVENT_MASK_COLOR_MAP_CHANGE = 8388608;
pub const XCB_EVENT_MASK_OWNER_GRAB_BUTTON = 16777216;

var xcb_create_window: fn (*Connection, u8, WINDOW, WINDOW, i16, i16, u16, u16, u16, u16, VISUALID, u32, ?[*]const u32) callconv(.C) VoidCookie = undefined;
pub fn xcbCreateWindow(connection: *Connection, depth: u8, wid: WINDOW, parent: WINDOW, x: i16, y: i16, width: u16, height: u16, border_width: u16, class: u16, visual: VISUALID, value_mask: u32, value_list: ?[*]const u32) VoidCookie {
    return xcb_create_window(connection, depth, wid, parent, x, y, width, height, border_width, class, visual, value_mask, value_list);
}

var xcb_destroy_window: fn (*Connection, WINDOW) callconv(.C) VoidCookie = undefined;
pub fn xcbDestroyWindow(connection: *Connection, window: WINDOW) VoidCookie {
    return xcb_destroy_window(connection, window);
}

var xcb_flush: fn (*Connection) callconv(.C) c_int = undefined;
pub fn xcbFlush(connection: *Connection) !void {
    if (xcb_flush(connection) > 0)
        return;
    try xcbConnectionHasError(connection);
}

var xcb_map_window: fn (*Connection, WINDOW) callconv(.C) VoidCookie = undefined;
pub fn xcbMapWindow(connection: *Connection, window: WINDOW) VoidCookie {
    return xcb_map_window(connection, window);
}

var xcb_unmap_window: fn (*Connection, WINDOW) callconv(.C) VoidCookie = undefined;
pub fn xcbUnapWindow(connection: *Connection, window: WINDOW) VoidCookie {
    return xcb_unmap_window(connection, window);
}

var xcb_create_colormap: fn (*Connection, u8, COLORMAP, WINDOW, VISUALID) callconv(.C) VoidCookie = undefined;
pub fn xcbCreateColormap(connection: *Connection, alloc: u8, mid: COLORMAP, window: WINDOW, visual: VISUALID) VoidCookie {
    return xcb_create_colormap(connection, alloc, mid, window, visual);
}

var xcb_free_colormap: fn (*Connection, COLORMAP) callconv(.C) VoidCookie = undefined;
pub fn xcbFreeColormap(connection: *Connection, cmap: COLORMAP) VoidCookie {
    return xcb_free_colormap(connection, cmap);
}

pub const XCB_PROP_MODE_REPLACE = 0;
pub const XCB_PROP_MODE_PREPEND = 1;
pub const XCB_PROP_MODE_APPEND = 2;

var xcb_change_property: fn (*Connection, u8, WINDOW, ATOM, ATOM, u8, u32, *const c_void) callconv(.C) VoidCookie = undefined;
pub fn xcbChangeProperty(connection: *Connection, mode: u8, window: WINDOW, property: ATOM, property_type: ATOM, format: u8, data_len: u32, data: *const c_void) VoidCookie {
    return xcb_change_property(connection, mode, window, property, property_type, format, data_len, data);
}

pub const GenericEvent = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    pad1: [7]u32,
    full_sequence: u32,
};

pub const XCB_EXPOSE = 12;
pub const ExposeEvent = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    window: WINDOW,
    x: u16,
    y: u16,
    width: u16,
    height: u16,
    count: u16,
    pad1: [2]u8,
};

pub const XCB_DESTROY_NOTIFY = 17;
pub const DestroyNotifyEvent = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    event: WINDOW,
    window: WINDOW,
};

pub const XCB_CONFIGURE_NOTIFY = 22;
pub const ConfigureNotifyEvent = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    event: WINDOW,
    window: WINDOW,
    above_sibling: WINDOW,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    border_width: u16,
    override_redirect: u8,
    pad1: u8,
};

var xcb_poll_for_event: fn (*Connection) callconv(.C) ?*GenericEvent = undefined;
pub fn xcbPollForEvent(connection: *Connection) !?*GenericEvent {
    const ret = xcb_poll_for_event(connection);
    if (ret) |r| return r;

    const err = xcb_connection_has_error(connection);
    return switch (err) {
        0 => null,
        XCB_CONN_ERROR => error.ConnectionClosed,
        XCB_CONN_CLOSED_EXT_NOTSUPPORTED => error.NotSupported,
        XCB_CONN_CLOSED_MEM_INSUFFICIENT => error.OutOfMemory,
        XCB_CONN_CLOSED_REQ_LEN_EXCEED => error.LengthExceeded,
        XCB_CONN_CLOSED_PARSE_ERR => error.ParseError,
        XCB_CONN_CLOSED_INVALID_SCREEN => error.InvalidScreen,
        XCB_CONN_CLOSED_FDPASSING_FAILED => error.FdPassingFailed,
        else => unreachable,
    };
}

var xcb_wait_for_event: fn (*Connection) callconv(.C) ?*GenericEvent = undefined;
pub fn xcbWaitForEvent(connection: *Connection) !*GenericEvent {
    const ret = xcb_wait_for_event(connection);
    if (ret) |r| return r;

    const err = xcb_connection_has_error(connection);
    return switch (err) {
        XCB_CONN_ERROR => error.ConnectionClosed,
        XCB_CONN_CLOSED_EXT_NOTSUPPORTED => error.NotSupported,
        XCB_CONN_CLOSED_MEM_INSUFFICIENT => error.OutOfMemory,
        XCB_CONN_CLOSED_REQ_LEN_EXCEED => error.LengthExceeded,
        XCB_CONN_CLOSED_PARSE_ERR => error.ParseError,
        XCB_CONN_CLOSED_INVALID_SCREEN => error.InvalidScreen,
        XCB_CONN_CLOSED_FDPASSING_FAILED => error.FdPassingFailed,
        else => unreachable,
    };
}
