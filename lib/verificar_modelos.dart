import 'dart:io';
import 'dart:convert';

// ⚠️ COLE SUA API KEY AQUI
const apiKey = 'AIzaSyAkBq5woUehA4yB_qM9lhSHmPajaKv1St8';

void main() async {
  print('🔍 Consultando lista de modelos disponíveis para sua chave...');

  final url = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
  );
  final httpClient = HttpClient();

  try {
    final request = await httpClient.getUrl(url);
    final response = await request.close();

    if (response.statusCode == 200) {
      final jsonString = await response.transform(utf8.decoder).join();
      final data = jsonDecode(jsonString);

      print('\n✅ MODELOS DISPONÍVEIS:');
      print('-----------------------------------');
      for (var model in data['models']) {
        // Filtra apenas os modelos que geram conteúdo (chat)
        if (model['supportedGenerationMethods'].contains('generateContent')) {
          // Remove o prefixo "models/" para facilitar a leitura
          String nome = model['name'].toString().replaceAll('models/', '');
          print('• $nome');
        }
      }
      print('-----------------------------------');
    } else {
      print('❌ Erro: ${response.statusCode}');
      print(
        'Verifique se a API Key está correta e se a API "Generative Language" está ativada no Google Cloud.',
      );
    }
  } catch (e) {
    print('❌ Erro de conexão: $e');
  } finally {
    httpClient.close();
  }
}
