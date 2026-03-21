import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum SpeechDictationState { idle, starting, listening, error, unsupported }

class SpeechDictationController extends ChangeNotifier {
  SpeechDictationController({this.idleHint = 'Toca el microfono para dictar.'});

  final String idleHint;
  final SpeechToText _speech = SpeechToText();

  SpeechDictationState _state = SpeechDictationState.idle;
  bool _initialized = false;
  bool _disposed = false;
  String _message = '';
  String? _lastError;
  TextEditingValue? _sessionValue;

  SpeechDictationState get state => _state;

  bool get isSupported =>
      _initialized && _state != SpeechDictationState.unsupported;

  String get statusText {
    switch (_state) {
      case SpeechDictationState.idle:
        return _message.isEmpty ? idleHint : _message;
      case SpeechDictationState.starting:
        return 'Activando dictado...';
      case SpeechDictationState.listening:
        return 'Escuchando. Toca otra vez para detener.';
      case SpeechDictationState.error:
        return _lastError ?? 'No se pudo iniciar el dictado.';
      case SpeechDictationState.unsupported:
        return _lastError ??
            'Dictado no disponible en esta plataforma o navegador.';
    }
  }

  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }

    _state = SpeechDictationState.starting;
    _message = 'Comprobando dictado...';
    _safeNotify();

    try {
      final available = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
      );
      if (_disposed) {
        return;
      }
      _initialized = true;
      if (!available) {
        _state = SpeechDictationState.unsupported;
        _lastError = 'Dictado no disponible en este dispositivo.';
        _message = _lastError!;
      } else {
        _state = SpeechDictationState.idle;
        _message = idleHint;
      }
    } catch (error) {
      if (_disposed) {
        return;
      }
      _initialized = true;
      _state = SpeechDictationState.unsupported;
      _lastError = 'Dictado no disponible: $error';
      _message = _lastError!;
    } finally {
      _safeNotify();
    }
  }

  Future<void> toggle(TextEditingController controller) async {
    if (_disposed) {
      return;
    }

    await initialize();
    if (!isSupported || _disposed) {
      return;
    }

    if (_state == SpeechDictationState.starting) {
      return;
    }

    if (_speech.isListening || _state == SpeechDictationState.listening) {
      await _speech.stop();
      if (_disposed) {
        return;
      }
      _state = SpeechDictationState.idle;
      _message = 'Dictado detenido.';
      _safeNotify();
      return;
    }

    _sessionValue = controller.value;
    _state = SpeechDictationState.starting;
    _message = 'Iniciando dictado...';
    _safeNotify();

    try {
      await _speech.listen(
        onResult: (result) {
          if (_disposed) {
            return;
          }
          _applyResult(controller, result.recognizedWords);
          if (result.finalResult) {
            _state = SpeechDictationState.idle;
            _message = idleHint;
            _safeNotify();
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
      if (_disposed) {
        return;
      }
      _state = SpeechDictationState.listening;
      _message = 'Escuchando. Toca el microfono para parar.';
      _safeNotify();
    } catch (error) {
      if (_disposed) {
        return;
      }
      _state = SpeechDictationState.error;
      _lastError = 'No se pudo iniciar el dictado: $error';
      _message = _lastError!;
      _safeNotify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_speech.isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  void _handleStatus(String status) {
    if (_disposed) {
      return;
    }

    if (status == 'listening') {
      _state = SpeechDictationState.listening;
      _message = 'Escuchando. Toca el microfono para parar.';
      _safeNotify();
      return;
    }

    if (status == 'notListening' || status == 'done' || status == 'stopped') {
      if (_state != SpeechDictationState.unsupported) {
        _state = SpeechDictationState.idle;
        _message = idleHint;
        _safeNotify();
      }
    }
  }

  void _handleError(SpeechRecognitionError error) {
    if (_disposed) {
      return;
    }

    if (error.permanent) {
      _state = SpeechDictationState.unsupported;
      _lastError = error.errorMsg;
    } else {
      _state = SpeechDictationState.error;
      _lastError = error.errorMsg;
    }
    _message = _lastError ?? idleHint;
    _safeNotify();
  }

  void _applyResult(TextEditingController controller, String transcript) {
    final baseValue = _sessionValue;
    if (baseValue == null) {
      return;
    }

    final normalizedTranscript = transcript.trim();
    if (normalizedTranscript.isEmpty) {
      return;
    }

    controller.value = _mergeTranscription(baseValue, normalizedTranscript);
  }

  TextEditingValue _mergeTranscription(
    TextEditingValue baseValue,
    String transcript,
  ) {
    final text = baseValue.text;
    final selection = baseValue.selection;

    if (selection.isValid && !selection.isCollapsed) {
      final before = text.substring(0, selection.start);
      final after = text.substring(selection.end);
      final merged = _joinTextSegments(before, transcript, after);
      return TextEditingValue(
        text: merged,
        selection: TextSelection.collapsed(
          offset: _selectionOffset(before, transcript),
        ),
      );
    }

    final cursor = selection.isValid
        ? selection.baseOffset.clamp(0, text.length).toInt()
        : text.length;
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final merged = _joinTextSegments(before, transcript, after);
    return TextEditingValue(
      text: merged,
      selection: TextSelection.collapsed(
        offset: _selectionOffset(before, transcript),
      ),
    );
  }

  int _selectionOffset(String before, String transcript) {
    if (before.isEmpty) {
      return transcript.length;
    }
    return before.length +
        (_endsWithWhitespace(before) ? 0 : 1) +
        transcript.length;
  }

  String _joinTextSegments(String before, String transcript, String after) {
    final buffer = StringBuffer();
    buffer.write(before);
    if (before.isNotEmpty &&
        !_endsWithWhitespace(before) &&
        transcript.isNotEmpty) {
      buffer.write(' ');
    }
    buffer.write(transcript);
    if (after.isNotEmpty) {
      if (!_endsWithWhitespace(transcript) && !_startsWithWhitespace(after)) {
        buffer.write(' ');
      }
      buffer.write(after);
    }
    return buffer.toString();
  }

  bool _endsWithWhitespace(String value) {
    if (value.isEmpty) {
      return false;
    }
    return RegExp(r'\s').hasMatch(value[value.length - 1]);
  }

  bool _startsWithWhitespace(String value) {
    if (value.isEmpty) {
      return false;
    }
    return RegExp(r'\s').hasMatch(value[0]);
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

class SpeechDictationActionButton extends StatelessWidget {
  const SpeechDictationActionButton({
    super.key,
    required this.controller,
    required this.textController,
    this.tooltip = 'Dictar',
  });

  final SpeechDictationController controller;
  final TextEditingController textController;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final state = controller.state;
        final icon = switch (state) {
          SpeechDictationState.starting => SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          SpeechDictationState.listening => const Icon(Icons.mic_rounded),
          SpeechDictationState.error => const Icon(Icons.mic_off_rounded),
          SpeechDictationState.unsupported => const Icon(Icons.mic_off_rounded),
          SpeechDictationState.idle => const Icon(Icons.mic_none_rounded),
        };

        final color = switch (state) {
          SpeechDictationState.listening => scheme.primary,
          SpeechDictationState.starting => scheme.tertiary,
          SpeechDictationState.error => scheme.error,
          SpeechDictationState.unsupported => scheme.outline,
          SpeechDictationState.idle => scheme.outline,
        };

        return IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: '$tooltip: ${controller.statusText}',
          onPressed: switch (state) {
            SpeechDictationState.starting => null,
            SpeechDictationState.unsupported => null,
            SpeechDictationState.listening => () => controller.toggle(
              textController,
            ),
            SpeechDictationState.error => () => controller.toggle(
              textController,
            ),
            SpeechDictationState.idle => () => controller.toggle(
              textController,
            ),
          },
          icon: IconTheme.merge(
            data: IconThemeData(color: color),
            child: icon,
          ),
        );
      },
    );
  }
}

class SpeechDictationHint extends StatelessWidget {
  const SpeechDictationHint({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.only(top: 4),
  });

  final SpeechDictationController controller;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final state = controller.state;
        final color = switch (state) {
          SpeechDictationState.listening => scheme.primary,
          SpeechDictationState.starting => scheme.tertiary,
          SpeechDictationState.error => scheme.error,
          SpeechDictationState.unsupported => scheme.outline,
          SpeechDictationState.idle => scheme.outline,
        };

        return Padding(
          padding: padding,
          child: Text(
            controller.statusText,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        );
      },
    );
  }
}
