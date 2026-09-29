import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../content/festival_skin.dart';
import '../content/festivals.dart';
import '../content/pongal_adventure.dart';
import '../model/adventure.dart';
import '../validation/adventure_validator.dart';
import 'adventure_variation.dart';

/// Why making a new adventure did not work, in words a player can act on.
class GenerationFailure implements Exception {
  const GenerationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What came back, and whether it was usable.
class GenerationResult {
  const GenerationResult({required this.adventure, required this.problems});

  final Adventure adventure;

  /// Empty when the adventure passed every check. Non-empty means the bundled
  /// adventure is being offered instead, and these are the reasons.
  final List<String> problems;

  bool get isGenerated => problems.isEmpty;
}

/// Asks the backend for a new set of words, and turns them into an adventure.
///
/// **The key never comes near this code.** The request goes to the project's
/// own Express backend, which holds `GEMINI_API_KEY` in its environment and
/// calls Gemini itself — exactly as the assistant and the quiz already do.
/// Nothing here knows a model name, a prompt or a key.
///
/// **Nothing is trusted.** What comes back is a map of strings. Those strings
/// go through [applyVariation], which can only put them into text slots of the
/// hand-written template, and the result then goes through the full
/// [AdventureValidator] — structure and solver both — on this device. If any of
/// that fails, the player gets the bundled adventure and is told plainly why.
class AdventureGenerator {
  AdventureGenerator({http.Client? httpClient, String? baseUrl})
    : _http = httpClient ?? http.Client(),
      _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceAll(
        RegExp(r'/+$'),
        '',
      );

  final http.Client _http;
  final String _baseUrl;

  bool get isConfigured => _baseUrl.isNotEmpty;

  static const Duration _timeout = Duration(seconds: 45);

  /// Makes a new adventure, or explains why it could not.
  ///
  /// Never throws for an ordinary failure — being offline, a slow server, a
  /// model having a bad day. Those come back as a [GenerationResult] carrying
  /// the bundled adventure and the reason, because a player who pressed "make
  /// me an adventure" should still get an adventure.
  Future<GenerationResult> generate({
    FestivalSkin? festival,
    String? seedWord,
  }) async {
    final skin = festival ?? kFestivals.first;
    final base = adventureForFestival(skin);

    if (!isConfigured) {
      return _fallback(['This build has no backend configured.'], base);
    }

    // The words as they stand FOR THIS FESTIVAL, so the model rewords Bihu
    // when Bihu was chosen rather than quietly rewording Pongal.
    final current = slotTextFor(base);
    Map<String, dynamic> body;

    try {
      final response = await _http
          .post(
            Uri.parse('$_baseUrl/api/adventure'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'slots': current.keys.toList(),
              'currentText': current,
              'itemNames': itemNamesFor(base),
              'festival': skin.name,
              'region': skin.region,
              'soldOutOptions': VariationPlan.allowedSoldOutItems,
              if (seedWord != null && seedWord.trim().isNotEmpty)
                'seed': seedWord.trim(),
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return _fallback([
          'The server could not make one just now '
              '(${response.statusCode}).',
        ], base);
      }
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (error) {
      debugPrint('Adventure generation failed: ${error.runtimeType}');
      return _fallback([
        'MindPal could not reach the internet to make a new adventure.',
      ], base);
    }

    // The sold-out item is a mechanical choice, so it is checked against the
    // list rather than taken on trust.
    final requestedSoldOut = body['soldOutItemId'] as String?;
    final plan = VariationPlan(
      soldOutItemId: requestedSoldOut != null &&
              VariationPlan.isAllowed(requestedSoldOut)
          ? requestedSoldOut
          : VariationPlan.standard.soldOutItemId,
    );

    final text = AdventureTextPack.fromMap(
      body['text'] as Map<String, dynamic>? ?? const {},
    );

    final adventure = applyVariation(
      id: 'generated_${skin.id}_${DateTime.now().millisecondsSinceEpoch}',
      festival: skin,
      text: text,
      plan: plan,
    );

    // The authoritative check, on this device, over the thing that will
    // actually be played — including a full solve.
    final report = const AdventureValidator().validate(adventure);
    if (!report.isValid) {
      debugPrint('Generated adventure rejected: ${report.problems}');
      return _fallback(report.problems, base);
    }

    return GenerationResult(adventure: adventure, problems: const []);
  }

  /// The bundled adventure for the festival they asked for, so a failed
  /// generation still gives them the festival they chose.
  GenerationResult _fallback(List<String> problems, [Adventure? base]) =>
      GenerationResult(
        adventure: base ?? kPongalAdventure,
        problems: problems,
      );

  void dispose() => _http.close();
}
