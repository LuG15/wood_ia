import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const WoodIAApp());
}

class WoodIAApp extends StatelessWidget {
  const WoodIAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WooD_IA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _imagemSelecionada;
  bool _carregando = false;
  bool _analisandoExtra = false;

  // Resultados da IA
  String? _especie;
  String? _nomeCientifico;
  String? _confianca;
  String? _descricao;
  String? _extraInfo;

  // Controle do Chat
  bool _mostrarChat = false;
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _mensagensChat = [];
  bool _chatCarregando = false;

  // SUA API KEY (Já configurada)
  static const String apiKey = 'AIzaSyDSDVMwlpCHIs2HGjOTPEUtSd1gOKg1d-8';

  late final GenerativeModel _model;
  late final GenerativeModel _chatModel;

  @override
  void initState() {
    super.initState();
    // Usando o modelo flash-latest para evitar erro de versão
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
    _chatModel = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
  }

  // --- Função 1: Identificar Árvore ou Folha ---
  Future<void> _analisarArvore() async {
    if (_imagemSelecionada == null) return;

    // Verificação de segurança simplificada
    if (apiKey.isEmpty || apiKey == 'COLE_SUA_CHAVE_AQUI') {
      _mostrarErro("Configure sua API Key no código.");
      return;
    }

    setState(() {
      _carregando = true;
      _limparResultadosAnteriores();
    });

    try {
      final imageBytes = await _imagemSelecionada!.readAsBytes();

      final prompt = TextPart(
        "Analise esta imagem. Deve ser uma folha ou um tronco de árvore. "
        "Identifique a espécie com base nas características visuais (formato da folha, textura do tronco, etc). "
        "Responda EXATAMENTE neste formato separado por barras verticais (|): "
        "Nome Popular|Nome Científico|Porcentagem de Confiança (ex: 95%)|Uma frase curta sobre a característica principal identificada."
        "Se não for uma planta ou árvore, retorne apenas: ERRO",
      );

      final imagePart = DataPart('image/jpeg', imageBytes);
      final response = await _model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      final text = response.text;

      if (text != null && text.contains("|")) {
        final parts = text.split("|");
        setState(() {
          _especie = parts[0].trim();
          _nomeCientifico = parts.length > 1 ? parts[1].trim() : "";
          _confianca = parts.length > 2 ? parts[2].trim() : "";
          _descricao = parts.length > 3 ? parts[3].trim() : "";

          // Inicia o chat com uma mensagem de boas-vindas
          _mensagensChat.add({
            'role': 'model',
            'text':
                'Olá! Identifiquei uma $_especie. O que quer saber sobre ela?',
          });
        });
      } else {
        _mostrarErro("Não consegui identificar a espécie nesta imagem.");
      }
    } catch (e) {
      _mostrarErro("Erro de conexão: $e");
    } finally {
      setState(() => _carregando = false);
    }
  }

  // --- Função 2: Gerar Curiosidades ---
  Future<void> _gerarCuriosidades() async {
    if (_especie == null) return;
    setState(() => _analisandoExtra = true);

    try {
      final prompt =
          "Sobre a árvore '$_especie' ($_nomeCientifico): Liste 3 usos da madeira/fruto e 1 curiosidade histórica. Seja breve.";
      final response = await _model.generateContent([Content.text(prompt)]);

      setState(() {
        _extraInfo = response.text;
      });
    } catch (e) {
      _mostrarErro("Erro ao buscar curiosidades.");
    } finally {
      setState(() => _analisandoExtra = false);
    }
  }

  // --- Função 3: Enviar Mensagem no Chat ---
  Future<void> _enviarMensagemChat() async {
    final texto = _chatController.text;
    if (texto.isEmpty || _especie == null) return;

    setState(() {
      _mensagensChat.add({'role': 'user', 'text': texto});
      _chatController.clear();
      _chatCarregando = true;
    });

    try {
      // Construir histórico simples para contexto
      String contexto =
          "Você é um especialista botânico. Estamos falando sobre a espécie: $_especie ($_nomeCientifico).\n";
      for (var msg in _mensagensChat) {
        contexto += "${msg['role']}: ${msg['text']}\n";
      }
      contexto += "Responda de forma curta e amigável.";

      final response = await _chatModel.generateContent([
        Content.text(contexto),
      ]);

      setState(() {
        _mensagensChat.add({
          'role': 'model',
          'text': response.text ?? "Sem resposta.",
        });
      });
    } catch (e) {
      setState(() {
        _mensagensChat.add({
          'role': 'model',
          'text': "Erro de conexão no chat.",
        });
      });
    } finally {
      setState(() => _chatCarregando = false);
    }
  }

  // Helpers
  void _limparResultadosAnteriores() {
    _especie = null;
    _nomeCientifico = null;
    _confianca = null;
    _descricao = null;
    _extraInfo = null;
    _mensagensChat.clear();
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _escolherImagem(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() => _imagemSelecionada = File(image.path));
        _analisarArvore();
      }
    } catch (e) {
      debugPrint('Erro ao selecionar imagem: $e');
    }
  }

  // Interface (UI)
  @override
  Widget build(BuildContext context) {
    if (_mostrarChat) return _buildChatScreen();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WooD_IA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[800],
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Área da Imagem
            Container(
              height: 350,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade200),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10),
                ],
              ),
              child: _imagemSelecionada == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.eco, size: 80, color: Colors.green[200]),
                        const SizedBox(height: 10),
                        Text(
                          "Fotografe Folha ou Tronco",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: Image.file(_imagemSelecionada!, fit: BoxFit.cover),
                    ),
            ),

            const SizedBox(height: 20),

            // Carregamento ou Resultados
            if (_carregando)
              const Column(
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 10),
                  Text(
                    "Identificando espécie...",
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              )
            else if (_especie != null)
              _buildResultCard(),

            const SizedBox(height: 30),

            // Botões de Câmera/Galeria
            if (_especie == null)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _escolherImagem(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Galeria"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _escolherImagem(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Câmera"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(15),
                        backgroundColor: Colors.green[800],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _imagemSelecionada = null;
                    _limparResultadosAnteriores();
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Analisar Outra"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Widget do Cartão de Resultado
  Widget _buildResultCard() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  Chip(
                    label: Text(
                      _confianca ?? "",
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    backgroundColor: Colors.green[600],
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              Text(
                _especie!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                _nomeCientifico!,
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.green[800],
                ),
              ),
              const Divider(),
              Text(
                _descricao!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),

              const SizedBox(height: 15),

              // Botões de Chat e Curiosidades
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _analisandoExtra || _extraInfo != null
                          ? null
                          : _gerarCuriosidades,
                      icon: _analisandoExtra
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.lightbulb,
                              size: 18,
                              color: Colors.amber,
                            ),
                      label: const Text(
                        "Curiosidades",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _mostrarChat = true),
                      icon: const Icon(
                        Icons.chat,
                        size: 18,
                        color: Colors.blue,
                      ),
                      label: const Text(
                        "Chat Botânico",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Exibe curiosidades se existirem
        if (_extraInfo != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(
              _extraInfo!,
              style: TextStyle(color: Colors.brown[800], fontSize: 13),
            ),
          ),
      ],
    );
  }

  // Tela de Chat
  Widget _buildChatScreen() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _mostrarChat = false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Especialista Botânico", style: TextStyle(fontSize: 16)),
            Text(
              "Falando sobre: $_especie",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _mensagensChat.length,
              itemBuilder: (context, index) {
                final msg = _mensagensChat[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 250),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.green[100] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isUser ? Colors.green : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(msg['text']!),
                  ),
                );
              },
            ),
          ),
          if (_chatCarregando)
            const LinearProgressIndicator(color: Colors.green),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: "Pergunte algo...",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.green[800],
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _enviarMensagemChat,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
