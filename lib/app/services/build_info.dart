import 'dart:convert';

class BuildInfo {
  const BuildInfo._();

  static const String sha = String.fromEnvironment(
    'CAJA_CLARA_BUILD_SHA',
    defaultValue: 'local',
  );
  static const String shortSha = String.fromEnvironment(
    'CAJA_CLARA_BUILD_SHORT_SHA',
    defaultValue: 'local',
  );
  static const String branch = String.fromEnvironment(
    'CAJA_CLARA_BUILD_BRANCH',
    defaultValue: 'main',
  );
  static const String builtAtUtc = String.fromEnvironment(
    'CAJA_CLARA_BUILD_TIME_UTC',
    defaultValue: 'local',
  );
  static const String source = String.fromEnvironment(
    'CAJA_CLARA_BUILD_SOURCE',
    defaultValue: 'manual',
  );

  static String get shortCommit => shortSha == 'local' ? 'local' : shortSha;

  static String get footerText => 'Build $shortCommit | $branch | $builtAtUtc';

  static Map<String, dynamic> toJson({String? baseHref}) {
    return <String, dynamic>{
      'commitSha': sha,
      'shortCommitSha': shortCommit,
      'branch': branch,
      'builtAtUtc': builtAtUtc,
      'source': source,
      if (baseHref != null) 'baseHref': baseHref,
    };
  }

  static String toJsonString({String? baseHref}) {
    return jsonEncode(toJson(baseHref: baseHref));
  }
}
