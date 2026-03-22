import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SaveShortcutIntent extends Intent {
  const SaveShortcutIntent();
}

class CancelShortcutIntent extends Intent {
  const CancelShortcutIntent();
}

class SearchShortcutIntent extends Intent {
  const SearchShortcutIntent();
}

class InputShortcutScope extends StatelessWidget {
  const InputShortcutScope({
    super.key,
    required this.child,
    this.onSave,
    this.onCancel,
    this.onFocusSearch,
  });

  final Widget child;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onFocusSearch;

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{
      if (onCancel != null)
        const SingleActivator(LogicalKeyboardKey.escape):
            const CancelShortcutIntent(),
      if (onSave != null) ...{
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const SaveShortcutIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            const SaveShortcutIntent(),
      },
      if (onFocusSearch != null) ...{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const SearchShortcutIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            const SearchShortcutIntent(),
      },
    };

    if (shortcuts.isEmpty) {
      return child;
    }

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          if (onCancel != null)
            CancelShortcutIntent: CallbackAction<CancelShortcutIntent>(
              onInvoke: (_) {
                onCancel!.call();
                return null;
              },
            ),
          if (onSave != null)
            SaveShortcutIntent: CallbackAction<SaveShortcutIntent>(
              onInvoke: (_) {
                onSave!.call();
                return null;
              },
            ),
          if (onFocusSearch != null)
            SearchShortcutIntent: CallbackAction<SearchShortcutIntent>(
              onInvoke: (_) {
                onFocusSearch!.call();
                return null;
              },
            ),
        },
        child: child,
      ),
    );
  }
}
