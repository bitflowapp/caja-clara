#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr unsigned int kInitialWindowWidth = 1440;
constexpr unsigned int kInitialWindowHeight = 900;

Win32Window::Point CenterWindowOrigin(unsigned int width, unsigned int height) {
  RECT work_area{};
  SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);

  const int available_width = work_area.right - work_area.left;
  const int available_height = work_area.bottom - work_area.top;
  int x = work_area.left + ((available_width - static_cast<int>(width)) / 2);
  int y = work_area.top + ((available_height - static_cast<int>(height)) / 2);
  if (x < 0) {
    x = 0;
  }
  if (y < 0) {
    y = 0;
  }

  return Win32Window::Point(static_cast<unsigned int>(x),
                            static_cast<unsigned int>(y));
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Size size(kInitialWindowWidth, kInitialWindowHeight);
  Win32Window::Point origin =
      CenterWindowOrigin(kInitialWindowWidth, kInitialWindowHeight);
  if (!window.Create(L"Caja Clara", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
