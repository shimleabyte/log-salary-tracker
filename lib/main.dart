import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TeacherLogApp());
}

class TeacherLogApp extends StatelessWidget {
  const TeacherLogApp({super.key});

  static const Color teal = Color(0xFF287F78);
  static const Color pageBackground = Color(0xFFF3F8F6);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.light,
      surface: Colors.white,
    );

    return MaterialApp(
      title: 'Teacher Log & Salary Tracker',
      debugShowCheckedModeBanner: false,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: pageBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: pageBackground,
          foregroundColor: Color(0xFF183A36),
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 68,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7FAF8),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDCE8E3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDCE8E3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: teal, width: 1.4),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: teal,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const TeacherLogHomePage(),
    );
  }
}

class AttendanceLog {
  const AttendanceLog({
    required this.id,
    required this.date,
    required this.className,
    required this.jp,
    required this.notes,
  });

  final int id;
  final DateTime date;
  final String className;
  final int jp;
  final String notes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'className': className,
        'jp': jp,
        'notes': notes,
      };

  factory AttendanceLog.fromMap(Map<String, dynamic> map) {
    final parsedDate = DateTime.tryParse(map['date']?.toString() ?? '') ??
        DateTime.now();
    final rawJp = map['jp'];
    final parsedJp = rawJp is num ? rawJp.toInt() : int.tryParse('$rawJp') ?? 1;
    final rawId = map['id'];

    return AttendanceLog(
      id: rawId is num ? rawId.toInt() : DateTime.now().microsecondsSinceEpoch,
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      className: map['className']?.toString() ?? 'Kelas tanpa nama',
      jp: parsedJp.clamp(1, 12).toInt(),
      notes: map['notes']?.toString() ?? '',
    );
  }
}

class TeacherLogHomePage extends StatefulWidget {
  const TeacherLogHomePage({super.key});

  @override
  State<TeacherLogHomePage> createState() => _TeacherLogHomePageState();
}

class _TeacherLogHomePageState extends State<TeacherLogHomePage> {
  static const String _logsKey = 'teacher_log_entries_v1';
  static const String _jpRateKey = 'teacher_log_rate_per_jp_v1';
  static const String _transportRateKey = 'teacher_log_transport_per_day_v1';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<AttendanceLog> _logs = [];
  bool _isLoading = true;
  String? _loadError;
  int _ratePerJp = 20000;
  int _transportPerDay = 25000;
  int _selectedJp = 1;
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Future<void> _saveQueue = Future<void>.value();

  static const List<String> _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const List<String> _shortMonthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _classController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final rawLogs = await _prefs.getString(_logsKey);
      final loadedLogs = <AttendanceLog>[];

      if (rawLogs != null && rawLogs.isNotEmpty) {
        final decoded = jsonDecode(rawLogs);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              try {
                loadedLogs.add(
                  AttendanceLog.fromMap(Map<String, dynamic>.from(item)),
                );
              } catch (_) {
                // Lewati satu record yang rusak; record lain tetap dimuat.
              }
            }
          }
        }
      }

      final savedJpRate = await _prefs.getInt(_jpRateKey) ?? 20000;
      final savedTransportRate = await _prefs.getInt(_transportRateKey) ?? 25000;

      if (!mounted) return;
      setState(() {
        _logs = loadedLogs;
        _ratePerJp = savedJpRate < 0 ? 20000 : savedJpRate;
        _transportPerDay = savedTransportRate < 0 ? 25000 : savedTransportRate;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Data lokal tidak dapat dibaca. Coba tutup dan buka aplikasi kembali.';
      });
    }
  }

  Future<bool> _persistAll() async {
    final logSnapshot = jsonEncode(_logs.map((entry) => entry.toMap()).toList());
    final jpRateSnapshot = _ratePerJp;
    final transportRateSnapshot = _transportPerDay;

    // Urutkan operasi tulis agar perubahan yang lebih baru tidak tertimpa
    // oleh operasi simpan sebelumnya yang selesai belakangan.
    final operation = _saveQueue.catchError((Object _) {}).then((_) async {
      await _prefs.setString(_logsKey, logSnapshot);
      await _prefs.setInt(_jpRateKey, jpRateSnapshot);
      await _prefs.setInt(_transportRateKey, transportRateSnapshot);
    });
    _saveQueue = operation;

    try {
      await operation;
      return true;
    } catch (_) {
      if (mounted) {
        _showSnackBar('Gagal menyimpan ke penyimpanan lokal. Coba lagi.');
      }
      return false;
    }
  }

  List<AttendanceLog> get _monthlyLogs {
    final result = _logs.where((entry) {
      return entry.date.year == _selectedMonth.year &&
          entry.date.month == _selectedMonth.month;
    }).toList();

    result.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
    return result;
  }

  int get _totalJp => _monthlyLogs.fold<int>(0, (sum, entry) => sum + entry.jp);

  int get _totalAttendanceDays => _monthlyLogs
      .map((entry) => '${entry.date.year}-${entry.date.month}-${entry.date.day}')
      .toSet()
      .length;

  int get _baseHonor => _totalJp * _ratePerJp;
  int get _transportTotal => _totalAttendanceDays * _transportPerDay;
  int get _takeHomePay => _baseHonor + _transportTotal;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('id', 'ID'),
      initialDate: _selectedDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Pilih tanggal mengajar',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _selectedMonth = DateTime(picked.year, picked.month);
    });
  }

  Future<void> _addLog() async {
    if (!_formKey.currentState!.validate()) return;

    final entry = AttendanceLog(
      id: DateTime.now().microsecondsSinceEpoch,
      date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      className: _classController.text.trim(),
      jp: _selectedJp,
      notes: _notesController.text.trim(),
    );

    setState(() {
      _logs.add(entry);
      _selectedMonth = DateTime(entry.date.year, entry.date.month);
      _classController.clear();
      _notesController.clear();
      _selectedJp = 1;
    });

    final saved = await _persistAll();
    if (saved && mounted) _showSnackBar('Log mengajar berhasil disimpan.');
  }

  Future<void> _confirmDelete(AttendanceLog entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus log?'),
        content: Text('Log kelas "${entry.className}" pada ${formatDate(entry.date)} akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB54747)),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _logs.removeWhere((item) => item.id == entry.id));
    final saved = await _persistAll();
    if (saved && mounted) _showSnackBar('Log berhasil dihapus.');
  }

  Future<void> _editRates() async {
    final jpController = TextEditingController(text: _ratePerJp.toString());
    final transportController = TextEditingController(text: _transportPerDay.toString());
    final dialogFormKey = GlobalKey<FormState>();

    try {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Atur tarif honor'),
          content: SingleChildScrollView(
            child: Form(
              key: dialogFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nilai ini dipakai untuk menghitung ringkasan bulan yang dipilih.',
                    style: TextStyle(color: Color(0xFF60736E), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: jpController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Honor per JP',
                      prefixText: 'Rp ',
                      suffixText: '/ JP',
                    ),
                    validator: _validateRate,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: transportController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Transport per hari hadir',
                      prefixText: 'Rp ',
                      suffixText: '/ hari',
                    ),
                    validator: _validateRate,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (dialogFormKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Simpan tarif'),
            ),
          ],
        ),
      );
      if (shouldSave != true || !mounted) return;

      final parsedJpRate = int.tryParse(jpController.text) ?? _ratePerJp;
      final parsedTransportRate =
          int.tryParse(transportController.text) ?? _transportPerDay;

      setState(() {
        _ratePerJp = parsedJpRate;
        _transportPerDay = parsedTransportRate;
      });

      final saved = await _persistAll();
      if (saved && mounted) _showSnackBar('Tarif berhasil diperbarui.');
    } finally {
      jpController.dispose();
      transportController.dispose();
    }
  }

  String? _validateRate(String? value) {
    final amount = int.tryParse(value ?? '');
    if (amount == null) return 'Masukkan angka yang valid';
    if (amount < 0) return 'Tarif tidak boleh negatif';
    if (amount > 1000000000) return 'Nilai terlalu besar';
    return null;
  }

  void _changeMonth(int difference) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + difference,
      );
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Teacher Log',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            Text(
              '& Salary Tracker',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Atur tarif honor',
            onPressed: _editRates,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                if (_loadError != null) ...[
                  _buildLoadWarning(),
                  const SizedBox(height: 12),
                ],
                _buildMonthHeader(),
                const SizedBox(height: 14),
                _buildSummaryCards(),
                const SizedBox(height: 12),
                _buildTakeHomeCard(),
                const SizedBox(height: 24),
                _buildSectionHeading(
                  'Tambah log mengajar',
                  subtitle: 'Catat kelas, jumlah JP, dan perkembangan belajar.',
                ),
                const SizedBox(height: 12),
                _buildEntryForm(),
                const SizedBox(height: 24),
                _buildSectionHeading(
                  'Riwayat log',
                  subtitle: '${_monthlyLogs.length} catatan pada ${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                ),
                const SizedBox(height: 12),
                if (_monthlyLogs.isEmpty)
                  _buildEmptyHistory()
                else
                  ..._monthlyLogs.map(_buildLogCard),
                const SizedBox(height: 12),
                const Text(
                  'Perhitungan THP adalah estimasi honor + transport dan belum memperhitungkan potongan lain.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667873),
                    height: 1.4,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD8A8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFF9A5B00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _loadError!,
              style: const TextStyle(color: Color(0xFF754A12), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Bulan sebelumnya',
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              const Text(
                'RINGKASAN BULANAN',
                style: TextStyle(
                  color: Color(0xFF60736E),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF183A36),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Bulan berikutnya',
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 660 ? 4 : 2;
        const gap = 12.0;
        final cardWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: cardWidth,
              child: _MetricCard(
                icon: Icons.menu_book_rounded,
                label: 'Total JP',
                value: '$_totalJp JP',
                helper: '${formatRupiah(_ratePerJp)} / JP',
                iconColor: const Color(0xFF287F78),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _MetricCard(
                icon: Icons.calendar_month_rounded,
                label: 'Hari hadir',
                value: '$_totalAttendanceDays hari',
                helper: 'Tanggal unik',
                iconColor: const Color(0xFF4C7DA7),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _MetricCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Honor pokok',
                value: formatRupiah(_baseHonor),
                helper: 'Total JP × tarif JP',
                iconColor: const Color(0xFF5B8B59),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _MetricCard(
                icon: Icons.directions_car_filled_outlined,
                label: 'Transport',
                value: formatRupiah(_transportTotal),
                helper: '${formatRupiah(_transportPerDay)} / hari',
                iconColor: const Color(0xFFB17A37),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTakeHomeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TeacherLogApp.teal,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estimasi Take-Home Pay',
                  style: TextStyle(
                    color: Color(0xFFE1F3EF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatRupiah(_takeHomePay),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Honor pokok + transport',
                  style: TextStyle(color: Color(0xFFD5EAE5), fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ubah tarif perhitungan',
            onPressed: _editRates,
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String title, {required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF183A36),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF667873),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildEntryForm() {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE1EBE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tanggal mengajar',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(formatDate(_selectedDate)),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: const Color(0xFF244D46),
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: Color(0xFFDCE8E3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _classController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama kelas',
                  hintText: 'Contoh: Tahfidz kelas 5A',
                  prefixIcon: Icon(Icons.groups_2_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama kelas wajib diisi';
                  }
                  if (value.trim().length > 80) {
                    return 'Nama kelas maksimal 80 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: _selectedJp,
                decoration: const InputDecoration(
                  labelText: 'Jumlah JP',
                  prefixIcon: Icon(Icons.schedule_rounded),
                ),
                items: List.generate(12, (index) => index + 1)
                    .map(
                      (jp) => DropdownMenuItem<int>(
                        value: jp,
                        child: Text('$jp JP'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedJp = value);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Catatan Tahsin/Tahfidz',
                  hintText: 'Contoh: Murajaah surat, kelancaran, atau materi.',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton.icon(
                onPressed: _addLog,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan log mengajar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogCard(AttendanceLog entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE1EBE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 13, 8, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    entry.date.day.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      color: Color(0xFF246E65),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _shortMonthNames[entry.date.month - 1],
                    style: const TextStyle(
                      color: Color(0xFF52716A),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.className,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF183A36),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F5F3),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${entry.jp} JP',
                      style: const TextStyle(
                        color: Color(0xFF42645D),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (entry.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      entry.notes,
                      style: const TextStyle(
                        color: Color(0xFF536761),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Hapus log',
              onPressed: () => _confirmDelete(entry),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline_rounded, size: 21),
              color: const Color(0xFF9B5A5A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1EBE6)),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_note_outlined, size: 35, color: Color(0xFF8BA59D)),
          SizedBox(height: 10),
          Text(
            'Belum ada log di bulan ini',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF244D46),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tambahkan catatan mengajar melalui form di atas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF667873)),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1EBE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(height: 11),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF687B75),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF183A36),
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF87948F),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

String formatDate(DateTime date) {
  const months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatRupiah(int value) {
  final digits = value.abs().toString();
  final output = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      output.write('.');
    }
    output.write(digits[index]);
  }
  final sign = value < 0 ? '-' : '';
  return '${sign}Rp ${output.toString()}';
}