import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';

/// Debe coincidir con `LegalDocuments.CURRENT_VERSION` del backend.
const currentLegalVersion = '2026-11-21';
const termsSlug = 'terminos-y-condiciones';
const privacySlug = 'politica-de-privacidad';

class LegalDocument {
  const LegalDocument(
      {required this.title, required this.version, required this.content});
  final String title, version, content;

  factory LegalDocument.fromJson(Map<String, dynamic> json) => LegalDocument(
      title: json['title'] as String,
      version: json['version'] as String,
      content: json['content'] as String);
}

Future<LegalDocument> fetchLegalDocument(ApiClient api, String slug) async {
  final response =
      await api.dio.get<Map<String, dynamic>>('/api/v1/public/legal/$slug');
  return LegalDocument.fromJson(response.data!);
}

void openLegalDocument(BuildContext context, String slug, String title) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => LegalDocumentPage(slug: slug, title: title)));

/// Muestra los Términos y Condiciones o la Política de Privacidad vigentes.
class LegalDocumentPage extends ConsumerStatefulWidget {
  const LegalDocumentPage({super.key, required this.slug, required this.title});
  final String slug, title;

  @override
  ConsumerState<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends ConsumerState<LegalDocumentPage> {
  late Future<LegalDocument> document;

  @override
  void initState() {
    super.initState();
    document = fetchLegalDocument(ref.read(apiClientProvider), widget.slug);
  }

  void retry() => setState(() =>
      document = fetchLegalDocument(ref.read(apiClientProvider), widget.slug));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: FutureBuilder<LegalDocument>(
          future: document,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('No pudimos cargar el documento.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: retry, child: const Text('Reintentar')),
                  ]),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return SelectionArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: legalMarkdownBlocks(context, snapshot.data!.content),
              ),
            );
          },
        ),
      );
}

/// Renderiza el subconjunto de Markdown usado en los documentos legales:
/// títulos (#, ##), viñetas (-), notas (>) y párrafos.
List<Widget> legalMarkdownBlocks(BuildContext context, String markdown) {
  final theme = Theme.of(context);
  final widgets = <Widget>[];
  for (final raw in markdown.split('\n')) {
    final line = raw.trimRight();
    if (line.isEmpty) continue;
    if (line.startsWith('# ')) {
      widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(line.substring(2),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800))));
    } else if (line.startsWith('## ')) {
      widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(line.substring(3),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700))));
    } else if (line.startsWith('- ')) {
      widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  '),
            Expanded(child: Text(line.substring(2))),
          ])));
    } else if (line.startsWith('> ')) {
      widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          color: theme.colorScheme.secondaryContainer,
          child: Text(line.substring(2))));
    } else {
      widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8), child: Text(line)));
    }
  }
  return widgets;
}

/// Enlaces a los documentos legales, para las pantallas de perfil.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        children: [
          TextButton(
              onPressed: () => openLegalDocument(
                  context, termsSlug, 'Términos y Condiciones'),
              child: const Text('Términos y Condiciones')),
          TextButton(
              onPressed: () => openLegalDocument(
                  context, privacySlug, 'Política de Privacidad'),
              child: const Text('Política de Privacidad')),
        ],
      );
}
