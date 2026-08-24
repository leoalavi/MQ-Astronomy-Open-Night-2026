import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/data/events_data.dart';
void main() {
  test('earliest published starts', () {
    final s = EventsData.all.where((e)=>!e.isUnscheduled)
      .expand((e)=>e.sessions.map((x)=>(x.start,e.title))).toList()
      ..sort((a,b)=>a.$1.compareTo(b.$1));
    for (final x in s.take(6)) {
      print('${x.$1.hour}:${x.$1.minute.toString().padLeft(2,'0')}  ${x.$2}');
    }
  });
}
