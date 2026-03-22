import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum SpeechDictationState {
  idle,
  starting,
  listening,
  processing,
  error,
  unsupported,
}

class SpeechDictationController extends ChangeNotifier {
  SpeechDictationController({this.idleHint = 'Toca el microfono para dictar.'});

  final String idleHint;
  final SpeechToText _speech = SpeechToText();

  SpeechDictationState _state = SpeechDictationState.idle;
  bool _initialized = false;
  bool _disposed = false;
  String _message = '';
  String? _lastError;
  String? _previewText;
  TextEditingValue? _sessionValue;
  bool _recognizedSpeechInSession = false;
  bool _stopRequested = false;

  SpeechDictationState get state => _state;
  bool get isListening => _state == SpeechDictationState.listening;
  String? get previewText =>
      _previewText == null || _previewText!.trim().isEmpty
      ? null
      : _previewText;

  bool get isSupported =>
      _initialized && _state != SpeechDictationState.unsupported;

  String get statusText {
    switch (_state) {
      case SpeechDictationState.idle:
        return _message.isEmpty ? idleHint : _message;
      case SpeechDictationState.starting:
        return 'Activando microfono...';
      case SpeechDictationState.listening:
        return 'Escuchando... Habla ahora.';
      case SpeechDictationState.processing:
        return 'Procesando dictado...';
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
        _lastError = 'El dictado no esta disponible en este dispositivo.';
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
      _lastError = _friendlyErrorMessage(error.toString(), unsupported: true);
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
      _stopRequested = true;
      _state = SpeechDictationState.processing;
      _message = 'Procesando dictado...';
      _safeNotify();
      await _speech.stop();
      return;
    }

    _sessionValue = controller.value;
    _previewText = null;
    _recognizedSpeechInSession = false;
    _stopRequested = false;
    _lastError = null;
    _state = SpeechDictationState.starting;
    _message = 'Activando microfono...';
    _safeNotify();

    try {
      await _speech.listen(
        onResult: (result) {
          if (_disposed) {
            return;
          }
          _applyResult(controller, result.recognizedWords);
          if (result.finalResult) {
            _finishSession();
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
      _message = 'Escuchando... Habla ahora.';
      _safeNotify();
    } catch (error) {
      if (_disposed) {
        return;
      }
      _state = SpeechDictationState.error;
      _lastError = _friendlyErrorMessage(error.toString());
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
      _message = 'Escuchando... Habla ahora.';
      _safeNotify();
      return;
    }

    if (status == 'notListening' || status == 'done' || status == 'stopped') {
      if (_state == SpeechDictationState.listening ||
          _state == SpeechDictationState.processing ||
          _state == SpeechDictationState.starting) {
        _finishSession();
      }
    }
  }

  void _handleError(SpeechRecognitionError error) {
    if (_disposed) {
      return;
    }

    final message = _friendlyErrorMessage(
      error.errorMsg,
      unsupported: error.permanent,
    );
    if (error.permanent) {
      _state = SpeechDictationState.unsupported;
    } else {
      _state = SpeechDictationState.error;
    }
    _lastError = message;
    _message = _lastError ?? idleHint;
    _previewText = null;
    _recognizedSpeechInSession = false;
    _stopRequested = false;
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

    _recognizedSpeechInSession = true;
    _previewText = normalizedTranscript;
    controller.value = _mergeTranscription(baseValue, normalizedTranscript);
    _message = 'Escuchando...';
    _safeNotify();
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

  void _finishSession() {
    if (_disposed || _state == SpeechDictationState.unsupported) {
      return;
    }

    final endedWhileCapturing =
        _state == SpeechDictationState.listening ||
        _state == SpeechDictationState.processing;
    _state = SpeechDictationState.idle;
    if (_recognizedSpeechInSession) {
      _message = 'Texto agregado al campo.';
    } else if (_stopRequested || endedWhileCapturing) {
      _message = 'No detecte voz. Prueba hablar mas cerca o revisar permisos.';
    } else {
      _message = idleHint;
    }
    _previewText = null;
    _sessionValue = null;
    _recognizedSpeechInSession = false;
    _stopRequested = false;
    _safeNotify();
  }

  String _friendlyErrorMessage(String raw, {bool unsupported = false}) {
    final message = raw.trim().toLowerCase();

    if (message.contains('permission') ||
        message.contains('not allowed') ||
        message.contains('denied') ||
        message.contains('permanently_denied')) {
      return 'El microfono no tiene permiso. Revisa permisos del navegador o del sistema.';
    }

    if (message.contains('no match') ||
        message.contains('no_speech') ||
        message.contains('speech timeout') ||
        message.contains('error_speech_timeout')) {
      return 'No detecte voz. Prueba hablar mas cerca o revisar el microfono.';
    }

    if (message.contains('busy') || message.contains('recognizerbusy')) {
      return 'El microfono esta en uso. Cierra otra captura y prueba de nuevo.';
    }

    if (message.contains('network') || message.contains('connection')) {
      return 'No pude usar el dictado ahora. Revisa la conexion e intenta de nuevo.';
    }

    if (unsupported ||
        message.contains('unsupported') ||
        message.contains('not available') ||
        message.contains('not supported')) {
      return 'El dictado no esta disponible en esta plataforma o navegador.';
    }

    return 'No se pudo iniciar el dictado. Intenta otra vez.';
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
          SpeechDictationState.listening => const Icon(Icons.stop_rounded),
          SpeechDictationState.processing => SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          SpeechDictationState.error => const Icon(Icons.mic_off_rounded),
          SpeechDictationState.unsupported => const Icon(Icons.mic_off_rounded),
          SpeechDictationState.idle => const Icon(Icons.mic_none_rounded),
        };

        final color = switch (state) {
          SpeechDictationState.listening => scheme.primary,
          SpeechDictationState.starting => scheme.tertiary,
          SpeechDictationState.processing => scheme.primary,
          SpeechDictationState.error => scheme.error,
          SpeechDictationState.unsupported => scheme.outline,
          SpeechDictationState.idle => scheme.outline,
        };

        return Stack(
          alignment: Alignment.center,
          children: [
            if (state == SpeechDictationState.listening)
              _SpeechPulse(color: color),
            Container(
              decoration: BoxDecoration(
                color: state == SpeechDictationState.listening
                    ? color.withValues(alpha: 0.14)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '$tooltip: ${controller.statusText}',
                onPressed: switch (state) {
                  SpeechDictationState.starting => null,
                  SpeechDictationState.processing => null,
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
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpeechPulse extends StatefulWidget {
  const _SpeechPulse({required this.color});

  final Color color;

  @override
  State<_SpeechPulse> createState() => _SpeechPulseState();
}

class _SpeechPulseState extends State<_SpeechPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.18, end: 0.04).animate(_controller),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.18).animate(_controller),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.18),
          ),
        ),
      ),
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
          SpeechDictationState.processing => scheme.primary,
          SpeechDictationState.error => scheme.error,
          SpeechDictationState.unsupported => scheme.outline,
          SpeechDictationState.idle => scheme.outline,
        };
        final preview = controller.previewText;
        final emphasized =
            state != SpeechDictationState.idle || preview != null;
        final icon = switch (state) {
          SpeechDictationState.listening => Icons.graphic_eq_rounded,
          SpeechDictationState.starting => Icons.mic_none_rounded,
          SpeechDictationState.processing => Icons.more_horiz_rounded,
          SpeechDictationState.error => Icons.info_outline_rounded,
          SpeechDictationState.unsupported => Icons.mic_off_rounded,
          SpeechDictationState.idle => Icons.keyboard_voice_outlined,
        };

        if (!emphasized) {
          return Padding(
            padding: padding,
            child: Text(
              controller.statusText,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          );
        }

        return Padding(
          padding: padding,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.statusText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (preview != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Reconocido: $preview',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
