import 'dart:convert';

import 'detector.dart';
import 'lang_detect_exception.dart';
import 'utils/lang_profile.dart';
import 'language.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

const PROFILES = [
  "af",
  "ar",
  "bg",
  "bn",
  "ca",
  "cs",
  "cy",
  "da",
  "de",
  "el",
  "en",
  "es",
  "et",
  "fa",
  "fi",
  "fr",
  "gu",
  "he",
  "hi",
  "hr",
  "hu",
  "id",
  "it",
  "ja",
  "kn",
  "ko",
  "lt",
  "lv",
  "mk",
  "ml",
  "mr",
  "ne",
  "nl",
  "no",
  "pa",
  "pl",
  "pt",
  "ro",
  "ru",
  "sk",
  "sl",
  "so",
  "sq",
  "sv",
  "sw",
  "ta",
  "te",
  "th",
  "tl",
  "tr",
  "uk",
  "ur",
  "vi",
  "zh-cn",
  "zh-tw",
];

class DetectorFactory {
  /// Language Detector Factory Class.
  /// This class manages an initialization and constructions of Detector.
  /// Before using language detection library,
  /// initialize just once with initFactory() method after
  /// WidgetsFlutterBinding.ensureInitialized();
  ///
  /// When the language detection,
  /// construct Detector instance via DetectorFactory.create().
  /// See also Detector's sample code.

  final logger = Logger();
  static final DetectorFactory _singleton = DetectorFactory._internal();
  static String profileBasePath =
      "packages/flutter_langdetect/assets/profiles/";

  factory DetectorFactory() {
    return _singleton;
  }

  DetectorFactory._internal();
  static bool _initialized = false;

  static Future<void> initFactory() async {
    if (_initialized == false) {
      await DetectorFactory().loadProfile();
      _initialized = true;
    }
  }

  static String detect(String text) {
    Detector detector = DetectorFactory().create();
    detector.append(text);
    return detector.detect();
  }

  static List<Language> detectLangs(String text) {
    Detector detector = DetectorFactory().create();
    detector.append(text);
    return detector.getProbabilities();
  }

  int? seed;

  Map<String, List<double>> wordLangProbMap = {};
  List<String> langList = [];

  Future<void> loadProfile() async {
    logger.d("loadProfile");
    int langSize = PROFILES.length;
    int index = 0;
    for (var file in PROFILES) {
      String filename = "$profileBasePath$file";

      try {
        String content = (await rootBundle.loadString(filename));

        final jsonData = jsonDecode(content);
        LangProfile profile = LangProfile(
            name: jsonData['name'],
            freq: (jsonData['freq'] as Map<String, dynamic>)
                .map((key, value) => MapEntry(key, value.toInt())),
            nWords: (jsonData['n_words'].cast<int>() as List<int>));
        addProfile(profile, index, langSize);
        index += 1;
      } catch (e) {
        throw LangDetectException(
            ErrorCode.FileLoadError, 'Cannot open "$filename"');
      }
    }
  }

  void loadJsonProfile(List<String> jsonProfiles) {
    int langSize = jsonProfiles.length;
    int index = 0;
    if (langSize < 2) {
      throw LangDetectException(
          ErrorCode.NeedLoadProfileError, 'Need more than 2 profiles.');
    }

    for (String jsonProfile in jsonProfiles) {
      try {
        final jsonData = jsonDecode(jsonProfile);
        LangProfile profile = LangProfile(
            name: jsonData['name'],
            freq: (jsonData['freq'] as Map<String, dynamic>)
                .map((key, value) => MapEntry(key, value.toInt())),
            nWords: (jsonData['n_words'].cast<int>() as List<int>));
        addProfile(profile, index, langSize);
        index += 1;
      } catch (e) {
        rethrow;
        // throw LangDetectException(
        //     ErrorCode.FormatError, 'Profile format error.$jsonProfile');
      }
    }
  }

  void addProfile(LangProfile profile, int index, int langSize) {
    String lang = profile.name!;
    if (langList.contains(lang)) {
      final s = langList.toString();
      throw LangDetectException(ErrorCode.DuplicateLangError,
          'Duplicate the same language profile. $s');
    }
    langList.add(lang);

    profile.freq.forEach((String word, int count) {
      if (!wordLangProbMap.containsKey(word)) {
        wordLangProbMap[word] = List<double>.filled(langSize, 0.0);
      }
      int length = word.length;
      if (1 <= length && length <= 3) {
        double prob = 1.0 * count / profile.nWords[length - 1];
        wordLangProbMap[word]![index] = prob;
      }
    });
  }

  void clear() {
    langList = [];
    wordLangProbMap = {};
  }

  Detector create({double? alpha}) {
    Detector detector = _createDetector();
    if (alpha != null) {
      detector.setAlpha(alpha);
    }
    return detector;
  }

  Detector _createDetector() {
    if (langList.isEmpty) {
      throw LangDetectException(
          ErrorCode.NeedLoadProfileError, 'Need to load profiles.');
    }
    return Detector(this);
  }

  void setSeed(int seed) {
    this.seed = seed;
  }

  List<String> getLangList() {
    return List<String>.from(langList);
  }
}
