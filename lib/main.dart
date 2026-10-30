import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ───────────────────────── Constantes ─────────────────────────
const kA = Color(0xFF6D5EFC);
const kB = Color(0xFFFF6BB5);
const kGrad = LinearGradient(
  colors: [kA, kB],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kCats = {'Personal': '🏠', 'Trabajo': '💼', 'Estudio': '📚'};
const kPrios = {
  'alta': Color(0xFFEF4444),
  'media': Color(0xFFF59E0B),
  'baja': Color(0xFF22C55E),
};
const kAvatars = ['😀', '😎', '🦊', '🐼', '🦁', '🐯', '🚀', '🌈', '🔥', '🌟', '🎯', '🧠'];

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String today() => dayKey(DateTime.now());

// ───────────────────────── Estado + Hive ─────────────────────────
class AppState extends ChangeNotifier {
  final Box box = Hive.box('todo');
  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> log = []; // historial permanente de completadas
  String name = '';
  String avatar = '😀';
  late String join;

  AppState() {
    tasks = _load('tasks');
    log = _load('log');
    name = box.get('name', defaultValue: '') as String;
    avatar = box.get('avatar', defaultValue: '😀') as String;
    join = box.get('join', defaultValue: today()) as String;
    box.put('join', join);
  }

  List<Map<String, dynamic>> _load(String k) => (box.get(k, defaultValue: []) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  void _save() {
    box.put('tasks', tasks);
    box.put('log', log);
    notifyListeners();
  }

  void add(String text, String p, String c, DateTime? date, TimeOfDay? time) {
    final tm = time == null
        ? null
        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    tasks.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'text': text,
      'p': p,
      'c': c,
      'd': date != null ? dayKey(date) : (tm != null ? today() : null),
      'tm': tm,
      'done': false,
      'n': false,
    });
    _save();
  }

  void toggle(Map<String, dynamic> t) {
    t['done'] = !(t['done'] as bool);
    log.removeWhere((l) => l['id'] == t['id']);
    if (t['done'] == true) {
      log.add({'id': t['id'], 'dt': today(), 'c': t['c'], 'p': t['p']});
    }
    _save();
  }

  void remove(Map<String, dynamic> t) {
    tasks.remove(t);
    _save();
  }

  void insertBack(int i, Map<String, dynamic> t) {
    tasks.insert(i.clamp(0, tasks.length), t);
    _save();
  }

  void clearDone() {
    tasks.removeWhere((t) => t['done'] == true);
    _save();
  }

  void setName(String v) {
    name = v.trim();
    box.put('name', name);
    notifyListeners();
  }

  void setAvatar(String a) {
    avatar = a;
    box.put('avatar', a);
    notifyListeners();
  }

  void wipe() {
    tasks = [];
    log = [];
    box.delete('b7');
    _save();
  }

  int get streak {
    final days = {for (final l in log) l['dt'] as String};
    var d = DateTime.now();
    if (!days.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
    var s = 0;
    while (days.contains(dayKey(d))) {
      s++;
      d = d.subtract(const Duration(days: 1));
    }
    return s;
  }

  int get level => log.length ~/ 5 + 1;

  bool justWon7() {
    if (streak >= 7 && box.get('b7') != true) {
      box.put('b7', true);
      return true;
    }
    return false;
  }

  DateTime? dueAt(Map<String, dynamic> t) {
    if (t['d'] == null) return null;
    final p = (t['d'] as String).split('-').map(int.parse).toList();
    final h = t['tm'] != null
        ? (t['tm'] as String).split(':').map(int.parse).toList()
        : [23, 59];
    return DateTime(p[0], p[1], p[2], h[0], h[1]);
  }

  /// Tareas con hora cuyo aviso ya toca (y que aún no se avisaron).
  List<Map<String, dynamic>> takeDue() {
    final now = DateTime.now();
    final out = <Map<String, dynamic>>[];
    for (final t in tasks) {
      if (t['done'] != true && t['tm'] != null && t['n'] != true) {
        final d = dueAt(t);
        if (d != null && !d.isAfter(now) && now.difference(d).inHours < 24) {
          t['n'] = true;
          out.add(t);
        }
      }
    }
    if (out.isNotEmpty) _save();
    return out;
  }
}

// ───────────────────────── Arranque ─────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('todo');
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) =>
        ThemeData(useMaterial3: true, colorSchemeSeed: kA, brightness: b);
    return MaterialApp(
      title: 'Mis tareas',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const SplashGate(),
    );
  }
}

// ───────────────────────── Animación de entrada ─────────────────────────
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  final AppState state = AppState();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      child: ready ? Shell(state: state) : Splash(name: state.name),
    );
  }
}

class Splash extends StatelessWidget {
  final String name;
  const Splash({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kGrad),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.elasticOut,
            builder: (_, v, __) => Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: v,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 110, color: Colors.white),
                    const SizedBox(height: 12),
                    const Text('Mis tareas',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(name.isEmpty ? 'Organiza tu día' : 'Hola, $name',
                        style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Shell con navegación ─────────────────────────
class Shell extends StatefulWidget {
  final AppState state;
  const Shell({super.key, required this.state});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 15), (_) => check());
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void check() {
    if (!mounted) return;
    for (final t in widget.state.takeDue()) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⏰ ${t['text']}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final pages = [TasksPage(state: s), StatsPage(state: s), ProfilePage(state: s)];
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
        ),
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => addSheet(context, s),
              icon: const Icon(Icons.add),
              label: const Text('Nueva'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Tareas'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Estadísticas'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}

// ───────────────────────── Tareas ─────────────────────────
class TasksPage extends StatefulWidget {
  final AppState state;
  const TasksPage({super.key, required this.state});
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String filter = 'todas';

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final all = s.tasks;
        final list = all.where((t) {
          switch (filter) {
            case 'pend':
              return t['done'] != true;
            case 'hechas':
              return t['done'] == true;
            default:
              return true;
          }
        }).toList();
        final done = all.where((t) => t['done'] == true).length;
        final p = all.isEmpty ? 0.0 : done / all.length;
        final h = DateTime.now().hour;
        final greet = h < 12 ? 'Buenos días' : h < 20 ? 'Buenas tardes' : 'Buenas noches';

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Text(greet, style: TextStyle(color: cs.outline)),
            Text(
              s.name.isEmpty ? 'Vamos a rendir' : s.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: kGrad,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: kA.withAlpha(100), blurRadius: 24, offset: const Offset(0, 10))
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: p),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (_, v, __) => Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: v,
                            strokeWidth: 9,
                            backgroundColor: Colors.white24,
                            color: Colors.white,
                          ),
                          Center(
                            child: Text('${(v * 100).round()}%',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          all.isEmpty
                              ? 'Empieza tu día'
                              : p == 1
                                  ? '¡Increíble!'
                                  : 'Vas muy bien',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          all.isEmpty
                              ? 'Añade tu primera tarea'
                              : '$done de ${all.length} tareas completadas',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final e in {'todas': 'Todas', 'pend': 'Pendientes', 'hechas': 'Hechas'}.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: filter == e.key,
                    onSelected: (_) => setState(() => filter = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Text('🌤️', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 6),
                    Text('Todo despejado. Añade algo.', style: TextStyle(color: cs.outline)),
                  ],
                ),
              ),
            for (final t in list) TaskTile(key: ValueKey(t['id']), state: s, t: t),
            if (done > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: s.clearDone, child: const Text('Borrar hechas')),
              ),
          ],
        );
      },
    );
  }
}

class TaskTile extends StatelessWidget {
  final AppState state;
  final Map<String, dynamic> t;
  const TaskTile({super.key, required this.state, required this.t});

  Widget chip(BuildContext context, String s, {bool hot = false}) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: hot ? Colors.red : Theme.of(context).dividerColor),
        ),
        child: Text(s,
            style: TextStyle(
                fontSize: 11.5,
                color: hot ? Colors.red : Theme.of(context).colorScheme.outline)),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = t['done'] == true;
    final due = state.dueAt(t);
    final late = !done && due != null && due.isBefore(DateTime.now());
    final tomorrow = dayKey(DateTime.now().add(const Duration(days: 1)));
    final dLabel = t['d'] == today() ? 'Hoy' : t['d'] == tomorrow ? 'Mañana' : '${t['d']}';
    final tm = t['tm'] != null ? ' · ⏰ ${t['tm']}' : '';
    final emoji = kCats[t['c']] ?? '';

    return Dismissible(
      key: ValueKey('d${t['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Colors.red.shade400, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        final i = state.tasks.indexOf(t);
        state.remove(t);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: const Text('Tarea eliminada'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(label: 'Deshacer', onPressed: () => state.insertBack(i, t)),
          ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withAlpha(120),
          borderRadius: BorderRadius.circular(18),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          leading: GestureDetector(
            onTap: () {
              state.toggle(t);
              HapticFeedback.lightImpact();
              if (t['done'] == true && state.justWon7()) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('🔥 ¡Racha de 7 días desbloqueada!'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? Colors.green : Colors.transparent,
                border: Border.all(color: done ? Colors.green : cs.outline, width: 2),
              ),
              child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ),
          title: Text(
            '${t['text']}',
            style: TextStyle(
              decoration: done ? TextDecoration.lineThrough : null,
              color: done ? cs.outline : null,
            ),
          ),
          subtitle: Wrap(
            spacing: 6,
            children: [
              chip(context, '$emoji ${t['c']}'),
              if (t['d'] != null) chip(context, '📅 $dLabel$tm', hot: late),
            ],
          ),
          trailing: Container(
            width: 6,
            height: 36,
            decoration: BoxDecoration(
              color: kPrios[t['p']],
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
      ),
    );
  }
}

void addSheet(BuildContext context, AppState state) {
  final ctrl = TextEditingController();
  String p = 'media', c = 'Personal';
  DateTime? date;
  TimeOfDay? time;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        void submit() {
          if (ctrl.text.trim().isEmpty) return;
          state.add(ctrl.text.trim(), p, c, date, time);
          Navigator.pop(ctx);
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                onSubmitted: (_) => submit(),
                decoration: const InputDecoration(
                    hintText: 'Nueva tarea…', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final e in kPrios.keys)
                  ChoiceChip(
                      label: Text(e), selected: p == e, onSelected: (_) => set(() => p = e)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final e in kCats.entries)
                  ChoiceChip(
                    label: Text('${e.value} ${e.key}'),
                    selected: c == e.key,
                    onSelected: (_) => set(() => c = e.key),
                  ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(date == null ? 'Fecha' : dayKey(date!)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) set(() => date = d);
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.alarm),
                  label: Text(time == null ? 'Hora' : time!.format(ctx)),
                  onPressed: () async {
                    final x = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                    if (x != null) set(() => time = x);
                  },
                ),
              ]),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: submit, child: const Text('Añadir tarea')),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ───────────────────────── Estadísticas ─────────────────────────
class StatsPage extends StatelessWidget {
  final AppState state;
  const StatsPage({super.key, required this.state});

  Widget card(BuildContext context, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(120),
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      );

  Widget stat(BuildContext context, String v, String l) => Expanded(
        child: card(
          context,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShaderMask(
              shaderCallback: (r) => kGrad.createShader(r),
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            Text(l, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ]),
        ),
      );

  Widget breakdown(BuildContext context, String title, Map<String, int> items) {
    final mx = items.values.fold<int>(1, (a, b) => a > b ? a : b);
    return card(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final e in items.entries) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(e.key),
            Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: e.value / mx),
            duration: const Duration(milliseconds: 600),
            builder: (_, v, __) => LinearProgressIndicator(
                value: v, minHeight: 8, borderRadius: BorderRadius.circular(9)),
          ),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final log = state.log;
        final n = log.length;
        final pend = state.tasks.where((t) => t['done'] != true).length;
        final rate = n + pend == 0 ? 0 : (n / (n + pend) * 100).round();
        final streak = state.streak;
        final days = {for (final l in log) l['dt'] as String};
        final week = [for (var i = 6; i >= 0; i--) DateTime.now().subtract(Duration(days: i))];
        final counts = week.map((d) => log.where((l) => l['dt'] == dayKey(d)).length).toList();
        final mx = counts.fold<int>(1, (a, b) => a > b ? a : b);
        const letters = 'LMMJVSD';
        int by(String k, String v) => log.where((l) => l[k] == v).length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Estadísticas',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(children: [
              stat(context, '$n', 'Completadas'),
              const SizedBox(width: 10),
              stat(context, '$rate%', 'Tasa de éxito'),
            ]),
            Row(children: [
              stat(context, '$streak', 'Racha (días)'),
              const SizedBox(width: 10),
              stat(context, '$pend', 'Pendientes'),
            ]),
            card(
              context,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🔥 Racha de 7 días', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  for (final d in week)
                    Column(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: days.contains(dayKey(d))
                              ? const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)])
                              : null,
                          border: days.contains(dayKey(d))
                              ? null
                              : Border.all(
                                  color: dayKey(d) == today()
                                      ? kA
                                      : Theme.of(context).dividerColor,
                                  width: 2),
                        ),
                        child: Text(days.contains(dayKey(d)) ? '🔥' : '',
                            style: const TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(height: 4),
                      Text(letters[d.weekday - 1],
                          style: TextStyle(
                              fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                    ]),
                ]),
                const SizedBox(height: 14),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (streak > 7 ? 7 : streak) / 7),
                  duration: const Duration(milliseconds: 600),
                  builder: (_, v, __) => LinearProgressIndicator(
                      value: v, minHeight: 8, borderRadius: BorderRadius.circular(9)),
                ),
                const SizedBox(height: 8),
                Text(streak >= 7
                    ? '🏆 ¡Racha de 7 días lograda!'
                    : 'Llevas $streak de 7 días seguidos'),
              ]),
            ),
            card(
              context,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📈 Últimos 7 días', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 130,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('${counts[i]}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.outline)),
                              const SizedBox(height: 4),
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: counts[i] / mx * 70 + 4),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOutBack,
                                builder: (_, v, __) => Container(
                                  height: v < 0 ? 0 : v,
                                  margin: const EdgeInsets.symmetric(horizontal: 5),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                        colors: [kB, kA],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(letters[week[i].weekday - 1],
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.outline)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ]),
            ),
            breakdown(context, '🗂️ Por categoría', {
              for (final e in kCats.entries) '${e.value} ${e.key}': by('c', e.key)
            }),
            breakdown(context, '🎯 Por prioridad', {
              '🔴 Alta': by('p', 'alta'),
              '🟠 Media': by('p', 'media'),
              '🟢 Baja': by('p', 'baja'),
            }),
          ],
        );
      },
    );
  }
}

// ───────────────────────── Perfil ─────────────────────────
class ProfilePage extends StatefulWidget {
  final AppState state;
  const ProfilePage({super.key, required this.state});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController ctrl = TextEditingController(text: widget.state.name);

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Widget card(BuildContext context, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(120),
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final cs = Theme.of(context).colorScheme;
    const titles = ['Novato', 'Aprendiz', 'Constante', 'Imparable', 'Maestro'];
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final n = s.log.length;
        final lv = s.level;
        final title = titles[((lv - 1) ~/ 2).clamp(0, 4)];
        final j = s.join.split('-');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Perfil',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            card(
              context,
              Row(children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: kGrad,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: kA.withAlpha(100), blurRadius: 20, offset: const Offset(0, 8))
                    ],
                  ),
                  child: Text(s.avatar, style: const TextStyle(fontSize: 38)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(
                      controller: ctrl,
                      maxLength: 20,
                      onChanged: s.setName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                          hintText: 'Tu nombre', counterText: '', border: InputBorder.none),
                    ),
                    Text('Nivel $lv · $title · desde ${j[2]}/${j[1]}/${j[0]}',
                        style: TextStyle(color: cs.outline, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
            card(
              context,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tu progreso', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (n % 5) / 5),
                  duration: const Duration(milliseconds: 600),
                  builder: (_, v, __) => LinearProgressIndicator(
                      value: v, minHeight: 8, borderRadius: BorderRadius.circular(9)),
                ),
                const SizedBox(height: 8),
                Text('${5 - n % 5} tareas para el nivel ${lv + 1}',
                    style: TextStyle(color: cs.outline, fontSize: 13)),
              ]),
            ),
            card(
              context,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Elige tu avatar', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final a in kAvatars)
                    GestureDetector(
                      onTap: () => s.setAvatar(a),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: a == s.avatar ? kA : cs.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: a == s.avatar ? kA : cs.outlineVariant),
                        ),
                        child: Text(a, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ]),
              ]),
            ),
            card(
              context,
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Borrar todos mis datos'),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Borrar todo?'),
                        content: const Text('Se eliminarán tus tareas y tus estadísticas.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Borrar')),
                        ],
                      ),
                    );
                    if (ok == true) s.wipe();
                  },
                  child: const Text('Borrar'),
                ),
              ]),
            ),
          ],
        );
      },
    );
  }
}