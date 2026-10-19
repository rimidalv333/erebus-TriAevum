/*
 * TriAevum for the PlayStation 5 - SDL2's video driver for the console.
 *
 * The console has one output and no windows: this gives SDL one display and
 * lets it keep its window bookkeeping (size, flags, events) for a window that
 * is the whole screen. Nothing is drawn through SDL. Its Vulkan calls answer
 * for the console: the "library" is RADV, linked into the title, and a window's
 * surface is VK_KHR_display's first display in its first mode.
 *
 * SDL_PS5_DISPLAY=WIDTHxHEIGHT in the environment sets the size (default
 * 1920x1080).
 *
 * Adapted for SDL2 from the SDL3 driver of PS5_WindWakerHD (Zlib licence).
 *
 * SPDX-License-Identifier: Zlib
 */
#include "SDL_internal.h"
#include <stdio.h>

#ifdef SDL_VIDEO_DRIVER_PS5

#include "video/SDL_sysvideo.h"
#include "events/SDL_events_c.h"
#include "events/SDL_keyboard_c.h"

/* the hidden "this" pointer of the video functions */
#ifndef _THIS
#define _THIS SDL_VideoDevice *_this
#endif

#ifdef SDL_VIDEO_VULKAN
#include "video/SDL_vulkan_internal.h"

/* RADV's entry point: there is no Vulkan loader, the driver is in the title */
extern PFN_vkVoidFunction vk_icdGetInstanceProcAddr(VkInstance instance, const char *name);

static int PS5_Vulkan_LoadLibrary(_THIS, const char *path)
{
    _this->vulkan_config.vkGetInstanceProcAddr = (PFN_vkGetInstanceProcAddr)vk_icdGetInstanceProcAddr;
    _this->vulkan_config.vkEnumerateInstanceExtensionProperties =
        (PFN_vkEnumerateInstanceExtensionProperties)vk_icdGetInstanceProcAddr(VK_NULL_HANDLE, "vkEnumerateInstanceExtensionProperties");
    if (!_this->vulkan_config.vkEnumerateInstanceExtensionProperties) {
        return SDL_SetError("RADV has no vkEnumerateInstanceExtensionProperties");
    }
    SDL_strlcpy(_this->vulkan_config.loader_path, "radv", SDL_arraysize(_this->vulkan_config.loader_path));
    _this->vulkan_config.loader_handle = (void *)vk_icdGetInstanceProcAddr; /* something non-NULL */
    return 0;
}

static void PS5_Vulkan_UnloadLibrary(_THIS)
{
    _this->vulkan_config.loader_handle = NULL;
}

static SDL_bool PS5_Vulkan_GetInstanceExtensions(_THIS, SDL_Window *window, unsigned *count, const char **names)
{
    static const char *const extensions[] = { VK_KHR_SURFACE_EXTENSION_NAME, VK_KHR_DISPLAY_EXTENSION_NAME };
    return SDL_Vulkan_GetInstanceExtensions_Helper(count, names, SDL_arraysize(extensions), extensions);
}

/* The first display of the first physical device, in its first mode, on a plane that can show it */
static SDL_bool PS5_Vulkan_CreateSurface(_THIS, SDL_Window *window, VkInstance instance, VkSurfaceKHR *surface)
{
    PFN_vkGetInstanceProcAddr getProc = _this->vulkan_config.vkGetInstanceProcAddr;
#define PS5_VK(name) PFN_##name name = (PFN_##name)getProc(instance, #name); \
    if (!name) { return SDL_SetError("RADV has no " #name); }
    PS5_VK(vkEnumeratePhysicalDevices)
    PS5_VK(vkGetPhysicalDeviceDisplayPropertiesKHR)
    PS5_VK(vkGetDisplayModePropertiesKHR)
    PS5_VK(vkGetPhysicalDeviceDisplayPlanePropertiesKHR)
    PS5_VK(vkGetDisplayPlaneSupportedDisplaysKHR)
    PS5_VK(vkCreateDisplayPlaneSurfaceKHR)
#undef PS5_VK
    VkPhysicalDevice gpus[8];
    uint32_t gpu_count = SDL_arraysize(gpus);
    VkResult result = vkEnumeratePhysicalDevices(instance, &gpu_count, gpus);
    if ((result != VK_SUCCESS && result != VK_INCOMPLETE) || gpu_count == 0) {
        return SDL_SetError("vkEnumeratePhysicalDevices found no GPU");
    }
    VkPhysicalDevice gpu = gpus[0];

    VkDisplayPropertiesKHR displays[4];
    uint32_t display_count = SDL_arraysize(displays);
    result = vkGetPhysicalDeviceDisplayPropertiesKHR(gpu, &display_count, displays);
    if ((result != VK_SUCCESS && result != VK_INCOMPLETE) || display_count == 0) {
        return SDL_SetError("the GPU has no display");
    }
    VkDisplayKHR display = displays[0].display;

    VkDisplayModePropertiesKHR modes[16];
    uint32_t mode_count = SDL_arraysize(modes);
    result = vkGetDisplayModePropertiesKHR(gpu, display, &mode_count, modes);
    if ((result != VK_SUCCESS && result != VK_INCOMPLETE) || mode_count == 0) {
        return SDL_SetError("the display has no mode");
    }
    /* The mode the window claims to be (1920x1080 unless SDL_PS5_DISPLAY says otherwise) when the
     * display has it; otherwise the first mode. The window's size then becomes the mode's, so the game's
     * layout and the swapchain agree (a 4K swapchain under a 1080p window puts the UI in a corner). */
    const VkDisplayModePropertiesKHR *mode = &modes[0];
    for (uint32_t i = 0; i < mode_count; i++) {
        fprintf(stderr, "[SDL] display mode %u: %ux%u @ %u mHz\n", i, modes[i].parameters.visibleRegion.width,
                modes[i].parameters.visibleRegion.height, modes[i].parameters.refreshRate);
    }
    const SDL_bool legacy = SDL_getenv("SDL_PS5_LEGACY_MODE") != NULL; /* first mode, window size untouched */
    for (uint32_t i = 0; i < mode_count && !legacy; i++) {
        if ((int)modes[i].parameters.visibleRegion.width == window->w &&
            (int)modes[i].parameters.visibleRegion.height == window->h) {
            mode = &modes[i];
            break;
        }
    }

    VkDisplayPlanePropertiesKHR planes[8];
    uint32_t plane_count = SDL_arraysize(planes);
    result = vkGetPhysicalDeviceDisplayPlanePropertiesKHR(gpu, &plane_count, planes);
    if ((result != VK_SUCCESS && result != VK_INCOMPLETE) || plane_count == 0) {
        return SDL_SetError("the GPU has no display plane");
    }
    uint32_t plane_index = plane_count;
    for (uint32_t i = 0; i < plane_count; i++) {
        VkDisplayKHR supported[8];
        uint32_t supported_count = SDL_arraysize(supported);
        if (vkGetDisplayPlaneSupportedDisplaysKHR(gpu, i, &supported_count, supported) != VK_SUCCESS) {
            continue;
        }
        for (uint32_t j = 0; j < supported_count; j++) {
            if (supported[j] == display) {
                plane_index = i;
                break;
            }
        }
        if (plane_index != plane_count) {
            break;
        }
    }
    if (plane_index == plane_count) {
        return SDL_SetError("no display plane can show the display");
    }

    VkDisplaySurfaceCreateInfoKHR info;
    SDL_zero(info);
    info.sType = VK_STRUCTURE_TYPE_DISPLAY_SURFACE_CREATE_INFO_KHR;
    info.displayMode = mode->displayMode;
    info.planeIndex = plane_index;
    info.planeStackIndex = planes[plane_index].currentStackIndex;
    info.transform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
    info.globalAlpha = 1.0f;
    info.alphaMode = VK_DISPLAY_PLANE_ALPHA_OPAQUE_BIT_KHR;
    info.imageExtent = mode->parameters.visibleRegion;
    result = vkCreateDisplayPlaneSurfaceKHR(instance, &info, NULL, surface);
    if (result != VK_SUCCESS) {
        return SDL_SetError("vkCreateDisplayPlaneSurfaceKHR failed: %d", (int)result);
    }
    fprintf(stderr, "[SDL] surface %ux%u (window was %dx%d)\n", info.imageExtent.width, info.imageExtent.height,
            window->w, window->h);
    if (!legacy) {
        window->w = (int)info.imageExtent.width;
        window->h = (int)info.imageExtent.height;
    }
    return SDL_TRUE;
}

static void PS5_Vulkan_GetDrawableSize(_THIS, SDL_Window *window, int *w, int *h)
{
    if (w) {
        *w = window->w;
    }
    if (h) {
        *h = window->h;
    }
}
#endif /* SDL_VIDEO_VULKAN */

static int PS5_VideoInit(_THIS)
{
    SDL_DisplayMode mode;
    int w = 1920, h = 1080;
    const char *size = SDL_getenv("SDL_PS5_DISPLAY");

    if (size && SDL_sscanf(size, "%dx%d", &w, &h) != 2) {
        w = 1920;
        h = 1080;
    }
    SDL_zero(mode);
    mode.format = SDL_PIXELFORMAT_XRGB8888;
    mode.w = w;
    mode.h = h;
    mode.refresh_rate = 60;
    return SDL_AddBasicVideoDisplay(&mode) < 0 ? -1 : 0;
}

static void PS5_VideoQuit(_THIS)
{
}

static void PS5_PumpEvents(_THIS)
{
}

static int PS5_CreateWindow(_THIS, SDL_Window *window)
{
    /* The window is the screen, and always has the pad's focus */
    SDL_SetKeyboardFocus(window);
    return 0;
}

static void PS5_SetWindowPosition(_THIS, SDL_Window *window)
{
}

static void PS5_SetWindowSize(_THIS, SDL_Window *window)
{
    /* The size stays the display's */
}

static void PS5_SetWindowFullscreen(_THIS, SDL_Window *window, SDL_VideoDisplay *display, SDL_bool fullscreen)
{
}

static void PS5_DeleteDevice(SDL_VideoDevice *device)
{
    SDL_free(device);
}

static SDL_VideoDevice *PS5_CreateDevice(void)
{
    SDL_VideoDevice *device = (SDL_VideoDevice *)SDL_calloc(1, sizeof(SDL_VideoDevice));
    if (!device) {
        SDL_OutOfMemory();
        return NULL;
    }
    device->VideoInit = PS5_VideoInit;
    device->VideoQuit = PS5_VideoQuit;
    device->PumpEvents = PS5_PumpEvents;
    device->CreateSDLWindow = PS5_CreateWindow;
    device->SetWindowPosition = PS5_SetWindowPosition;
    device->SetWindowSize = PS5_SetWindowSize;
    device->SetWindowFullscreen = PS5_SetWindowFullscreen;
#ifdef SDL_VIDEO_VULKAN
    device->Vulkan_LoadLibrary = PS5_Vulkan_LoadLibrary;
    device->Vulkan_UnloadLibrary = PS5_Vulkan_UnloadLibrary;
    device->Vulkan_GetInstanceExtensions = PS5_Vulkan_GetInstanceExtensions;
    device->Vulkan_CreateSurface = PS5_Vulkan_CreateSurface;
    device->Vulkan_GetDrawableSize = PS5_Vulkan_GetDrawableSize;
#endif
    device->free = PS5_DeleteDevice;
    return device;
}

VideoBootStrap PS5_bootstrap = {
    "ps5", "PlayStation 5 video driver", PS5_CreateDevice, NULL /* no ShowMessageBox implementation */
};

#endif /* SDL_VIDEO_DRIVER_PS5 */
