import sublime_plugin


_sidebar_focused_windows = set()


class AiFirstToggleSidebarFocusCommand(sublime_plugin.WindowCommand):
    def run(self):
        window_id = self.window.id()
        if window_id in _sidebar_focused_windows:
            self.window.focus_group(self.window.active_group())
            _sidebar_focused_windows.discard(window_id)
            return

        self.window.run_command("focus_side_bar")
        _sidebar_focused_windows.add(window_id)


class AiFirstSidebarFocusListener(sublime_plugin.EventListener):
    def on_activated_async(self, view):
        window = view.window()
        if window:
            _sidebar_focused_windows.discard(window.id())
