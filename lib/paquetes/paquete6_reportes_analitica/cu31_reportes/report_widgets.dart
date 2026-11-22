import 'package:flutter/material.dart';
import '../../../core/theme/taji_theme.dart';
import 'report_models.dart';

class ReportSection extends StatelessWidget {
  const ReportSection({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: TajiColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: TajiColors.ink,
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              subtitle!,
              style: const TextStyle(color: TajiColors.muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class ReportRecord extends StatelessWidget {
  const ReportRecord({
    required this.columns,
    required this.values,
    required this.index,
    super.key,
  });
  final List<ReportColumn> columns;
  final List<String> values;
  final int index;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 12),
    title: Text(
      values.isEmpty || values.first.isEmpty
          ? 'Registro ${index + 1}'
          : values.first,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      '${columns.length} campos · tocar para ver',
      style: const TextStyle(fontSize: 11, color: TajiColors.muted),
    ),
    children: [
      for (var i = 0; i < columns.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  columns[i].label,
                  style: const TextStyle(fontSize: 12, color: TajiColors.muted),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: SelectableText(
                  i < values.length && values[i].isNotEmpty ? values[i] : '—',
                  style: const TextStyle(fontSize: 13, color: TajiColors.ink),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class ReportFilterEditor extends StatelessWidget {
  const ReportFilterEditor({
    required this.filter,
    required this.source,
    required this.index,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });
  final ReportFilter filter;
  final ReportSource source;
  final int index;
  final bool enabled;
  final VoidCallback onChanged, onRemove;
  @override
  Widget build(BuildContext context) {
    final column = source.columns.firstWhere((c) => c.key == filter.field);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: filter.field,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'Campo ${index + 1}'),
                  items: source.columns
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.key,
                          child: Text(
                            c.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: !enabled
                      ? null
                      : (v) {
                          filter.field = v!;
                          final col = source.columns.firstWhere(
                            (c) => c.key == v,
                          );
                          filter.operator = col.operators.first;
                          filter.value = '';
                          onChanged();
                        },
                ),
              ),
              IconButton(
                tooltip: 'Quitar filtro ${index + 1}',
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: filter.operator,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Condición'),
            items: column.operators
                .map(
                  (op) => DropdownMenuItem(
                    value: op,
                    child: Text(reportOperatorLabels[op] ?? op),
                  ),
                )
                .toList(),
            onChanged: !enabled
                ? null
                : (v) {
                    filter.operator = v!;
                    onChanged();
                  },
          ),
          if (!emptyReportOperator(filter.operator)) ...[
            const SizedBox(height: 10),
            if (column.type == 'choice')
              DropdownButtonFormField<String>(
                value: column.choices.any((c) => c['value'] == filter.value)
                    ? filter.value
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Valor del filtro',
                ),
                items: column.choices
                    .map(
                      (c) => DropdownMenuItem(
                        value: '${c['value']}',
                        child: Text('${c['label']}'),
                      ),
                    )
                    .toList(),
                onChanged: !enabled
                    ? null
                    : (v) {
                        filter.value = v ?? '';
                        onChanged();
                      },
              )
            else if (column.type == 'date' || column.type == 'datetime')
              OutlinedButton.icon(
                onPressed: !enabled
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.tryParse(filter.value) ?? DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2200),
                        );
                        if (date != null && context.mounted) {
                          filter.value = date.toIso8601String().substring(
                            0,
                            10,
                          );
                          onChanged();
                        }
                      },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  filter.value.isEmpty ? 'Elegir fecha' : filter.value,
                ),
              )
            else
              TextFormField(
                key: ValueKey(
                  '${identityHashCode(filter)}-${filter.field}-${filter.operator}',
                ),
                initialValue: filter.value,
                enabled: enabled,
                maxLength: 200,
                keyboardType: column.type == 'number'
                    ? const TextInputType.numberWithOptions(signed: true)
                    : TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Valor del filtro',
                  counterText: '',
                ),
                onChanged: (v) {
                  filter.value = v;
                  onChanged();
                },
              ),
          ],
        ],
      ),
    );
  }
}
