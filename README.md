# Пишем кастомные правила линтера для Dart и Flutter-проектов

[Стандартный набор правил Дартового линтера](https://dart.dev/tools/linter-rules) содержит много готовых проверок кода,
которые помогают нам выявлять потенциальные ошибки и проблемы в проекте.

Однако, иногда приходится писать собственные правила для линтера.

**Вот несколько причин, почему нам могут потребоваться свои проверки кода:**

- Единые стандарты: обеспечение согласованности в больших командах.
- Обнаружение специфических проблем: бизнес-логика или особенности архитектуры проекта могут содержать логику,
  работоспособность которой лучше доверить машине.
- Сокращение Code Review: ваш код уже прошел минимальный набор обязательных проверок, и ревьюеру будет проще
  сконцентрироваться на бизнес-части, нежели писать кучу однотипных комментариев с просьбами добавить или убрать что-то
  из проекта.
- Документирование: кастомные правила порой говорят сами за себя. Вам не нужно читать кучу документации перед началом
  работы над проектом, многое будет подсвечено в процессе.

Dart имеет свой фреймворк для создания подобных решений, и называется
он [analyzer_plugin](https://pub.dev/packages/analyzer_plugin). К сожалению, сейчас он не доступен для общего
пользования, и в целом разработка на нем требует больше подготовительных моментов, нежели другие решения.

Мы будем использовать [custom_lint](https://pub.dev/packages/custom_lint). Это стороннее решение для создания
собственных правил линтера. Плагин поддерживается сообществом, содержит рабочие примеры кода, а так же дает возможность
запускать свои правила отдельно из CLI.

## Что будем проверять?

Возьмем как пример реальный кейс, который может иногда встречаться на Flutter-проектах. Будем разбирать его в
рамках [bloc_example](https://github.com/fluttermiddlepodcast/bloc_example), небольшого репозитория, где мы
изучаем [flutter_bloc](https://pub.dev/packages/flutter_bloc).

*Цель: нужно правило для проверки всех виджетов `BlocBuilder` на наличие параметра `buildWhen`. Это аргумент, который
позволяет определить, нужно ли обновлять UI при изменении состояния, тем самым минимизируя лишние перерисовки во
время ненужных обновлений. Если вы не работали с `flutter_bloc`, то начать
можно [отсюда](https://github.com/fluttermiddlepodcast/bloc_example). В репозитории есть ссылки на видео-материалы и
выпуски подкаста, а так же [обзор `BlocBuilder`](https://youtu.be/98iF13KKdss).*

**Опираясь на код, вот так неправильно:**

```dart
@override
Widget build(BuildContext context) {
  return BlocBuilder<AuthBloc, AuthState>(
    // Тут должен быть параметр `buildWhen`, но его нет.
    builder: (context, state) {
      return state.isAuthenticated ? HomePage() : LoginPage();
    },
  );
}
```

**А вот так правильно:**

```dart
@override
Widget build(BuildContext context) {
  return BlocBuilder<AuthBloc, AuthState>(
    buildWhen: (previous, current) {
      return previous.isAuthenticated != current.isAuthenticated;
    },
    builder: (context, state) {
      return state.isAuthenticated ? HomePage() : LoginPage();
    },
  );
}
```

Если параметр `buildWhen` не указан, то мы увидим ошибку в IDE, либо же во время прогона CI.

**IDE покажет такой вывод:**

![Error in IDE](./media/error_ide.png)

**CI или консоль выдаст следующее:**

![Error in CI](./media/error_ci.png)

## Разбор кода

**В проекте имеем всего 2 файла:**

- [./lib/bloc_builder_build_when_lint_rule.dart](./lib/bloc_builder_build_when_lint_rule.dart) - код с конфигурацией нашего плагина.
- [./lib/src/bloc_builder_build_when_rule.dart](./lib/src/bloc_builder_build_when_rule.dart) - код с логикой нашего правила.

### Код правила

[./lib/src/bloc_builder_build_when_rule.dart](./lib/src/bloc_builder_build_when_rule.dart)

**Полный листинг с комментариями к каждой строке кода:**

```dart
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
  void run(CustomLintResolver resolver,
      ErrorReporter reporter,
      CustomLintContext context,) {
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

  bool _isType(TypeAnnotation? type,
      String matchType,
      String package,) {
    final element = type?.type?.element;

    if (element == null || element.name != matchType) {
      return false;
    }

    return element.library?.location?.components.any((c) => c.contains(package)) ?? false;
  }
}
```

### Код конфигураци

[./lib/bloc_builder_build_when_lint_rule.dart](./lib/bloc_builder_build_when_lint_rule.dart)

**Содержимое файла с комментариями:**

```dart
import 'package:bloc_builder_build_when_lint_rule/src/bloc_builder_build_when_rule.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _BlocBuilderLintPlugin();

class _BlocBuilderLintPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) =>
      [
        BlocBuilderBuildWhenRule(),
      ];
}
```

## Запуск

Рассмотрим как локальный запуск - работу с IDE, так и конфигурацию для CI.

### Локально

После создания правила, нужно добавить его в ваш проект. Поскольку мы зависим от `custom_lint`, его так же нужно
импортировать в `dev_dependencies`. Готовый файл можно найти [тут](./pubspec.yaml).

**Из Git-репозитория добавление будет таким:**

```yaml
dev_dependencies:
  custom_lint:
  bloc_builder_build_when_rule:
    git:
      url: https://github.com/fluttermiddlepodcast/bloc_builder_build_when_lint_rule.git
      ref: master
```

**Если плагин расположен локально, то можно просто указать относительный путь от проекта до правила:**

```yaml
dev_dependencies:
  custom_lint:
  bloc_builder_build_when_rule:
    path: ../bloc_builder_build_when_lint_rule
```

**Далее запускаем `dart pub get` для загрузки зависимостей и подключения их в проект:**

```shell
$ dart pub get
```

После анализа проекта плагин будет доступен в проекте. Если у вас есть какие-то виджеты типа `BlocBuilder` без
указанного `buildWhen`, IDE начнет подсвечивать их инициализацию с
ошибкой. [Ветка bloc_example с нашим правилом](https://github.com/fluttermiddlepodcast/bloc_example/tree/custom_lint)
содержит невалидный по меркам правила код, можете выгрузить и убедиться в работоспособности плагина.

**Для запуска всех проверок `custom_lint`, достаточно выполнить из терминала:**

```shell
$ dart pub run custom_lint
```

### CI

Конфигурацию для GitHub Actions можно
найти [тут](https://github.com/fluttermiddlepodcast/bloc_example/blob/custom_lint/.github/workflows/flutter.yaml). Если
вам интересно, что там дополнительно навешано для оптимизации запуска CI, и как еще можно оптимизировать ваши проверки,
рекомендую посмотреть [отдельное видео](https://youtu.be/NxY6mGaIzKY) по этой теме.

**Сама часть с `custom_lint` будет выглядить следующим образом:**

```yaml
custom_lint:
  runs-on: ubuntu-latest
  needs: changes
  if: needs.changes.outputs.any_changed == 'true'
  steps:
    - uses: actions/checkout@v4
    - uses: kuhnroyal/flutter-fvm-config-action@v2
      id: fvm-config-action
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: ${{ steps.fvm-config-action.outputs.FLUTTER_VERSION }}
        channel: ${{ steps.fvm-config-action.outputs.FLUTTER_CHANNEL }}
    - name: Get dependencies
      run: flutter pub get
    - name: Analyze code
      run: flutter pub run custom_lint ${{ needs.changes.outputs.all_changed_files }}
```

Упавший билд CI можно посмотреть [в этом пулл реквесте](https://github.com/fluttermiddlepodcast/bloc_example/pull/12).

## Подводные камни

Если бы с написанием правил для линтера было все так просто, много проблемных моментов на проектах удалось бы избежать в
процессе его написания и рефакторинга.

**К сожалению, мы имеем такие минусы:**

- Сложность освоения: если небольшие правила можно написать без дополнительной подготовки с каким-нибудь AI-ассистентом,
  то со сложными решениями придется повозиться. Понадобится изучить
  дартовый [AST](https://ru.wikipedia.org/wiki/%D0%90%D0%B1%D1%81%D1%82%D1%80%D0%B0%D0%BA%D1%82%D0%BD%D0%BE%D0%B5_%D1%81%D0%B8%D0%BD%D1%82%D0%B0%D0%BA%D1%81%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%BE%D0%B5_%D0%B4%D0%B5%D1%80%D0%B5%D0%B2%D0%BE)
  и работу аналайзера кода в целом.
- Возможные ложные срабатывания: есть риск что-то упустить во время написания сложной логики обработки кода.
- Поддержка о обновление: Dart, Flutter и сторонние плагины обновляются, и нужно следить за тем, насколько ваши правила
  актуальны для используемых инструментов.
- Производительность: сложные проверки или неоптимизированные правила могут замедлить работу Аналайзера даже на средних
  проектах. Может потребоваться дополнительное время на написание более оптимального подхода по анализу кода.
- Overengineering: есть риск создания бесполезных правил ради правил. В купе с минусами выше становится одной из главных
  проблем. Лучше заранее подумать, насколько +1 анализатор кода вам действительно нужен.

## Выводы

Пример из проекта - лишь капля в море возможностей реализации проверок вашего кода. Писать собственные правила не так
трудно, нужно лишь время на разбор концепций и написание инструментов.

Импакт от таких решений на больших проектах можно оценить в уменьшении времени проверки кода коллег, следованию
регламентам компании, и в целом меньшим количеством споров и глупых потенциальных ошибок.
