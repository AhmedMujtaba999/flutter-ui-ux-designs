import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'storage.dart';
import 'models.dart';
import 'widgets.dart';
import 'theme.dart';

class WorkItemsPage extends StatefulWidget {
  final String? initialTab; // 'active' or 'completed'
  const WorkItemsPage({super.key, this.initialTab});

  @override
  State<WorkItemsPage> createState() => _WorkItemsPageState();
}

class _WorkItemsPageState extends State<WorkItemsPage> {
  bool activeSelected = true;

  // ✅ Completed sub-tab state
  bool completedByDateSelected = true; // By date / History
  DateTime selectedDate = DateTime.now(); // default today

  @override
  void initState() {
    super.initState();
    if (widget.initialTab == 'completed') {
      activeSelected = false;
      completedByDateSelected = true;
      selectedDate = DateTime.now();
    }
    if (widget.initialTab == 'active') activeSelected = true;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    if (_isSameDay(d, now)) return "Today";
    return DateFormat('EEE, MMM d, y').format(d);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) return;
    setState(() => selectedDate = picked);
  }

  Future<List<WorkItem>> _load() async {
    final status = activeSelected ? 'active' : 'completed';
    final list = await AppDb.instance.listWorkItemsByStatus(status);

    // nice sorting: newest first
    list.sort((a, b) {
      final ad = activeSelected ? a.createdAt : (a.completedAt ?? a.createdAt);
      final bd = activeSelected ? b.createdAt : (b.completedAt ?? b.createdAt);
      return bd.compareTo(ad);
    });

    if (activeSelected) return list;

    // Completed -> History
    if (!completedByDateSelected) return list;

    // Completed -> By date (filter by completedAt)
    return list.where((it) {
      final dt = it.completedAt; // ✅ completed date
      if (dt == null) return false;
      return _isSameDay(dt, selectedDate);
    }).toList();
  }

  Future<void> _openInvoice(WorkItem it) async {
    await Navigator.pushNamed(context, '/invoice', arguments: it.id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteWorkItem(WorkItem it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete work item?"),
        content: const Text("This will permanently delete the work item and its services."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (ok != true) return;

    await AppDb.instance.deleteWorkItem(it.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted")));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          GradientHeader(
            title: "Work Items",
            child: PillSwitch(
              leftSelected: activeSelected,
              leftText: "Active",
              rightText: "Completed",
              onLeft: () => setState(() => activeSelected = true),
              onRight: () => setState(() {
                activeSelected = false;
                // default when user enters completed
                completedByDateSelected = true;
                selectedDate = DateTime.now();
              }),
            ),
          ),

          if (!activeSelected) _completedControls(),

          Expanded(
            child: FutureBuilder<List<WorkItem>>(
              future: _load(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                final list = snap.data!;
                if (list.isEmpty) {
                  final msg = activeSelected
                      ? "No active work items"
                      : completedByDateSelected
                          ? "No completed items for ${_dateLabel(selectedDate)}"
                          : "No completed work items";

                  return EmptyState(text: msg);
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                    await Future.delayed(const Duration(milliseconds: 200));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _workCard(list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =======================
  // ✅ Completed Controls (Pro UI)
  // =======================
  Widget _completedControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _segmentedTabsWithCalendarInsideByDate(),
            if (completedByDateSelected) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    "Showing: ${_dateLabel(selectedDate)}",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segmentedTabsWithCalendarInsideByDate() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // ✅ BY DATE (with calendar icon INSIDE)
          Expanded(
            child: InkWell(
              onTap: () => setState(() => completedByDateSelected = true),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: completedByDateSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: completedByDateSelected ? AppColors.primary.withOpacity(0.35) : Colors.transparent,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_available_outlined,
                        size: 18,
                        color: completedByDateSelected ? AppColors.primary : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "By date",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: completedByDateSelected ? AppColors.primary : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Calendar button inside the By date pill
                      InkWell(
                        onTap: () async {
                          // Ensure By date is selected and open calendar
                          if (!completedByDateSelected) {
                            setState(() => completedByDateSelected = true);
                          }
                          await _pickDate();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: completedByDateSelected
                                ? AppColors.primary.withOpacity(0.14)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: completedByDateSelected
                                  ? AppColors.primary.withOpacity(0.20)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: completedByDateSelected ? AppColors.primary : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // ✅ HISTORY
          Expanded(
            child: InkWell(
              onTap: () => setState(() => completedByDateSelected = false),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: !completedByDateSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !completedByDateSelected ? AppColors.primary.withOpacity(0.35) : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        size: 18,
                        color: !completedByDateSelected ? AppColors.primary : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "History",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: !completedByDateSelected ? AppColors.primary : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =======================
  // Cards
  // =======================
  Widget _workCard(WorkItem it) {
    return InkWell(
      onTap: () => _openInvoice(it),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    it.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),

                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: activeSelected ? AppColors.primary.withOpacity(0.10) : Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        activeSelected ? Icons.timelapse : Icons.check_circle,
                        size: 16,
                        color: activeSelected ? AppColors.primary : Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        activeSelected ? "Active" : "Completed",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: activeSelected ? AppColors.primary : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                if (!activeSelected) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'delete') _deleteWorkItem(it);
                    },
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Center(
                          child: Text(
                            "Delete",
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            if (it.phone.trim().isNotEmpty) Text(it.phone, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total",
                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700),
                ),
                Text(
                  "\$${it.total.toStringAsFixed(2)}",
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
