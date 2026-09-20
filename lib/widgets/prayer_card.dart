import 'package:flutter/material.dart';
import '../models/prayer_time.dart';

class PrayerCard extends StatelessWidget {
  final PrayerTime prayer;

  const PrayerCard({super.key, required this.prayer});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final borderColor = prayer.isCurrent
        ? colorScheme.primary
        : prayer.isNext
            ? colorScheme.secondary
            : Colors.transparent;

    final elevation = prayer.isCurrent
        ? 6.0
        : prayer.isNext
            ? 4.0
            : 2.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          prayer.name,
          style: TextStyle(
            fontWeight: (prayer.isCurrent || prayer.isNext)
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          TimeOfDay.fromDateTime(prayer.time).format(context),
          style: TextStyle(
            fontSize: 18,
            fontWeight: (prayer.isCurrent || prayer.isNext)
                ? FontWeight.w700
                : FontWeight.normal,
            color: prayer.isCurrent
                ? colorScheme.primary
                : prayer.isNext
                    ? colorScheme.secondary
                    : null,
          ),
        ),
        trailing: prayer.isCurrent
            ? Chip(
                label: const Text('Now'),
                backgroundColor: colorScheme.primary.withAlpha(31),
                labelStyle: TextStyle(color: colorScheme.primary),
              )
            : prayer.isNext
                ? Chip(
                    label: const Text('Next'),
                    backgroundColor: colorScheme.secondary.withAlpha(31),
                    labelStyle: TextStyle(color: colorScheme.secondary),
                  )
                : null,
      ),
    );
  }
}
