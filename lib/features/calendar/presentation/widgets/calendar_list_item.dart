import 'package:flutter/material.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';

class CalendarListItem extends StatelessWidget {
  final CalendarModel calendar;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSync;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CalendarListItem({
    super.key,
    required this.calendar,
    this.isSelected = false,
    required this.onTap,
    required this.onSync,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color:
              isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Calendar color indicator
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: calendar.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),

              // Calendar details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          calendar.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (calendar.isDefault)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getCalendarTypeText(calendar.type),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons
              IconButton(
                icon: const Icon(Icons.sync),
                tooltip: 'Sync calendar',
                onPressed: calendar.type != CalendarType.local ? onSync : null,
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit calendar',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete calendar',
                onPressed: calendar.isDefault ? null : onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCalendarTypeText(CalendarType type) {
    switch (type) {
      case CalendarType.local:
        return 'Local Calendar';
      case CalendarType.webdav:
        return 'WebDAV Calendar';
      case CalendarType.device:
        return 'Device Calendar';
    }
  }
}
