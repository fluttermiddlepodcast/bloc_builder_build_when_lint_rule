import 'package:bloc_builder_build_when_lint_rule/src/bloc_builder_build_when_rule.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _BlocBuilderLintPlugin();

class _BlocBuilderLintPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        BlocBuilderBuildWhenRule(),
      ];
}
