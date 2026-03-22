import 'package:flutter/widgets.dart';

void selectAllTextOnFocus(
  FocusNode focusNode,
  TextEditingController controller,
) {
  focusNode.addListener(() {
    if (!focusNode.hasFocus || controller.text.isEmpty) {
      return;
    }
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  });
}

void focusAndSelectAll(FocusNode focusNode, TextEditingController controller) {
  focusNode.requestFocus();
  if (controller.text.isEmpty) {
    return;
  }
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );
}
