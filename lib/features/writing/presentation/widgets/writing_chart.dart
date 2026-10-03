/// Renders a Task 1 `chart_data` object without any charting dependency.
///
/// The seed ships four shapes — `line`, `bar`, `pie` and `table` — which are
/// drawn here with [CustomPainter] (line / bar / pie) or a plain [Table]. The
/// parser is defensive: unknown or malformed fields degrade to an empty chart
/// rather than throwing (the widget is skipped when there is nothing to draw).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/json_utils.dart';

/// One data series (a line or a set of bars).
@immutable
class ChartSeries {
  const ChartSeries({required this.name, required this.values});

  /// Series label (e.g. `Country A`).
  final String name;

  /// The values, one per x position / category.
  final List<double> values;
}

/// One slice of a pie chart.
@immutable
class ChartSlice {
  const ChartSlice({required this.label, required this.value});

  /// Slice label.
  final String label;

  /// Slice value.
  final double value;
}

/// Parsed `writing_tasks.chart_data`.
@immutable
class WritingChartData {
  const WritingChartData({
    required this.type,
    this.title,
    this.unit,
    this.xLabels = const <String>[],
    this.xAxisLabel,
    this.yAxisLabel,
    this.series = const <ChartSeries>[],
    this.categories = const <String>[],
    this.slices = const <ChartSlice>[],
    this.columns = const <String>[],
    this.rows = const <List<String>>[],
  });

  /// One of `line` / `bar` / `pie` / `table`.
  final String type;

  /// Chart title.
  final String? title;

  /// Value unit (e.g. `%`).
  final String? unit;

  /// X-axis tick labels (line charts).
  final List<String> xLabels;

  /// X-axis label (line charts).
  final String? xAxisLabel;

  /// Y-axis label (line / bar charts).
  final String? yAxisLabel;

  /// Line / bar series.
  final List<ChartSeries> series;

  /// Category labels (bar charts).
  final List<String> categories;

  /// Pie slices.
  final List<ChartSlice> slices;

  /// Table header cells.
  final List<String> columns;

  /// Table body rows (normalised to [columns]'s length).
  final List<List<String>> rows;

  /// Whether there is nothing to draw for [type].
  bool get isEmpty {
    switch (type) {
      case 'line':
        return series.isEmpty || xLabels.isEmpty;
      case 'bar':
        return series.isEmpty || categories.isEmpty;
      case 'pie':
        return slices.isEmpty;
      case 'table':
        return columns.isEmpty || rows.isEmpty;
      default:
        return true;
    }
  }

  /// Parses a decoded `chart_data` map.
  factory WritingChartData.fromMap(Map<String, Object?> map) {
    final String type = (asString(map['type']) ?? '').toLowerCase();

    final Map<String, Object?>? xAxis = decodeMap(map['xAxis']);
    final Map<String, Object?>? yAxis = decodeMap(map['yAxis']);

    final List<ChartSeries> series = <ChartSeries>[
      for (final Map<String, Object?> item in decodeMapList(map['series']))
        ChartSeries(
          name: asString(item['name']) ?? '',
          values: <double>[
            for (final Object? value in _asList(item['values']))
              asDouble(value) ?? 0,
          ],
        ),
    ];

    final List<ChartSlice> slices = <ChartSlice>[
      for (final Map<String, Object?> item in decodeMapList(map['items']))
        ChartSlice(
          label: asString(item['label']) ?? '',
          value: asDouble(item['value']) ?? 0,
        ),
    ];

    final List<String> columns = decodeStringList(map['columns']);
    final List<List<String>> rawRows = decodeStringMatrix(map['rows']);
    final List<List<String>> rows = <List<String>>[
      for (final List<String> row in rawRows)
        <String>[
          for (int i = 0; i < columns.length; i++)
            i < row.length ? row[i] : '',
        ],
    ];

    return WritingChartData(
      type: type,
      title: asString(map['title']),
      unit: asString(map['unit']),
      xLabels: xAxis == null ? const <String>[] : decodeStringList(xAxis['values']),
      xAxisLabel: xAxis == null ? null : asString(xAxis['label']),
      yAxisLabel: yAxis == null ? null : asString(yAxis['label']),
      series: series,
      categories: decodeStringList(map['categories']),
      slices: slices,
      columns: columns,
      rows: rows,
    );
  }
}

List<Object?> _asList(Object? raw) =>
    raw is List<Object?> ? raw : const <Object?>[];

/// Draws one Task 1 chart.
class WritingChart extends StatelessWidget {
  const WritingChart({super.key, required this.data});

  /// The parsed chart data.
  final WritingChartData data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final List<Color> seriesColors = _seriesColors(context);

    final Widget body;
    switch (data.type) {
      case 'line':
        body = _AxisChart(data: data, isLine: true, colors: seriesColors);
      case 'bar':
        body = _AxisChart(data: data, isLine: false, colors: seriesColors);
      case 'pie':
        body = _PieChart(data: data, colors: seriesColors);
      case 'table':
        body = _TableView(data: data);
      default:
        body = const SizedBox.shrink();
    }

    final String? caption = _axisCaption(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (data.title != null && data.title!.isNotEmpty)
          Text(data.title!, style: theme.textTheme.titleSmall),
        if (caption != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            caption,
            style: theme.textTheme.caption.copyWith(
              color: context.palette.muted,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        body,
      ],
    );
  }
}

/// The x / y axis caption line (e.g. `Year · Percentage of households (%)`).
String? _axisCaption(WritingChartData data) {
  final List<String> parts = <String>[
    if (data.xAxisLabel != null && data.xAxisLabel!.isNotEmpty) data.xAxisLabel!,
    if (data.yAxisLabel != null && data.yAxisLabel!.isNotEmpty)
      data.unit == null || data.unit!.isEmpty
          ? data.yAxisLabel!
          : '${data.yAxisLabel!} (${data.unit!})',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

List<Color> _seriesColors(BuildContext context) {
  final ColorScheme colors = Theme.of(context).colorScheme;
  final AppPalette palette = context.palette;
  return <Color>[
    colors.primary,
    colors.secondary,
    palette.success,
    palette.warning,
    colors.tertiary,
  ];
}

// --- Line / bar -------------------------------------------------------------

class _AxisChart extends StatelessWidget {
  const _AxisChart({
    required this.data,
    required this.isLine,
    required this.colors,
  });

  final WritingChartData data;
  final bool isLine;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> labels = isLine ? data.xLabels : data.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 200,
          width: double.infinity,
          child: CustomPaint(
            painter: _AxisChartPainter(
              labels: labels,
              series: data.series,
              isLine: isLine,
              colors: colors,
              gridColor: theme.colorScheme.outlineVariant,
              labelColor: context.palette.muted,
              textStyle: theme.textTheme.caption,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Legend(
          names: <String>[
            for (final ChartSeries series in data.series) series.name,
          ],
          colors: colors,
        ),
      ],
    );
  }
}

class _AxisChartPainter extends CustomPainter {
  _AxisChartPainter({
    required this.labels,
    required this.series,
    required this.isLine,
    required this.colors,
    required this.gridColor,
    required this.labelColor,
    required this.textStyle,
  });

  final List<String> labels;
  final List<ChartSeries> series;
  final bool isLine;
  final List<Color> colors;
  final Color gridColor;
  final Color labelColor;
  final TextStyle textStyle;

  static const double _leftPad = 40;
  static const double _rightPad = 8;
  static const double _topPad = 8;
  static const double _bottomPad = 30;

  /// Plot height, captured in [paint] for the x-label placement.
  double _plotH = 0;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty || series.isEmpty) {
      return;
    }
    final double plotW = size.width - _leftPad - _rightPad;
    final double plotH = size.height - _topPad - _bottomPad;
    if (plotW <= 0 || plotH <= 0) {
      return;
    }
    _plotH = plotH;

    double maxValue = 0;
    for (final ChartSeries item in series) {
      for (final double value in item.values) {
        if (value > maxValue) {
          maxValue = value;
        }
      }
    }
    maxValue = _niceMax(maxValue);

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    const int gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final double y = _topPad + plotH * (i / gridLines);
      canvas.drawLine(
        Offset(_leftPad, y),
        Offset(_leftPad + plotW, y),
        gridPaint,
      );
      final double value = maxValue * (1 - i / gridLines);
      _paintYLabel(canvas, _formatNumber(value), y);
    }

    if (isLine) {
      _paintLines(canvas, plotW, plotH, maxValue);
    } else {
      _paintBars(canvas, plotW, plotH, maxValue);
    }
  }

  void _paintLines(Canvas canvas, double plotW, double plotH, double maxValue) {
    final int count = labels.length;
    final double gap = count <= 1 ? 0 : plotW / (count - 1);

    double xAt(int index) =>
        count <= 1 ? _leftPad + plotW / 2 : _leftPad + gap * index;
    double yAt(double value) => _topPad + plotH * (1 - value / maxValue);

    for (int s = 0; s < series.length; s++) {
      final ChartSeries item = series[s];
      final Color color = colors[s % colors.length];
      final Paint stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round;

      final Path path = Path();
      bool started = false;
      for (int i = 0; i < count; i++) {
        final double value = _valueAt(item, i);
        final Offset point = Offset(xAt(i), yAt(value));
        if (!started) {
          path.moveTo(point.dx, point.dy);
          started = true;
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, stroke);
      for (int i = 0; i < count; i++) {
        canvas.drawCircle(
          Offset(xAt(i), yAt(_valueAt(item, i))),
          2.5,
          Paint()..color = color,
        );
      }
    }

    final double labelWidth = count <= 1 ? plotW : gap;
    for (int i = 0; i < count; i++) {
      _paintXLabel(canvas, labels[i], xAt(i), labelWidth);
    }
  }

  void _paintBars(Canvas canvas, double plotW, double plotH, double maxValue) {
    final int count = labels.length;
    final int seriesCount = series.length;
    final double groupW = plotW / count;
    final double barW = (groupW * 0.7) / seriesCount;

    for (int c = 0; c < count; c++) {
      final double groupLeft = _leftPad + groupW * c + groupW * 0.15;
      for (int s = 0; s < seriesCount; s++) {
        final double value = _valueAt(series[s], c);
        final double height = plotH * (value / maxValue);
        final Rect rect = Rect.fromLTWH(
          groupLeft + barW * s,
          _topPad + plotH - height,
          barW * 0.9,
          height,
        );
        canvas.drawRect(rect, Paint()..color = colors[s % colors.length]);
      }
      _paintXLabel(
        canvas,
        labels[c],
        _leftPad + groupW * c + groupW / 2,
        groupW,
      );
    }
  }

  double _valueAt(ChartSeries item, int index) =>
      index < item.values.length ? item.values[index] : 0;

  void _paintYLabel(Canvas canvas, String text, double centerY) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(color: labelColor),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(
      canvas,
      Offset(_leftPad - 6 - painter.width, centerY - painter.height / 2),
    );
  }

  void _paintXLabel(
    Canvas canvas,
    String text,
    double centerX,
    double maxWidth,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(color: labelColor),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth < 24 ? 24 : maxWidth);
    painter.paint(
      canvas,
      Offset(centerX - painter.width / 2, _topPad + _plotH + 4),
    );
  }

  @override
  bool shouldRepaint(_AxisChartPainter oldDelegate) => true;
}

// --- Pie --------------------------------------------------------------------

class _PieChart extends StatelessWidget {
  const _PieChart({required this.data, required this.colors});

  final WritingChartData data;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 140,
          height: 140,
          child: CustomPaint(
            painter: _PiePainter(slices: data.slices, colors: colors),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < data.slices.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          borderRadius: AppRadius.smAll,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          data.slices[i].label,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _formatNumber(data.slices[i].value) +
                            (data.unit ?? ''),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.slices, required this.colors});

  final List<ChartSlice> slices;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    double total = 0;
    for (final ChartSlice slice in slices) {
      total += slice.value;
    }
    if (total <= 0) {
      return;
    }
    final Rect rect = Offset.zero & size;
    double start = -math.pi / 2;
    for (int i = 0; i < slices.length; i++) {
      final double sweep = 2 * math.pi * (slices[i].value / total);
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = colors[i % colors.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) => true;
}

// --- Table ------------------------------------------------------------------

class _TableView extends StatelessWidget {
  const _TableView({required this.data});

  final WritingChartData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color border = theme.colorScheme.outlineVariant;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: border, width: 1),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: <TableRow>[
          TableRow(
            children: <Widget>[
              for (final String column in data.columns)
                _cell(theme, column, header: true),
            ],
          ),
          for (final List<String> row in data.rows)
            TableRow(
              children: <Widget>[
                for (final String cell in row) _cell(theme, cell),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(ThemeData theme, String text, {bool header = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        text,
        style: header ? theme.textTheme.titleSmall : theme.textTheme.bodySmall,
      ),
    );
  }
}

// --- Legend & helpers -------------------------------------------------------

class _Legend extends StatelessWidget {
  const _Legend({required this.names, required this.colors});

  final List<String> names;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (int i = 0; i < names.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  borderRadius: AppRadius.smAll,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                names[i],
                style: theme.textTheme.caption.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Rounds [value] up to a "nice" axis maximum (1 / 2 / 5 × 10ⁿ).
double _niceMax(double value) {
  if (value <= 0) {
    return 1;
  }
  final double magnitude =
      math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
  final double normalized = value / magnitude;
  final double nice;
  if (normalized <= 1) {
    nice = 1;
  } else if (normalized <= 2) {
    nice = 2;
  } else if (normalized <= 5) {
    nice = 5;
  } else {
    nice = 10;
  }
  return nice * magnitude;
}

/// Formats [value] without a trailing `.0`.
String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}
