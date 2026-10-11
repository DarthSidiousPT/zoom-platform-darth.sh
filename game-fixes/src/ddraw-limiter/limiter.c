/*
 * e-Racer 60 FPS limiter: a ddraw.dll proxy that forwards to the real (Wine builtin) ddraw and
 * waits before each Flip so the game never presents faster than 60 times a second (or what
 * ddraw-darth.ini next to this DLL says).
 *
 * Copyright (c) 2026 DarthSidiousPT, https://github.com/DarthSidiousPT/zoom-platform-darth.sh
 * BSD 3-Clause License, see the LICENSE file in this folder (LICENSE-ddraw-limiter.txt in the zip).
 */
#define WIN32_LEAN_AND_MEAN
#define INITGUID
#include <windows.h>
#include <string.h>
#include <mmsystem.h>
#include <ddraw.h>

static const char CREDIT[] =
    "e-Racer 60 FPS limiter, Copyright (c) 2026 DarthSidiousPT, "
    "https://github.com/DarthSidiousPT/zoom-platform-darth.sh";

#define DEFAULT_FPS 60
#define MAX_FPS 1000
#define N_VER 5 /* IDirectDrawSurface, 2, 3, 4, 7 */
#define FLIP_SLOT 11
#define CREATESURFACE_SLOT 6

typedef HRESULT (WINAPI *flip_fn)(void *self, void *target, DWORD flags);

static HMODULE g_real;
static LARGE_INTEGER g_freq, g_next;
static int g_timing;
static int g_fps = DEFAULT_FPS;   /* 0 = no cap */
static int g_vsync = 1;           /* 0 = every Flip gets DDFLIP_NOVSYNC */
static flip_fn g_orig_flip[N_VER];
static void **g_flip_slot[N_VER]; /* where each version's Flip pointer lives, NULL = not patched */

static const GUID *const SURFACE_IIDS[N_VER] = {
    &IID_IDirectDrawSurface, &IID_IDirectDrawSurface2, &IID_IDirectDrawSurface3,
    &IID_IDirectDrawSurface4, &IID_IDirectDrawSurface7,
};

/* Sleeps until the next frame is due. The schedule is kept from one Flip to the next; a frame
 * that ran late restarts it instead of being "caught up" with a burst. */
static void wait_for_frame(void)
{
    LARGE_INTEGER now;
    LONGLONG step, left;

    if (g_fps <= 0) return;
    step = g_freq.QuadPart / g_fps;
    QueryPerformanceCounter(&now);
    if (!g_timing || now.QuadPart - g_next.QuadPart > step) {
        g_timing = 1;
        g_next.QuadPart = now.QuadPart + step;
        return;
    }
    for (;;) {
        left = g_next.QuadPart - now.QuadPart;
        if (left <= 0) break;
        if (left * 1000 / g_freq.QuadPart >= 2) Sleep(1); /* spin the last 2 ms */
        QueryPerformanceCounter(&now);
    }
    g_next.QuadPart += step;
}

/* Wine's v1 to v3 Flip ignores its flags and always waits for vsync, so with vsync off the
 * call goes straight to the v7 Flip (the same surface) with DDFLIP_NOVSYNC. */
static HRESULT do_flip(int i, void *self, void *target, DWORD flags)
{
    IUnknown *s7 = NULL;
    HRESULT hr;

    wait_for_frame();
    if (g_vsync) return g_orig_flip[i](self, target, flags);
    flags |= DDFLIP_NOVSYNC;
    if (i == N_VER - 1) return g_orig_flip[i](self, target, flags);
    if (target || FAILED(((IUnknown *)self)->lpVtbl->QueryInterface((IUnknown *)self, &IID_IDirectDrawSurface7, (void **)&s7)) || !s7)
        return g_orig_flip[i](self, target, flags);
    hr = g_orig_flip[N_VER - 1](s7, NULL, flags | DDFLIP_WAIT);
    s7->lpVtbl->Release(s7);
    return hr;
}

#define FLIP_HOOK(i) \
    static HRESULT WINAPI flip_hook##i(void *self, void *target, DWORD flags) \
    { return do_flip(i, self, target, flags); }
FLIP_HOOK(0) FLIP_HOOK(1) FLIP_HOOK(2) FLIP_HOOK(3) FLIP_HOOK(4)
static const flip_fn FLIP_HOOKS[N_VER] = { flip_hook0, flip_hook1, flip_hook2, flip_hook3, flip_hook4 };

static void patch_slot(void **slot, void *fn)
{
    DWORD old;
    if (VirtualProtect(slot, sizeof(void *), PAGE_READWRITE, &old)) {
        *slot = fn;
        VirtualProtect(slot, sizeof(void *), old, &old);
    }
}

/* Wine keeps one vtable per interface version, so patching it once covers every surface. */
static void hook_surface_flips(IDirectDrawSurface7 *s7)
{
    int i;
    for (i = 0; i < N_VER; i++) {
        void *s = NULL;
        void **slot;
        if (g_flip_slot[i]) continue;
        if (FAILED(s7->lpVtbl->QueryInterface(s7, SURFACE_IIDS[i], &s)) || !s) continue;
        slot = &(*(void ***)s)[FLIP_SLOT];
        g_orig_flip[i] = (flip_fn)*slot;
        g_flip_slot[i] = slot;
        patch_slot(slot, (void *)FLIP_HOOKS[i]);
        ((IUnknown *)s)->lpVtbl->Release((IUnknown *)s);
    }
}

typedef HRESULT (WINAPI *create_surface_fn)(IDirectDraw7 *, LPDDSURFACEDESC2, LPDIRECTDRAWSURFACE7 *, IUnknown *);
static create_surface_fn g_orig_create_surface;

static HRESULT WINAPI create_surface_hook(IDirectDraw7 *self, LPDDSURFACEDESC2 desc,
                                          LPDIRECTDRAWSURFACE7 *out, IUnknown *outer)
{
    HRESULT hr = g_orig_create_surface(self, desc, out, outer);
    if (SUCCEEDED(hr) && out && *out && !g_flip_slot[0]) hook_surface_flips(*out);
    return hr;
}

static void hook_ddraw7(IDirectDraw7 *dd)
{
    void **slot = &((void **)dd->lpVtbl)[CREATESURFACE_SLOT];
    if (g_orig_create_surface) return;
    g_orig_create_surface = (create_surface_fn)*slot;
    patch_slot(slot, (void *)create_surface_hook);
}

static FARPROC real_proc(const char *name)
{
    char path[MAX_PATH + 16];
    if (!g_real) {
        UINT n = GetSystemDirectoryA(path, MAX_PATH);
        if (n == 0 || n >= MAX_PATH) return NULL;
        lstrcatA(path, "\\ddraw.dll");
        g_real = LoadLibraryA(path);
        if (!g_real) return NULL;
    }
    return GetProcAddress(g_real, name);
}

#define FORWARD(ret, name, params, args) \
    ret WINAPI my_##name params { \
        ret (WINAPI *fwd_) params = (void *)real_proc(#name); \
        return fwd_ ? fwd_ args : DDERR_GENERIC; }

HRESULT WINAPI my_DirectDrawCreateEx(GUID *guid, LPVOID *out, REFIID iid, IUnknown *outer)
{
    HRESULT (WINAPI *f)(GUID *, LPVOID *, REFIID, IUnknown *) = (void *)real_proc("DirectDrawCreateEx");
    HRESULT hr;
    if (!f) return DDERR_GENERIC;
    hr = f(guid, out, iid, outer);
    if (SUCCEEDED(hr) && out && *out && IsEqualIID(iid, &IID_IDirectDraw7)) hook_ddraw7((IDirectDraw7 *)*out);
    return hr;
}

FORWARD(HRESULT, DirectDrawCreate, (GUID *g, LPDIRECTDRAW *o, IUnknown *u), (g, o, u))
FORWARD(HRESULT, DirectDrawCreateClipper, (DWORD f, LPDIRECTDRAWCLIPPER *o, IUnknown *u), (f, o, u))
FORWARD(HRESULT, DirectDrawEnumerateA, (LPDDENUMCALLBACKA cb, LPVOID ctx), (cb, ctx))
FORWARD(HRESULT, DirectDrawEnumerateW, (LPDDENUMCALLBACKW cb, LPVOID ctx), (cb, ctx))
FORWARD(HRESULT, DirectDrawEnumerateExA, (LPDDENUMCALLBACKEXA cb, LPVOID ctx, DWORD f), (cb, ctx, f))
FORWARD(HRESULT, DirectDrawEnumerateExW, (LPDDENUMCALLBACKEXW cb, LPVOID ctx, DWORD f), (cb, ctx, f))
FORWARD(HRESULT, DllCanUnloadNow, (void), ())
FORWARD(HRESULT, DllGetClassObject, (REFCLSID c, REFIID i, LPVOID *o), (c, i, o))

/* A whole number from 0 to MAX_FPS, nothing else (the Windows integer reader turns text into 0,
 * which here would mean no cap). Returns -1 for anything that is not one. */
static int parse_fps(const char *t)
{
    int n = 0, digits = 0;
    while (*t == ' ' || *t == '\t') t++;
    for (; *t >= '0' && *t <= '9'; t++) {
        if (++digits > 4) return -1;
        n = n * 10 + (*t - '0');
    }
    while (*t == ' ' || *t == '\t') t++;
    return (digits && !*t && n <= MAX_FPS) ? n : -1;
}

/* ddraw-darth.ini, next to this DLL. A missing file or a bad value keeps the defaults (60, vsync on). */
static void load_settings(HINSTANCE inst)
{
    char path[MAX_PATH + 16], val[32], msg[96];
    DWORD n = GetModuleFileNameA(inst, path, MAX_PATH);
    char *slash;
    int fps;

    if (n != 0 && n < MAX_PATH && (slash = strrchr(path, '\\')) != NULL) {
        lstrcpyA(slash + 1, "ddraw-darth.ini");
        GetPrivateProfileStringA("limiter", "fps", "", val, sizeof(val), path);
        fps = parse_fps(val);
        if (fps >= 0) g_fps = fps;
        GetPrivateProfileStringA("limiter", "vsync", "on", val, sizeof(val), path);
        if (lstrcmpiA(val, "off") == 0 || lstrcmpiA(val, "no") == 0 || lstrcmpiA(val, "false") == 0) g_vsync = 0;
    }
    wsprintfA(msg, "ddraw limiter: fps=%d vsync=%s", g_fps, g_vsync ? "on" : "off");
    OutputDebugStringA(msg);
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved)
{
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        QueryPerformanceFrequency(&g_freq);
        load_settings(inst);
        timeBeginPeriod(1);
        OutputDebugStringA(CREDIT);
    } else if (reason == DLL_PROCESS_DETACH) {
        timeEndPeriod(1);
    }
    return TRUE;
}
