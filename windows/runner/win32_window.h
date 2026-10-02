#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

// A class abstraction for a high DPI-aware Win32 Window. Intended to be
// inherited from by classes that wish to specialize with custom
// rendering and input handling.
class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // Creates a win32 window with |title| that is positioned and sized using
  // |origin| and |size|. New windows are created on the default monitor. Window
  // sizes are specified to the OS in physical pixels, hence to ensure a
  // consistent size you should use the ScaleFactor to scale the values provided.
  bool Create(const std::wstring& title, const Point& origin, const Size& size);

  // Shows the Win32Window.
  bool Show();

  // Called when the window is created.
  virtual bool OnCreate();

  // Called when the window is destroyed.
  virtual void OnDestroy();

  // Retrieves a handle to the Win32Window's parent window.
  HWND GetHandle();

  // Registers with |content| as the child window that hosts the Flutter view.
  void SetChildContent(HWND content);

  // The window procedure.
  virtual LRESULT MessageHandler(HWND hwnd, UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // The client area of the window, in physical pixels.
  RECT GetClientArea();

  // Whether the window is being destroyed.
  bool IsBeingDestroyed();

  // Sets whether the window should quit the app when closed.
  void SetQuitOnClose(bool quit_on_close);

  // Provides the Win32 window's callback function to create the window.
  static LRESULT CALLBACK WndProc(HWND const window, UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

 private:
  // Retrieves a Win32Window* from a window handle's user data.
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  // Destroys the window and, if it is the last window, unregisters the class.
  void Destroy();

  // Applies the current Windows theme (light/dark) to the window frame.
  void UpdateTheme(HWND const window);

  // The window handle.
  HWND window_handle_ = nullptr;

  // The child window that hosts the Flutter view.
  HWND child_content_ = nullptr;

  // Whether the window should quit the app when closed.
  bool quit_on_close_ = false;

  // Disable copy and assignment of Win32Window objects.
  Win32Window(const Win32Window&) = delete;
  Win32Window& operator=(const Win32Window&) = delete;
};

#endif  // RUNNER_WIN32_WINDOW_H_
