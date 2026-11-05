import 'package:flutter_test/flutter_test.dart';
import 'package:footiq/three21/t21_voice.dart';

void main() {
  test('ses tanıma tekrarlarını ayıklar', () {
    expect(T21Voice.cleanTranscript('Messi Messi'), 'Messi');
    expect(T21Voice.cleanTranscript('Arda Turan Arda Turan'), 'Arda Turan');
    expect(T21Voice.cleanTranscript('Hakan Şükür.'), 'Hakan Şükür');
    expect(T21Voice.cleanTranscript('Arda Turan'), 'Arda Turan');
    expect(T21Voice.cleanTranscript(''), '');
  });
}
