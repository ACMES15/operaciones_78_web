import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExcelTable extends StatefulWidget {
  final List<String> columns;
  final List<List<String>> data;
  final void Function(int row, int col, String value) onChanged;
  const ExcelTable(
      {super.key,
      required this.columns,
      required this.data,
      required this.onChanged});

  @override
  State<ExcelTable> createState() => _ExcelTableState();
}

class _ExcelTableState extends State<ExcelTable> {
  late List<List<TextEditingController>> controllers;
  late List<List<FocusNode>> focusNodes;
  int? _activeRow;
  int? _activeCol;

  @override
  void initState() {
    super.initState();
    _initControllersAndFocusNodes();
  }

  @override
  void didUpdateWidget(covariant ExcelTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.length != controllers.length) {
      _initControllersAndFocusNodes();
    }
  }

  void _initControllersAndFocusNodes() {
    controllers = List.generate(
        widget.data.length,
        (i) => List.generate(widget.columns.length,
            (j) => TextEditingController(text: widget.data[i][j])));
    focusNodes = List.generate(widget.data.length,
        (i) => List.generate(widget.columns.length, (j) => FocusNode()));
  }

  @override
  void dispose() {
    for (var row in focusNodes) {
      for (var node in row) {
        node.dispose();
      }
    }
    for (var row in controllers) {
      for (var ctrl in row) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  void _handleKey(FocusNode node, RawKeyEvent event, int row, int col) {
    if (event is RawKeyDownEvent) {
      final isShift = event.isShiftPressed;
      final isCtrl = event.isControlPressed;
      if (event.logicalKey == LogicalKeyboardKey.tab && !isShift && !isCtrl) {
        if (col < widget.columns.length - 1) {
          focusNodes[row][col + 1].requestFocus();
        } else if (row < widget.data.length - 1) {
          focusNodes[row + 1][0].requestFocus();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.tab && isShift) {
        if (col > 0) {
          focusNodes[row][col - 1].requestFocus();
        } else if (row > 0) {
          focusNodes[row - 1][widget.columns.length - 1].requestFocus();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.tab && isCtrl) {
        if (col > 0) {
          focusNodes[row][col - 1].requestFocus();
        } else if (row > 0) {
          focusNodes[row - 1][widget.columns.length - 1].requestFocus();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (col < widget.columns.length - 1) {
          focusNodes[row][col + 1].requestFocus();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (col > 0) {
          focusNodes[row][col - 1].requestFocus();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        if (row < widget.data.length - 1) {
          focusNodes[row + 1][col].requestFocus();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (row > 0) {
          focusNodes[row - 1][col].requestFocus();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              Row(
                children: widget.columns
                    .map((col) => Container(
                          width: 120,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D6A4F),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Center(
                            child: Text(col,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ))
                    .toList(),
              ),
              SizedBox(
                height: constraints.maxHeight - 48,
                child: ListView.builder(
                  itemCount: widget.data.length,
                  itemExtent: 40,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemBuilder: (context, row) {
                    return Row(
                      children: List.generate(widget.columns.length, (col) {
                        final isActive = _activeRow == row && _activeCol == col;
                        return Container(
                          width: 120,
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.black : Colors.white,
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: RawKeyboardListener(
                            focusNode: focusNodes[row][col],
                            onKey: (event) => _handleKey(
                                focusNodes[row][col], event, row, col),
                            child: TextFormField(
                              controller: controllers[row][col],
                              autofocus: isActive,
                              onChanged: (v) {
                                widget.onChanged(row, col, v);
                              },
                              decoration: const InputDecoration(
                                  border: InputBorder.none),
                              style: TextStyle(
                                fontSize: 15,
                                color: isActive ? Colors.white : Colors.black,
                              ),
                              onTap: () {
                                setState(() {
                                  _activeRow = row;
                                  _activeCol = col;
                                });
                                Clipboard.setData(ClipboardData(
                                    text: controllers[row][col].text));
                              },
                              readOnly: false,
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
