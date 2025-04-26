import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';

class EventBriefInfo extends StatefulWidget {
  final CalendarEventModel event;
  final VoidCallback onClose;
  final Offset position;
  final Function(CalendarEventModel) onEdit;
  final Function(CalendarEventModel) onDuplicate;
  final Function(CalendarEventModel) onDelete;
  final Function(CalendarEventModel)? onDurationChange;

  const EventBriefInfo({
    super.key,
    required this.event,
    required this.onClose,
    required this.position,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    this.onDurationChange,
  });

  @override
  State<EventBriefInfo> createState() => _EventBriefInfoState();
}

class _EventBriefInfoState extends State<EventBriefInfo>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  int _durationMinutes = 0;
  late CalendarEventModel _eventCopy;

  @override
  void initState() {
    super.initState();

    // Initialize the local event copy and duration
    _eventCopy = widget.event;
    _durationMinutes = _eventCopy.end.difference(_eventCopy.start).inMinutes;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 333),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // This transparent container covers the whole screen to detect taps outside
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        // The actual info card with animation
        Positioned(
          left: widget.position.dx,
          top: widget.position.dy,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTap: () {}, // Prevent taps from reaching the background
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: _eventCopy.color.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _eventCopy.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _eventCopy.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: widget.onClose,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDateRange(_eventCopy.start, _eventCopy.end,
                              _eventCopy.wholeDay),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                        if (_eventCopy.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _eventCopy.description,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],

                        if (_eventCopy.reminder != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.notifications, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Reminder: ${DateFormat('MMM d, h:mm a').format(_eventCopy.reminder!)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],

                        // Add the duration controls
                        if (!_eventCopy.wholeDay) _buildDurationControls(),

                        const SizedBox(height: 16),
                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                widget.onClose();
                                widget.onEdit(_eventCopy);
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Edit'),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                widget.onClose();
                                widget.onDuplicate(_eventCopy);
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Duplicate'),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                widget.onClose();
                                widget.onDelete(_eventCopy);
                              },
                              icon: const Icon(Icons.delete, size: 18),
                              label: const Text('Delete'),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateRange(DateTime start, DateTime end, bool wholeDay) {
    if (wholeDay) {
      if (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day) {
        return 'All day, ${DateFormat('MMM d, yyyy').format(start)}';
      } else {
        return 'All day, ${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
      }
    } else {
      if (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day) {
        return '${DateFormat('MMM d, yyyy').format(start)} ${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';
      } else {
        return '${DateFormat('MMM d, h:mm a').format(start)} - ${DateFormat('MMM d, h:mm a').format(end)}';
      }
    }
  }

  Widget _buildDurationControls() {
    const int timeInterval = 15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        const Text('Adjust Duration:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
              onPressed: _durationMinutes <= timeInterval
                  ? null
                  : () {
                      // Decrease duration by one interval
                      setState(() {
                        _durationMinutes -= timeInterval;
                        final newEnd = _eventCopy.start
                            .add(Duration(minutes: _durationMinutes));
                        _eventCopy = _eventCopy.copyWith(end: newEnd);
                      });

                      // Update the event using callback
                      if (widget.onDurationChange != null) {
                        widget.onDurationChange!(_eventCopy);
                      }
                    },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${_durationMinutes ~/ 60}h ${_durationMinutes % 60}m',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
              onPressed: () {
                // Increase duration by one interval
                setState(() {
                  _durationMinutes += timeInterval;
                  final newEnd =
                      _eventCopy.start.add(Duration(minutes: _durationMinutes));
                  _eventCopy = _eventCopy.copyWith(end: newEnd);
                });

                // Update the event using callback
                if (widget.onDurationChange != null) {
                  widget.onDurationChange!(_eventCopy);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
