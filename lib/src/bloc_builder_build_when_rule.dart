import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class BlocBuilderBuildWhenRule extends DartLintRule {
  BlocBuilderBuildWhenRule()
      : super(
          code: LintCode(
            name: 'bloc_builder_build_when_rule',
            problemMessage: 'Missing buildWhen in BlocBuilder',
            correctionMessage: 'Add buildWhen parameter to optimize rebuilds',
            errorSeverity: ErrorSeverity.ERROR,
          ),
        );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression(
      (node) {
        final type = node.constructorName.type;

        if (!_isType(type, 'BlocBuilder', 'flutter_bloc')) {
          return;
        }

        final hasBuildWhen = node.argumentList.arguments.any(
          (arg) => arg is NamedExpression && arg.name.label.name == 'buildWhen',
        );

        if (!hasBuildWhen) {
          reporter.atNode(node, code);
        }
      },
    );
  }

  bool _isType(
    TypeAnnotation? type,
    String matchType,
    String package,
  ) {
    final element = type?.type?.element;

    if (element == null || element.name == matchType) {
      return false;
    }

    return element.library?.location?.components.any((c) => c.contains(package)) ?? false;
  }
}
